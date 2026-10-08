"""Native storage discovery and writes; callers retain immutable disk identities."""

import json
import re
from pathlib import Path

from .command import run
from .model import Disk, Partition, Plan, Mode, InstallError, ESP_BYTES, ESP_TYPE, ROOT_TYPE


def blockdev():
    import gi
    gi.require_version("BlockDev", "3.0")
    from gi.repository import BlockDev
    if not BlockDev.is_initialized():
        BlockDev.init([BlockDev.PluginSpec.new(BlockDev.Plugin.PART, None)])
    if not BlockDev.is_plugin_available(BlockDev.Plugin.PART):
        raise InstallError("Partition support is unavailable")
    return BlockDev


def _descendants(device):
    yield device
    for child in device.get("children", ()):
        yield from _descendants(child)


def probe() -> tuple[Disk, ...]:
    bd = blockdev()
    rows = json.loads(run(["lsblk", "--json", "--bytes", "--tree", "--output",
        "PATH,TYPE,SIZE,LOG-SEC,WWN,SERIAL,MAJ:MIN,RO,PTTYPE,FSTYPE,MOUNTPOINTS"]).stdout)["blockdevices"]
    disks = []
    for row in rows:
        if row["type"] != "disk" or not row["size"]:
            continue
        children = list(_descendants(row))
        busy = any(any(m for m in (d.get("mountpoints") or [])) for d in children)
        busy |= any(d["type"] not in ("disk", "part") for d in children)
        identity = (row.get("wwn") or row.get("serial") or "").strip()
        table = row.get("pttype") or ""
        parts = []
        if table:
            by_path = {d["path"]: d for d in children}
            for p in bd.part.get_disk_parts(row["path"]):
                node = by_path.get(p.path)
                if node is None or node["type"] != "part":
                    busy = True
                    continue
                number = int((Path("/sys/class/block") / Path(p.path).name / "partition").read_text())
                parts.append(Partition(p.path, number, (p.uuid or "").lower(),
                    (p.type_guid or "").lower(), p.start, p.size, node.get("fstype") or ""))
        disks.append(Disk(row["path"], identity, row["maj:min"], row["size"], row["log-sec"], table,
                          tuple(sorted(parts, key=lambda p: p.start)), busy, bool(row["ro"])))
    return tuple(disks)


def revalidate(expected: Disk):
    matches = [d for d in probe() if d.identity == expected.identity]
    if len(matches) != 1 or matches[0] != expected:
        raise InstallError("The selected disk changed; prepare a new installation plan")


def current_partition(disk: Disk, expected: Partition, *, check_type=True):
    matches = [d for d in probe() if d.identity == disk.identity]
    if len(matches) != 1:
        raise InstallError("The selected disk disappeared or its identity is ambiguous")
    now = matches[0]
    if (now.path, now.device_number, now.size, now.sector_size) != (
            disk.path, disk.device_number, disk.size, disk.sector_size):
        raise InstallError("The selected disk identity changed")
    actual = next((p for p in now.partitions if p.uuid == expected.uuid), None)
    if actual is None or (actual.path, actual.number, actual.start, actual.size) != (
            expected.path, expected.number, expected.start, expected.size):
        raise InstallError("The target partition changed")
    if check_type and actual.kind != expected.kind:
        raise InstallError("The target partition type changed")
    return actual


def create_partitions(plan: Plan, created: list[Partition]):
    bd = blockdev()
    revalidate(plan.disk)
    if plan.mode is Mode.REPLACE:
        if plan.disk.table == "gpt":
            for p in plan.disk.partitions:
                if p.kind != ESP_TYPE:
                    current_partition(plan.disk, p)
                    bd.part.delete_part(plan.disk.path, p.path)
        else:
            run(["wipefs", "--all", plan.disk.path])
            bd.part.create_table(plan.disk.path, bd.PartTableType.GPT, True)

    def create(start, size, kind):
        p = bd.part.create_part(plan.disk.path, bd.PartTypeReq.NORMAL, start, size, bd.PartAlign.OPTIMAL)
        # Keep ownership before any fallible command or read-back. The returned
        # GPT UUID and extent identify this allocation even if udev fails.
        number = int(re.search(r"[0-9]+$", p.path).group())
        created.append(Partition(p.path, number, (p.uuid or "").lower(),
                                 (p.type_guid or "").lower(), p.start, p.size))
        run(["udevadm", "settle"])
        part = current_partition(plan.disk, created[-1], check_type=False)
        created[-1] = part
        if part.start != start or part.size != size or not part.uuid:
            raise InstallError("The created partition does not match the planned extent")
        bd.part.set_part_type(plan.disk.path, part.path, kind)
        part = current_partition(plan.disk, created[-1], check_type=False)
        created[-1] = part
        if part.kind != kind:
            raise InstallError("The partition type was not applied")
        return part

    esp = plan.esp or create(plan.esp_start, ESP_BYTES, ESP_TYPE)
    root = create(plan.root_start, plan.root_size, ROOT_TYPE)
    return esp, root


def remove_created(disk, created):
    failures = []
    for partition in reversed(created):
        try:
            current_partition(disk, partition, check_type=False)
            blockdev().part.delete_part(disk.path, partition.path)
        except Exception:
            failures.append(partition.uuid)
    if failures:
        raise InstallError("Cleanup could not remove all owned partitions; recovery is required")
