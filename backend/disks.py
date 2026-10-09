"""Present backend storage plans without making a second set of storage rules."""
from pathlib import Path

import backend
from backend.model import ESP_TYPE, Partition, ROOT_TYPE, gaps


def size_label(value):
    return f'{value / 1e12:.1f} TB' if value >= 1e12 else f'{value / 1e9:.1f} GB'


def segments(disk, parts=None):
    parts = disk.partitions if parts is None else parts
    rows = []
    for i, part in enumerate(parts):
        rows.append({'path': part.path, 'firstSector': part.start // disk.sector_size,
                     'lastSector': (part.start + part.size) // disk.sector_size - 1,
                     'capacityFraction': part.size / disk.size, 'free': False,
                     'systemColorIndex': i % 3 + 1, 'isPlannedRoot': part.path == 'planned-root'})
    for start, size in gaps(disk.size, parts):
        rows.append({'firstSector': start // disk.sector_size,
                     'lastSector': (start + size) // disk.sector_size - 1,
                     'capacityFraction': size / disk.size, 'free': True})
    return sorted(rows, key=lambda row: row['firstSector'])


def drive_row(disk):
    used = sum(p.size for p in disk.partitions)
    try:
        name = (Path('/sys/class/block') / Path(disk.path).name / 'device/model').read_text().strip()
    except OSError:
        name = ''
    return {'name': name or Path(disk.path).name, 'path': disk.path,
            'detail': f'{disk.path} · {len(disk.partitions)} partitions' if disk.partitions else f'{disk.path} · Empty',
            'capacity': size_label(disk.size), 'used': size_label(used),
            'available': size_label(max(0, disk.size - used)),
            'capacityBytes': disk.size, 'usedBytes': used, 'empty': not disk.partitions}


def options(disk, allocation):
    if disk is None:
        return []
    choices = []
    for mode in (backend.Mode.FREE_SPACE, backend.Mode.REPLACE):
        if mode is backend.Mode.FREE_SPACE and not disk.partitions:
            continue
        try:
            plan = backend.plan_install(disk, mode, allocation if mode is backend.Mode.FREE_SPACE else None)
        except backend.InstallError:
            continue
        parts = list(disk.partitions if mode is backend.Mode.FREE_SPACE else ([plan.esp] if plan.esp else []))
        if plan.esp is None:
            parts.append(Partition('planned-efi', 0, '', ESP_TYPE, plan.esp_start, plan.root_start - plan.esp_start, 'vfat'))
        parts.append(Partition('planned-root', 0, '', ROOT_TYPE, plan.root_start, plan.root_size, 'btrfs'))
        free = mode is backend.Mode.FREE_SPACE
        choices.append({'mode': mode.value, 'plan': plan,
                        'detail': 'Keep existing partitions and choose space for Pond.' if free else
                                  'Keep EFI; erase all other partitions.' if plan.esp else
                                  'Erase all partitions.',
                        'rootBytes': plan.root_size, 'capacity': size_label(plan.root_size),
                        'preservesEfi': plan.esp is not None, 'plannedSegments': segments(disk, parts)})
    return choices
