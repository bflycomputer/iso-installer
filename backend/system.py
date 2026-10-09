"""Rootfs acquisition, filesystem creation, and installed-system configuration."""

import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile

from .command import identifier, run
from .model import InstallError, ROOTFS_SHA256, ROOTFS_URL, SUBVOLUMES

ASSETS = Path(__file__).parent / "assets"


def verify_rootfs(archive):
    with Path(archive).open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    if digest != ROOTFS_SHA256:
        raise InstallError("Pond rootfs checksum verification failed")


def fetch_rootfs(directory: Path) -> Path:
    """Download into caller-owned scratch space; installation verifies the checksum."""
    directory = Path(directory)
    with tempfile.NamedTemporaryFile(dir=directory, prefix="pond-rootfs-", suffix=".tar.zst", delete=False) as out:
        path = Path(out.name)
        try:
            run(["curl", "--fail", "--location", "--proto", "=https", "--retry", "3",
                 "--retry-all-errors", "--progress-bar", "--output", str(path), ROOTFS_URL], stderr=sys.stderr)
        except BaseException:
            path.unlink(missing_ok=True)
            raise
    return path


def fstab(root_uuid, esp_uuid):
    for value in (root_uuid, esp_uuid):
        if not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", value):
            raise InstallError("Invalid filesystem or EFI partition UUID")
    lines = [f"UUID={root_uuid}  {mount}  btrfs  rw,relatime,compress=zstd:1,subvol={sub}  0 0\n"
             for sub, mount in SUBVOLUMES]
    return "".join(lines) + "tmpfs  /tmp  tmpfs  defaults,noatime,mode=1777  0 0\n" + \
        f"PARTUUID={esp_uuid}  /boot/efi  vfat  umask=0077,nofail  0 1\n"


def mount_root(root, target):
    run(["wipefs", "--all", root.path])
    run(["mkfs.btrfs", "-f", "-L", "POND_ROOT", "-O", "^block-group-tree", root.path])
    run(["mount", "-o", "compress=zstd:1", root.path, str(target)])
    for sub, _ in SUBVOLUMES:
        run(["btrfs", "subvolume", "create", str(target / sub)])
    run(["umount", str(target)])
    run(["mount", "-o", "compress=zstd:1,subvol=@", root.path, str(target)])
    for sub, mount in SUBVOLUMES[1:]:
        path = target / mount.lstrip("/")
        path.mkdir(parents=True, exist_ok=True)
        run(["mount", "-o", f"compress=zstd:1,subvol={sub}", root.path, str(path)])
    (target / ".snapshots").chmod(0o750)


def configure_hardware(target, progress=lambda value: None):
    prefix = ["arch-chroot", str(target)]
    # Refresh and upgrade the rootfs before installing hardware packages.
    for args in (["pacman", "-Sy"], ["pacman", "-Su", "--noconfirm", "--disable-download-timeout"]):
        for _ in range(7):  # Initial attempt plus six retries.
            result = run(prefix + args, check=False)
            if result.returncode == 0:
                break
        else:
            raise InstallError(f"pacman failed (exit {result.returncode})")
    run(prefix + ["chwd", "--autoconfigure"])
    progress(0.90)
    run(prefix + ["bash", "-c", "sed -i '/^HOOKS=/ { /[ (]autodetect[ )]/! s/ systemd / systemd autodetect /; }' /etc/mkinitcpio.conf.d/*pond.conf"])
    run(prefix + ["mkinitcpio", "-P"])


def provision(target, root, esp, archive, profile, progress=lambda value: None):
    run(["bsdtar", "--numeric-owner", "--acls", "--xattrs", "-xpf", str(archive), "-C", str(target)])
    progress(0.78)
    (target / "boot/efi").mkdir(parents=True, exist_ok=True)
    root_uuid = identifier(["blkid", "-s", "UUID", "-o", "value", root.path])
    (target / "etc/fstab").write_text(fstab(root_uuid, esp.uuid))
    prefix = ["arch-chroot", str(target)]
    read_profile = "set -euo pipefail\n" + "\n".join(
        f"IFS= read -r POND_{name}" for name in ("USERNAME", "PASSWORD", "TIMEZONE", "HOSTNAME")) + "\n"
    run(prefix + ["bash", "-c", read_profile + (ASSETS / "configure.sh").read_text()], input=profile.credentials())
    run(prefix + ["python", "-c", (ASSETS / "apply-settings.py").read_text()], input=json.dumps(profile.settings()))
    network = target / "etc/NetworkManager/system-connections"
    network.mkdir(parents=True, exist_ok=True, mode=0o700)
    for connection in Path("/etc/NetworkManager/system-connections").glob("*.nmconnection"):
        shutil.copy2(connection, network / connection.name)
    progress(0.82)
    configure_hardware(target, progress)
    progress(0.95)
    stub = target / "root/pond-grub-stub.cfg"
    stub.write_text(
        "insmod part_gpt\n"
        "insmod btrfs\n"
        f"search --no-floppy --fs-uuid --set=root {root_uuid}\n"
        "configfile ($root)/@/boot/grub/grub.cfg\n"
    )
    run(prefix + ["grub-mkstandalone", "--format=x86_64-efi", "--output=/root/grubx64.efi",
                  "--locales=", "--fonts=unicode", "boot/grub/grub.cfg=/root/pond-grub-stub.cfg"])
    stub.unlink()
    for artifact in ("root/grubx64.efi", "boot/vmlinuz-linux-pond", "boot/initramfs-linux-pond.img",
                     "boot/vmlinuz-linux-pond-lts", "boot/initramfs-linux-pond-lts.img"):
        if not (target / artifact).is_file() or (target / artifact).stat().st_size == 0:
            raise InstallError("A required boot artifact is missing")
