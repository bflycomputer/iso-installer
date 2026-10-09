"""Private installation process. Requests arrive on stdin, never command arguments."""
from dataclasses import asdict, replace
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
    if profile.wifi is not None:
        data['wifi']['ssid'] = profile.wifi.ssid.hex()
    return {'disk': asdict(plan.disk), 'mode': plan.mode.value,
            'allocation_gib': plan.allocation_gib, 'profile': data}


def decode(data):
    disk = dict(data['disk'])
    disk['partitions'] = tuple(Partition(**part) for part in disk['partitions'])
    plan = backend.plan_install(backend.Disk(**disk), backend.Mode(data['mode']), data['allocation_gib'])
    values = dict(data['profile'])
    if values.get('wifi') is not None:
        wifi = dict(values['wifi'])
        wifi['ssid'] = bytes.fromhex(wifi['ssid'])
        values['wifi'] = backend.Wifi(**wifi)
    profile = backend.Profile(**values)
    return plan, profile


def connected_wifi():
    """Carry a connected personal Wi-Fi profile into Pond, when secrets are available."""
    import gi
    gi.require_version('NM', '1.0')
    from gi.repository import NM
    client = NM.Client.new(None)
    for active in client.get_active_connections():
        if active.get_state() != NM.ActiveConnectionState.ACTIVATED or active.get_connection_type() != '802-11-wireless':
            continue
        connection = active.get_connection()
        wireless = connection.get_setting_wireless()
        security = connection.get_setting_wireless_security()
        if wireless is None or security is None or security.get_key_mgmt() not in ('wpa-psk', 'sae'):
            continue
        secrets = connection.get_secrets('802-11-wireless-security', None).unpack()
        password = secrets.get('802-11-wireless-security', {}).get('psk', '')
        if password:
            return backend.Wifi(bytes(wireless.get_ssid().get_data()), password, security.get_key_mgmt())
    return None


def execute(data, report):
    if os.geteuid() != 0 or not Path('/etc/pond-installer-live').is_file():
        raise backend.InstallError('Installation requires the Pond live environment as root')
    plan, profile = decode(data)
    # Reject an outdated confirmation before downloading the payload.
    revalidate(plan.disk)
    warnings = []
    if profile.wifi is None:
        try:
            profile = replace(profile, wifi=connected_wifi())
        except Exception:
            warnings.append('Your Wi-Fi settings could not be copied. Connect again after restarting.')
    with tempfile.TemporaryDirectory(prefix='pond-download-', dir='/var/tmp') as directory:
        report({'type': 'status', 'message': 'Downloading Pond…'})
        archive = backend.fetch_rootfs(Path(directory))
        report({'type': 'status', 'message': 'Installing Pond…'})
        result = backend.install(plan, profile, archive)
    report({'type': 'done', 'warnings': warnings + list(result.warnings)})


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
