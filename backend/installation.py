"""Synchronous installation for the dedicated installation process."""

from contextlib import suppress
from dataclasses import dataclass
import fcntl
import os
from pathlib import Path
import re
import shutil
import signal
import tempfile

from .command import run
from .model import InstallError, Plan, Profile, plan_install
from . import system, storage


@dataclass(frozen=True)
class Installed:
    boot_entry: str
    warnings: tuple[str, ...] = ()


def _firmware():
    text = run(["efibootmgr"]).stdout
    entries = dict(re.findall(r"^Boot([0-9A-Fa-f]{4})\*?\s+(.+)$", text, re.M))
    order = re.search(r"^BootOrder: ([0-9A-Fa-f,]+)$", text, re.M)
    return {key.upper(): value.split("\t", 1)[0].strip() for key, value in entries.items()}, order.group(1).upper() if order else ""


def _preflight(plan):
    if os.geteuid() != 0 or not Path("/etc/pond-installer-live").is_file():
        raise InstallError("Installation requires the Pond live environment as root")
    required = ("lsblk", "udevadm", "wipefs", "mkfs.btrfs", "mkfs.fat", "btrfs", "blkid",
                "mount", "mountpoint", "umount", "bsdtar", "arch-chroot", "efibootmgr", "sync")
    if any(shutil.which(command) is None for command in required):
        raise InstallError("The live environment is missing an installation dependency")
    if plan != plan_install(plan.disk, plan.mode, plan.allocation_gib):
        raise InstallError("The installation plan was modified")
    if not Path("/sys/firmware/efi").is_dir():
        raise InstallError("Pond requires UEFI")
    secure_boot = Path("/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c")
    # Firmware without Secure Boot support does not expose this variable.
    state = secure_boot.read_bytes() if secure_boot.exists() else b"\0" * 5
    if len(state) != 5 or state[4] != 0:
        raise InstallError("Secure Boot must be disabled")
    if any(label.casefold() == "pond" for label in _firmware()[0].values()):
        raise InstallError("A Pond firmware entry already exists")


def _validate_esp(plan, mount):
    if plan.esp is None:
        return
    storage.current_partition(plan.disk, plan.esp)
    if plan.esp.filesystem != "vfat":
        raise InstallError("The EFI partition must use FAT32")
    # blkid's vfat also includes FAT12/FAT16; verify the FAT32 boot sector.
    with open(plan.esp.path, "rb") as source:
        sector = source.read(512)
    if sector[82:90] != b"FAT32   ":
        raise InstallError("The EFI partition must use FAT32")
    run(["mount", "-o", "ro,nosuid,nodev,noexec,umask=0077", plan.esp.path, str(mount)])
    try:
        space = os.statvfs(mount)
        if space.f_bavail * space.f_frsize < 16 * 1024**2:
            raise InstallError("The EFI partition needs at least 16 MiB free")
        if (mount / "EFI/pond").exists():
            raise InstallError("The EFI partition already contains Pond boot files")
    finally:
        run(["umount", str(mount)])


