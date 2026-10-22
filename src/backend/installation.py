"""Synchronous installation for the dedicated installation process."""

from contextlib import suppress
import fcntl
import os
from pathlib import Path
import shutil
import signal
import tempfile

from .command import run
from .model import BootMode, InstallError, Plan, Profile
from . import system, storage


def _preflight():
    if os.geteuid() != 0 or not Path("/etc/pond-installer-live").is_file():
        raise InstallError("Installation requires the installer live environment as root")
    required = ("lsblk", "udevadm", "wipefs", "mkfs.btrfs", "mkfs.fat", "btrfs", "blkid",
                "mount", "mountpoint", "umount", "bsdtar", "arch-chroot", "efibootmgr", "sync")
    if any(shutil.which(command) is None for command in required):
        raise InstallError("The live environment is missing an installation dependency")


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
    run(["mount", "-t", "vfat", "-o", "ro,nosuid,nodev,noexec,umask=0077", plan.esp.path, str(mount)])
    try:
        space = os.statvfs(mount)
        if space.f_bavail * space.f_frsize < 32 * 1024**2:
            raise InstallError("The EFI partition needs at least 32 MiB free")
    finally:
        run(["umount", str(mount)])


def _execute(plan, profile, progress, archive=None):
    _preflight()
    os.unshare(os.CLONE_NEWNS)
    run(["mount", "--make-rprivate", "/"])
    target = Path(tempfile.mkdtemp(prefix="pond-target-", dir="/mnt"))
    esp_mount = Path(tempfile.mkdtemp(prefix="pond-esp-", dir="/mnt"))
    created = []
    boot_dir = None
    committed = False
    warnings = []
    uefi = plan.boot_mode is BootMode.UEFI
    try:
        if uefi:
            _validate_esp(plan, esp_mount)
        boot, root = storage.create_partitions(plan, created)
        storage.current_partition(plan.disk, root)
        system.mount_root(root, target)
        progress(0.04)
        if archive is None:
            archive = system.fetch_rootfs(target / "var/tmp")
            system.verify_rootfs(archive)
        progress(0.60)
        system.provision(target, root, boot if uefi else None, archive, profile, progress)
        storage.current_partition(plan.disk, boot)
        if uefi:
            esp = boot
            # Update the ESP only after configuring the target system.
            if plan.esp is None:
                run(["wipefs", "--all", esp.path])
                run(["mkfs.fat", "-F", "32", "-n", "Pond EFI", esp.path])
            run(["mount", "-t", "vfat", "-o", "umask=0077", esp.path, str(esp_mount)])
            run(["mount", "--bind", str(esp_mount), str(target / "boot/efi")])
        run(["arch-chroot", str(target), "/usr/share/libalpm/scripts/pond-grub-update"])
        if not (target / "boot/grub/grub.cfg").stat().st_size:
            raise InstallError("Pond's boot menu is empty")
        run(["arch-chroot", str(target), "grub-script-check", "/boot/grub/grub.cfg"])
        if uefi:
            candidate = esp_mount / "EFI/pond"
            candidate.mkdir(parents=True, exist_ok=True)
            boot_dir = candidate
            loader = candidate / "grubx64.efi"
            shutil.copyfile(target / "root/grubx64.efi", loader)
            if not loader.stat().st_size:
                raise InstallError("Pond's EFI loader is empty")
            (esp_mount / "EFI/BOOT").mkdir(exist_ok=True)
            shutil.copyfile(loader, esp_mount / "EFI/BOOT/BOOTX64.EFI")
            (target / "root/grubx64.efi").unlink()
            run(["sync"])
            run(["efibootmgr", "--create", "--disk", plan.disk.path,
                 "--part", str(esp.number), "--label", "Pond", "--loader", r"\EFI\pond\grubx64.efi"])
        else:
            run(["arch-chroot", str(target), "grub-install", "--target=i386-pc", "--recheck", plan.disk.path])
            run(["sync"])
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
        if not committed and boot_dir is not None:
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
    return tuple(warnings)


def install(plan: Plan, profile: Profile, progress=lambda value: None, archive=None) -> tuple[str, ...]:
    """Install in the dedicated child process, with a private mount namespace.

    A failed replacement cannot recover erased data. Power-loss resume is not supported.
    """
    profile.validate()
    fd = os.open("/run/pond-installer.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise InstallError("Another Pond installation is in progress") from error
        return _execute(plan, profile, progress, archive)
