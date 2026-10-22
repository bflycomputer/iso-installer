"""Present backend storage plans without making a second set of storage rules."""
from pathlib import Path

import backend


def size_label(value):
    return f'{value / 1e12:.1f} TB' if value >= 1e12 else f'{value / 1e9:.1f} GB'


def hotplug(device):
    for parent in device.parents:
        try:
            state = (parent / 'removable').read_text().strip()
        except OSError:
            continue
        if state in ('fixed', 'removable'):
            return state == 'removable'
    return False


def drive_kind(block):
    device = block.resolve()
    chain = device.as_posix()
    if '/usb' in chain:
        return 'External USB'
    if '/mmc_host/' in chain:
        return 'SD card' if (block / 'device/type').read_text().strip() == 'SD' else 'Internal eMMC'
    if '/nvme/' in chain:
        bus = 'NVMe SSD'
    elif '/ata' in chain:
        bus = 'SATA HDD' if (block / 'queue/rotational').read_text().strip() == '1' else 'SATA SSD'
    else:
        return ''
    return f"{'External' if hotplug(device) else 'Internal'} {bus}"


def drive_row(disk):
    used = sum(p.size for p in disk.partitions)
    block = Path('/sys/class/block') / Path(disk.path).name
    try:
        name = (block / 'device/model').read_text().strip()
    except OSError:
        name = ''
    try:
        kind = drive_kind(block)
    except OSError:
        kind = ''
    return {'name': name or Path(disk.path).name, 'kind': kind,
            'detail': ' • '.join(filter(None, (kind, '' if disk.partitions else 'Empty'))),
            'capacity': size_label(disk.size), 'used': size_label(used),
            'available': size_label(max(0, disk.size - used)),
            'capacityBytes': disk.size, 'usedBytes': used, 'empty': not disk.partitions}


def options(disk):
    if disk is None:
        return []
    choices, unavailable = [], []
    for mode in (backend.Mode.FREE_SPACE, backend.Mode.REPLACE):
        if mode is backend.Mode.FREE_SPACE and not disk.partitions:
            continue
        try:
            plan = backend.plan_install(disk, mode, boot_mode=backend.current_boot_mode())
        except backend.NoSpaceError:
            unavailable.append({'mode': mode.value, 'available': False})
            continue
        except backend.InstallError:
            continue
        choices.append({'mode': mode.value, 'plan': plan, 'preservesEfi': plan.esp is not None, 'available': True})
    return choices + unavailable