def _execute(plan, profile, archive, progress):
    _preflight(plan)
    system.verify_rootfs(archive)
    progress(0.60)
    os.unshare(os.CLONE_NEWNS)
    run(["mount", "--make-rprivate", "/"])
    target = Path(tempfile.mkdtemp(prefix="pond-target-", dir="/mnt"))
    esp_mount = Path(tempfile.mkdtemp(prefix="pond-esp-", dir="/mnt"))
    created = []
    entry = None
    boot_dir = None
    committed = False
    warnings = []
    before_entries, before_order = _firmware()
    try:
        _validate_esp(plan, esp_mount)
        esp, root = storage.create_partitions(plan, created)
        storage.current_partition(plan.disk, root)
        system.mount_root(root, target)
        system.provision(target, root, esp, archive, profile, progress)
        # Update the ESP only after configuring the target system.
        storage.current_partition(plan.disk, esp)
        if plan.esp is None:
            run(["wipefs", "--all", esp.path])
            run(["mkfs.fat", "-F", "32", "-n", "Pond EFI", esp.path])
        run(["mount", "-o", "umask=0077", esp.path, str(esp_mount)])
        run(["mount", "--bind", str(esp_mount), str(target / "boot/efi")])
        run(["arch-chroot", str(target), "/usr/share/libalpm/scripts/pond-grub-update"])
        if not (target / "boot/grub/grub.cfg").stat().st_size:
            raise InstallError("Pond's boot menu is empty")
        run(["arch-chroot", str(target), "grub-script-check", "/boot/grub/grub.cfg"])
        candidate = esp_mount / "EFI/pond"
        candidate.mkdir(parents=True, exist_ok=False)
        boot_dir = candidate
        loader = candidate / "grubx64.efi"
        shutil.copyfile(target / "root/grubx64.efi", loader)
        if not loader.stat().st_size:
            raise InstallError("Pond's EFI loader is empty")
        (target / "root/grubx64.efi").unlink()
        run(["sync"])
        # Read back even on failure: firmware may have created an entry before
        # reporting an error. Only our new Pond entry is eligible for cleanup.
        result = run(["efibootmgr", "--create", "--disk", plan.disk.path,
                      "--part", str(esp.number), "--label", "Pond", "--loader", r"\EFI\pond\grubx64.efi"], check=False)
        after_entries, _ = _firmware()
        added = [n for n, label in after_entries.items() if n not in before_entries and label == "Pond"]
        if len(added) == 1:
            entry = added[0]
        if result.returncode or entry is None:
            raise InstallError("Pond's persistent firmware entry could not be created")
        details = run(["efibootmgr", "--verbose"]).stdout.casefold()
        line = next((line for line in details.splitlines() if line.startswith(f"boot{entry.lower()}")), "")
        if (f"hd({esp.number},gpt,{esp.uuid}," not in line
                or not re.search(r"/(?:file\()?\\efi\\pond\\grubx64\.efi(?:\)|$)", line)):
            raise InstallError("Pond's firmware entry points to an unexpected target")
        run(["efibootmgr", "--bootorder", ",".join([entry] + [n for n in before_order.split(",") if n and n != entry])])
        if run(["efibootmgr", "--bootnext", entry], check=False).returncode:
            warnings.append("One-time boot selection failed; the persistent Pond entry is installed")
        committed = True
        progress(0.99)
    finally:
        # Cleanup must finish even if cancellation arrives after another error.
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)

        def cleanup_command(argv):
            try:
                return run(argv, check=False).returncode
            except OSError:
                return 127

        if (target / "etc/pacman.d/gnupg").is_dir():
            cleanup_command(["arch-chroot", str(target), "gpgconf", "--homedir", "/etc/pacman.d/gnupg", "--kill", "all"])
        if not committed:
            if entry:
                if cleanup_command(["efibootmgr", "--bootnum", entry, "--delete-bootnum"]):
                    warnings.append("Firmware entry cleanup failed")
            if boot_dir is not None:
                try:
                    shutil.rmtree(boot_dir)
                except OSError:
                    warnings.append("EFI file cleanup failed")
        unmounted = True
        for mount in (esp_mount, target):
            if cleanup_command(["mountpoint", "-q", str(mount)]) != 32:
                if cleanup_command(["umount", "-R", str(mount)]):
                    warnings.append("An installation filesystem could not be unmounted")
                    unmounted = False
            with suppress(OSError):
                mount.rmdir()
        if not committed and unmounted:
            try:
                storage.remove_created(plan.disk, created)
            except InstallError as error:
                warnings.append(str(error))
        if not committed and warnings:
            raise InstallError("Installation failed and cleanup needs attention: " + "; ".join(warnings))
    return Installed(entry, tuple(warnings))


def install(plan: Plan, profile: Profile, archive: Path, progress=lambda value: None) -> Installed:
    """Install in the dedicated child process, with a private mount namespace.

    The caller owns archive acquisition and must keep its contents unchanged
    until this call returns. A failed replacement cannot recover erased data.
    Power-loss resume is not supported.
    """
    profile.validate()
    archive = Path(archive).resolve(strict=True)
    fd = os.open("/run/pond-installer.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise InstallError("Another Pond installation is in progress") from error
        return _execute(plan, profile, archive, progress)
