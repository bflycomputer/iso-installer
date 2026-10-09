"""Private installation process. Requests arrive on stdin, never command arguments."""
from dataclasses import asdict
import json
import os
from pathlib import Path
import signal
import sys
import tempfile

import backend
from backend.model import Partition
from backend.storage import revalidate


def request(plan, profile):
    data = asdict(profile)
    data.pop('wifi')
    return {'disk': asdict(plan.disk), 'mode': plan.mode.value,
            'allocation_gib': plan.allocation_gib, 'profile': data}


def decode(data):
    disk = dict(data['disk'])
    disk['partitions'] = tuple(Partition(**part) for part in disk['partitions'])
    plan = backend.plan_install(backend.Disk(**disk), backend.Mode(data['mode']), data['allocation_gib'])
    profile = backend.Profile(**data['profile'])
    return plan, profile


def execute(data, report):
    if os.geteuid() != 0 or not Path('/etc/pond-installer-live').is_file():
        raise backend.InstallError('Installation requires the Pond live environment as root')
    plan, profile = decode(data)
    # Reject an outdated confirmation before downloading the payload.
    revalidate(plan.disk)
    def progress(value):
        report({'type': 'progress', 'value': value})

    with tempfile.TemporaryDirectory(prefix='pond-download-', dir='/var/tmp') as directory:
        progress(0.04)
        archive = backend.fetch_rootfs(Path(directory))
        result = backend.install(plan, profile, archive, progress)
    progress(1)
    report({'type': 'done', 'warnings': list(result.warnings)})


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
        execute(json.load(sys.stdin), report)
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
