"""Installation settings, disk descriptions, and storage planning."""

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import re

USERNAME = re.compile(r"[a-z_][a-z0-9_-]{0,31}")
HOSTNAME = re.compile(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?")
MAX_PASSWORD_LENGTH = 128
MIN_ALLOCATION_GIB = 20

GIB = 1024**3
MIB = 1024**2
ESP_BYTES = 512 * MIB
ESP_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
ROOT_TYPE = "0fc63daf-8483-4772-8e79-3d69d8477de4"
BIOS_TYPE = "21686148-6449-6e6f-744e-656564454649"
ROOTFS_SHA256 = "8c07d67d3b8ed9a9ea0271d7f3ce77081e0d1f01539332fb0849e967a0ff9fef"
ROOTFS_URL = f"https://releases.butterfly.so/rootfs/{ROOTFS_SHA256}/pond-rootfs.tar.zst"
SUBVOLUMES = (
    ("@", "/"), ("@home", "/home"), ("@root", "/root"), ("@srv", "/srv"),
    ("@log", "/var/log"), ("@cache", "/var/cache"), ("@tmp", "/var/tmp"),
    ("@nix", "/nix"), ("@flatpak", "/var/lib/flatpak"),
    ("@usr-local", "/usr/local"), ("@snapshots", "/.snapshots"),
)


class InstallError(RuntimeError):
    """Installation failed; no password or network secret belongs in this error."""


class Mode(Enum):
    FREE_SPACE = "free-space"
    REPLACE = "replace"


class BootMode(Enum):
    UEFI = "uefi"
    BIOS = "bios"


def current_boot_mode():
    return BootMode.UEFI if Path("/sys/firmware/efi").is_dir() else BootMode.BIOS


@dataclass(frozen=True)
class Profile:
    username: str
    password: str = field(repr=False)
    hostname: str
    timezone: str = "UTC"
    locale: str = "en_US.UTF-8"
    keyboard_layout: str = "us"

    def validate(self):
        if not isinstance(self.username, str) or not USERNAME.fullmatch(self.username):
            raise InstallError("Invalid username")
        if not isinstance(self.hostname, str) or not HOSTNAME.fullmatch(self.hostname):
            raise InstallError("Invalid computer name")
        if not isinstance(self.password, str) or not 1 <= len(self.password) <= MAX_PASSWORD_LENGTH or any(c in self.password for c in "\n\r\0"):
            raise InstallError("Invalid password")
        if not all(isinstance(v, str) for v in (self.timezone, self.locale, self.keyboard_layout)):
            raise InstallError("Invalid regional settings")
        if not re.fullmatch(r"[A-Za-z0-9_.@-]+", self.locale):
            raise InstallError("Invalid locale")
        if not re.fullmatch(r"[a-z0-9_-]+", self.keyboard_layout):
            raise InstallError("Invalid keyboard layout")

    def credentials(self):
        zone = self.timezone
        if any(c in zone for c in "\n\r\0") or any(p in ("", ".", "..") for p in zone.split("/")):
            zone = "UTC"
        return "\n".join((self.username, self.password, zone, self.hostname)) + "\n"


@dataclass(frozen=True)
class Partition:
    path: str
    number: int
    uuid: str
    kind: str
    start: int
    size: int
    filesystem: str = ""


@dataclass(frozen=True)
class Disk:
    path: str
    identity: str
    device_number: str
    size: int
    sector_size: int
    table: str
    partitions: tuple[Partition, ...]
    busy: bool = False
    read_only: bool = False


@dataclass(frozen=True)
class Plan:
    disk: Disk
    mode: Mode
    root_start: int
    root_size: int
    esp: Partition | None
    boot_start: int | None
    boot_mode: BootMode
    bios: Partition | None


def gaps(size, partitions):
    """Find whole-MiB free regions, reserving space for GPT metadata at both ends."""
    end = MIB
    result = []
    for start, length in [(p.start, p.size) for p in sorted(partitions, key=lambda p: p.start)] + [(size - MIB, 0)]:
        aligned = (end + MIB - 1) // MIB * MIB
        length_free = start // MIB * MIB - aligned
        if length_free > 0:
            result.append((aligned, length_free))
        end = max(end, start + length)
    return result


def plan_install(disk: Disk, mode: Mode, *, boot_mode: BootMode = BootMode.UEFI) -> Plan:
    if disk.busy or disk.read_only or not disk.identity:
        raise InstallError("The selected disk is unavailable or in use")
    if disk.size < 21 * GIB:
        raise InstallError("Pond needs at least 20GB of space")
    esps = [p for p in disk.partitions if p.kind == ESP_TYPE]
    if boot_mode is BootMode.UEFI and len(esps) > 1:
        raise InstallError(f"This disk has {len(esps)} EFI partitions, wipe it before attempting to install")
    esp = esps[0] if esps else None
    if mode is Mode.FREE_SPACE and disk.table != "gpt":
        raise InstallError("Free-space installation requires GPT")
    parts = disk.partitions if mode is Mode.FREE_SPACE else esps
    regions = gaps(disk.size, parts)
    if not regions:
        raise InstallError("No contiguous unallocated space")
    start, available = max(regions, key=lambda r: r[1])
    bios = None
    if boot_mode is BootMode.BIOS and mode is Mode.FREE_SPACE:
        boots = [p for p in disk.partitions if p.kind == BIOS_TYPE]
        if len(boots) > 1:
            raise InstallError("The disk has multiple BIOS boot partitions")
        bios = boots[0] if boots else None
    boot_bytes = (0 if bios else MIB) if boot_mode is BootMode.BIOS else (0 if esp else ESP_BYTES)
    if mode is Mode.FREE_SPACE:
        total = available // GIB * GIB
        if total < MIN_ALLOCATION_GIB * GIB:
            raise InstallError(f"Allocation must fit the largest free region and be at least {MIN_ALLOCATION_GIB} GiB")
    else:
        total = available
        if total - boot_bytes < MIN_ALLOCATION_GIB * GIB:
            raise InstallError("Not enough space remains after preserving EFI partitions")
    return Plan(disk, mode, start + boot_bytes, total - boot_bytes,
                esp, start if boot_bytes else None, boot_mode, bios)
