"""Present backend storage plans without making a second set of storage rules."""
from pathlib import Path

import backend
from backend.model import max_allocation_gib


def size_label(value):
    return f'{value / 1e12:.1f} TB' if value >= 1e12 else f'{value / 1e9:.1f} GB'


def drive_row(disk):
    used = sum(p.size for p in disk.partitions)
    try:
        name = (Path('/sys/class/block') / Path(disk.path).name / 'device/model').read_text().strip()
    except OSError:
        name = ''
    return {'name': name or Path(disk.path).name,
            'detail': f'{len(disk.partitions)} partitions' if disk.partitions else 'Empty',
            'capacity': size_label(disk.size), 'used': size_label(used),
            'available': size_label(max(0, disk.size - used)),
            'capacityBytes': disk.size, 'usedBytes': used, 'empty': not disk.partitions}


def options(disk):
    if disk is None:
        return []
    choices = []
    for mode in (backend.Mode.FREE_SPACE, backend.Mode.REPLACE):
        if mode is backend.Mode.FREE_SPACE and not disk.partitions:
            continue
        try:
            plan = backend.plan_install(disk, mode, max_allocation_gib(disk) if mode is backend.Mode.FREE_SPACE else None)
        except backend.InstallError:
            continue
        choices.append({'mode': mode.value, 'plan': plan, 'preservesEfi': plan.esp is not None})
    return choices
