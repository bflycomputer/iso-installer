"""Configure the installed system's locale, keyboard, and Wi-Fi connection."""

import json
from pathlib import Path
import subprocess
import sys
import uuid


def log(message):
    print(f"[settings] {message}", file=sys.stderr)


def configure_locale(locale, language):
    supported = {line.split()[0] for line in Path("/usr/share/i18n/SUPPORTED").read_text().splitlines()
                 if line.endswith(" UTF-8")}
    if locale not in supported or language not in supported:
        raise ValueError("Unsupported locale")
    Path("/etc/locale.gen").write_text("".join(f"{name} UTF-8\n" for name in sorted({locale, language})))
    subprocess.run(["locale-gen"], check=True, stdout=subprocess.DEVNULL)
    Path("/etc/locale.conf").write_text(f"LANG={locale}\nLC_MESSAGES={language}\n")
    log(f"Regional format: {locale}; display language: {language}")


def configure_keyboard(layout, variant):
    directory = Path("/etc/X11/xorg.conf.d")
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "00-keyboard.conf").write_text(
        'Section "InputClass"\n    Identifier "system-keyboard"\n    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{layout}"\n    Option "XkbVariant" "{variant}"\nEndSection\n'
    )
    # systemd-localed reads 00-keyboard.conf; niri and the login screen use it.
    for line in Path("/usr/share/systemd/kbd-model-map").read_text().splitlines():
        fields = line.split()
        if len(fields) >= 4 and fields[1] == layout and ("" if fields[3] == "-" else fields[3]) == variant:
            Path("/etc/vconsole.conf").write_text(f"KEYMAP={fields[0]}\n")
            break
    else:
        log(f"No console keymap for {layout}/{variant}; desktop layout was applied")
    log(f"Keyboard: {layout}/{variant}")


def wifi_connection(profile):
    import gi
    gi.require_version("NM", "1.0")
    from gi.repository import GLib, NM

    ssid = bytes.fromhex(profile["ssid_hex"])
    connection = NM.SimpleConnection.new()
    identity = NM.SettingConnection.new()
    identity.props.id = ssid.decode("utf-8", errors="replace")
    identity.props.uuid = str(uuid.uuid4())
    identity.props.type = "802-11-wireless"
    connection.add_setting(identity)
    wifi = NM.SettingWireless.new()
    wifi.props.ssid = GLib.Bytes.new(ssid)
    wifi.props.mode = "infrastructure"
    connection.add_setting(wifi)
    wireless_security = NM.SettingWirelessSecurity.new()
    wireless_security.props.key_mgmt = profile["key_management"]
    wireless_security.props.psk = profile["psk"]
    connection.add_setting(wireless_security)
    connection.verify()
    return NM.keyfile_write(connection, NM.KeyfileHandlerFlags.NONE).to_data()[0]


def configure_wifi(profile):
    if profile is None:
        return
    try:
        data = wifi_connection(profile)
    except Exception as error:
        # Parser/library errors can contain SSIDs or keys; log only their type.
        log(f"Wi-Fi profile skipped ({type(error).__name__}); it can be configured in Pond")
        return
    path = Path("/etc/NetworkManager/system-connections/pond-wifi.nmconnection")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data)
    path.chmod(0o600)
    log("Imported connected Wi-Fi")


if __name__ == "__main__":
    settings = json.load(sys.stdin)
    configure_locale(settings["locale"], settings["language"])
    configure_keyboard(settings["layout"], settings["variant"])
    configure_wifi(settings["wifi"])
