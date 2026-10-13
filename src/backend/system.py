"""Rootfs acquisition, filesystem creation, and installed-system configuration."""

import hashlib
from pathlib import Path
import re
import shutil
import sys

from .command import run
from .model import InstallError, ROOTFS_SHA256, ROOTFS_URL, SUBVOLUMES

ASSETS = Path(__file__).parent / "assets"


def verify_rootfs(archive):
    with Path(archive).open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    if digest != ROOTFS_SHA256:
        raise InstallError("Pond rootfs checksum verification failed")


def fetch_rootfs(directory: Path) -> Path:
    """Download into caller-owned scratch space; installation verifies the checksum."""
    path = Path(directory) / "pond-rootfs.tar.zst"
    run(["curl", "--fail", "--location", "--proto", "=https", "--retry", "3",
         "--retry-all-errors", "--progress-bar", "--output", str(path), ROOTFS_URL], stderr=sys.stderr)
    return path


def fstab(root_uuid, esp_uuid=None):
    for value in (root_uuid,) if esp_uuid is None else (root_uuid, esp_uuid):
        if not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", value):
            raise InstallError("Invalid filesystem or EFI partition UUID")
    lines = [f"UUID={root_uuid}  {mount}  btrfs  rw,relatime,compress=zstd:1,subvol={sub}  0 0\n"
             for sub, mount in SUBVOLUMES]
    return "".join(lines) + "tmpfs  /tmp  tmpfs  defaults,noatime,mode=1777  0 0\n" + \
        (f"PARTUUID={esp_uuid}  /boot/efi  vfat  umask=0077,nofail  0 1\n" if esp_uuid else "")


def mount_root(root, target):
    run(["wipefs", "--all", root.path])
    run(["mkfs.btrfs", "-f", "-L", "POND_ROOT", "-O", "^block-group-tree", root.path])
    run(["mount", "-t", "btrfs", "-o", "compress=zstd:1", root.path, str(target)])
    for sub, _ in SUBVOLUMES:
        run(["btrfs", "subvolume", "create", str(target / sub)])
    run(["umount", str(target)])
    run(["mount", "-t", "btrfs", "-o", "compress=zstd:1,subvol=@", root.path, str(target)])
    for sub, mount in SUBVOLUMES[1:]:
        path = target / mount.lstrip("/")
        path.mkdir(parents=True, exist_ok=True)
        run(["mount", "-t", "btrfs", "-o", f"compress=zstd:1,subvol={sub}", root.path, str(path)])
    (target / ".snapshots").chmod(0o750)


def configure_locale(target, locale):
    supported = {line.split()[0] for line in (target / "usr/share/i18n/SUPPORTED").read_text().splitlines()
                 if line.endswith(" UTF-8")}
    if locale not in supported:
        raise InstallError("Unsupported locale")
    (target / "etc/locale.gen").write_text(f"{locale} UTF-8\n")
    run(["arch-chroot", str(target), "locale-gen"])
    (target / "etc/locale.conf").write_text(f"LANG={locale}\nLC_MESSAGES={locale}\n")


def configure_keyboard(target, layout):
    directory = target / "etc/X11/xorg.conf.d"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "00-keyboard.conf").write_text(
        'Section "InputClass"\n    Identifier "system-keyboard"\n    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{layout}"\n    Option "XkbVariant" ""\nEndSection\n'
    )
    # systemd-localed reads 00-keyboard.conf; niri and the login screen use it.
    for line in (target / "usr/share/systemd/kbd-model-map").read_text().splitlines():
        fields = line.split()
        if len(fields) >= 4 and fields[1] == layout and fields[3] == "-":
            (target / "etc/vconsole.conf").write_text(f"KEYMAP={fields[0]}\n")
            break


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
    root_uuid = run(["blkid", "-s", "UUID", "-o", "value", root.path]).stdout.strip()
    (target / "etc/fstab").write_text(fstab(root_uuid, esp.uuid if esp else None))
    prefix = ["arch-chroot", str(target)]
    read_profile = "set -euo pipefail\n" + "\n".join(
        f"IFS= read -r POND_{name}" for name in ("USERNAME", "PASSWORD", "TIMEZONE", "HOSTNAME")) + "\n"
    run(prefix + ["bash", "-c", read_profile + (ASSETS / "configure.sh").read_text()], input=profile.credentials())
    configure_locale(target, profile.locale)
    configure_keyboard(target, profile.keyboard_layout)
    network = target / "etc/NetworkManager/system-connections"
    network.mkdir(parents=True, exist_ok=True, mode=0o700)
    for connection in Path("/etc/NetworkManager/system-connections").glob("*.nmconnection"):
        shutil.copy2(connection, network / connection.name)
    progress(0.82)
    configure_hardware(target, progress)
    progress(0.95)
    artifacts = ["boot/vmlinuz-linux-pond", "boot/initramfs-linux-pond.img",
                 "boot/vmlinuz-linux-pond-lts", "boot/initramfs-linux-pond-lts.img"]
    if esp is not None:
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
        artifacts.append("root/grubx64.efi")
    for artifact in artifacts:
        if not (target / artifact).is_file() or (target / artifact).stat().st_size == 0:
            raise InstallError("A required boot artifact is missing")
