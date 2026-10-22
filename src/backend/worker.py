"""Private installation process. Requests arrive on stdin, never command arguments."""
from dataclasses import asdict
import json
import os
from pathlib import Path
import signal
import sys
import tempfile

import backend
from backend import system
from backend.model import GIB, Partition
from backend.storage import revalidate


def request(plan, profile):
    return {'disk': asdict(plan.disk), 'mode': plan.mode.value,
            'boot_mode': plan.boot_mode.value, 'profile': asdict(profile)}


def decode(data):
    disk = dict(data['disk'])
    disk['partitions'] = tuple(Partition(**part) for part in disk['partitions'])
    plan = backend.plan_install(backend.Disk(**disk), backend.Mode(data['mode']),
                                boot_mode=backend.BootMode(data['boot_mode']))
    profile = backend.Profile(**data['profile'])
    return plan, profile


def prefetch(directory):
    if not Path('/etc/pond-installer-live').is_file() or os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') < 7 * GIB:
        return None
    try:
        archive = system.fetch_rootfs(directory)
        system.verify_rootfs(archive)
        return archive
    except backend.InstallError:
        for path in directory.iterdir():
            path.unlink()
        return None


def execute(data, report, archive=None):
    if os.geteuid() != 0 or not Path('/etc/pond-installer-live').is_file():
        raise backend.InstallError('Installation requires the installer live environment as root')
    plan, profile = decode(data)
    revalidate(plan.disk)
    def progress(value):
        report({'type': 'progress', 'value': value})

    warnings = backend.install(plan, profile, progress, archive)
    progress(1)
    report({'type': 'done', 'warnings': list(warnings)})


def main():
    os.setsid()

    def interrupt(*_):
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        raise KeyboardInterrupt

    signal.signal(signal.SIGINT, interrupt)
    signal.signal(signal.SIGTERM, interrupt)

    def report(event):
        print(json.dumps(event), flush=True)

    try:
        with tempfile.TemporaryDirectory(prefix='pond-rootfs-') as directory:
            archive = prefetch(Path(directory))
            execute(json.load(sys.stdin), report, archive)
    except KeyboardInterrupt:
        report({'type': 'error', 'message': 'Installation cancelled. Check the target before trying again.'})
        return 1
    except backend.InstallError as error:
        report({'type': 'error', 'message': str(error)})
        return 1
    except Exception:
        report({'type': 'error', 'message': 'Installation stopped unexpectedly. Check the target before trying again.'})
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
