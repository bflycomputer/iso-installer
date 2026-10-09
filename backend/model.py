"""Installation settings, disk descriptions, and storage planning."""

from dataclasses import dataclass, field
from enum import Enum
import re

USERNAME = re.compile(r"[a-z_][a-z0-9_-]{0,31}")
HOSTNAME = re.compile(r"[A-Za-z0-9_](?:[A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?")
MAX_PASSWORD_LENGTH = 128
MIN_ALLOCATION_GIB = 20

GIB = 1024**3
MIB = 1024**2
ESP_BYTES = 512 * MIB
ESP_TYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
ROOT_TYPE = "0fc63daf-8483-4772-8e79-3d69d8477de4"
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


@dataclass(frozen=True)
class Wifi:
    ssid: bytes
    password: str = field(repr=False)
    key_management: str = "wpa-psk"


@dataclass(frozen=True)
class Profile:
    username: str
    password: str = field(repr=False)
    hostname: str
    timezone: str = "UTC"
    locale: str = "en_US.UTF-8"
    language: str = "en_US.UTF-8"
    keyboard_layout: str = "us"
    keyboard_variant: str = ""
    wifi: Wifi | None = field(default=None, repr=False)

    def validate(self):
        if not isinstance(self.username, str) or not USERNAME.fullmatch(self.username):
            raise InstallError("Invalid username")
        if not isinstance(self.hostname, str) or not HOSTNAME.fullmatch(self.hostname):
            raise InstallError("Invalid computer name")
        if not isinstance(self.password, str) or not 1 <= len(self.password) <= MAX_PASSWORD_LENGTH or any(c in self.password for c in "\n\r\0"):
            raise InstallError("Invalid password")
        if not all(isinstance(v, str) for v in (self.timezone, self.locale, self.language,
                                               self.keyboard_layout, self.keyboard_variant)):
            raise InstallError("Invalid regional settings")
        for value in (self.locale, self.language):
            if not re.fullmatch(r"[A-Za-z0-9_.@-]+", value):
                raise InstallError("Invalid locale")
        if not re.fullmatch(r"[a-z0-9_-]+", self.keyboard_layout) or not re.fullmatch(r"[a-z0-9_-]*", self.keyboard_variant):
            raise InstallError("Invalid keyboard layout")
        if self.wifi is not None:
            if (not isinstance(self.wifi, Wifi) or not isinstance(self.wifi.ssid, bytes)
                    or not 1 <= len(self.wifi.ssid) <= 32 or not isinstance(self.wifi.password, str)
                    or self.wifi.key_management not in ("wpa-psk", "sae")):
                raise InstallError("Invalid network settings")

    def credentials(self):
        zone = self.timezone
        if any(c in zone for c in "\n\r\0") or any(p in ("", ".", "..") for p in zone.split("/")):
            zone = "UTC"
        return "\n".join((self.username, self.password, zone, self.hostname)) + "\n"

    def settings(self):
        return {"locale": self.locale, "language": self.language,
                "layout": self.keyboard_layout, "variant": self.keyboard_variant,
                "wifi": None if self.wifi is None else {
                    "ssid_hex": self.wifi.ssid.hex(), "psk": self.wifi.password,
                    "key_management": self.wifi.key_management}}


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
    allocation_gib: int | None
    root_start: int
    root_size: int
    esp: Partition | None
    esp_start: int | None


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


def max_allocation_gib(disk):
    return max((size // GIB for _, size in gaps(disk.size, disk.partitions)), default=0)


def plan_install(disk: Disk, mode: Mode, allocation_gib: int | None = None) -> Plan:
    if not isinstance(mode, Mode):
        raise InstallError("Unknown installation mode")
    if disk.busy or disk.read_only or not disk.identity or disk.size < 21 * GIB:
        raise InstallError("The selected disk is unavailable or in use")
    esps = [p for p in disk.partitions if p.kind == ESP_TYPE]
    if len(esps) > 1:
        raise InstallError("Multiple EFI partitions; cannot select one unambiguously")
    esp = esps[0] if esps else None
    if mode is Mode.FREE_SPACE and disk.table != "gpt":
        raise InstallError("Free-space installation requires GPT")
    parts = disk.partitions if mode is Mode.FREE_SPACE else esps
    regions = gaps(disk.size, parts)
    if not regions:
        raise InstallError("No contiguous unallocated space")
    start, available = max(regions, key=lambda r: r[1])
    esp_bytes = 0 if esp else ESP_BYTES
    if mode is Mode.FREE_SPACE:
        if type(allocation_gib) is not int or not MIN_ALLOCATION_GIB <= allocation_gib <= available // GIB:
            raise InstallError(f"Allocation must fit the largest free region and be at least {MIN_ALLOCATION_GIB} GiB")
        total = allocation_gib * GIB
    else:
        if allocation_gib is not None:
            raise InstallError("Replacement uses the available space; do not specify an allocation")
        total = available
        if total - esp_bytes < MIN_ALLOCATION_GIB * GIB:
            raise InstallError("Not enough space remains after preserving EFI partitions")
    return Plan(disk, mode, allocation_gib, start + esp_bytes, total - esp_bytes, esp, None if esp else start)
