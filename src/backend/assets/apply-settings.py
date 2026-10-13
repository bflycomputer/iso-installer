"""Configure the installed system's locale and keyboard."""

import json
from pathlib import Path
import subprocess
import sys


def log(message):
    print(f"[settings] {message}", file=sys.stderr)


def configure_locale(locale):
    supported = {line.split()[0] for line in Path("/usr/share/i18n/SUPPORTED").read_text().splitlines()
                 if line.endswith(" UTF-8")}
    if locale not in supported:
        raise ValueError("Unsupported locale")
    Path("/etc/locale.gen").write_text(f"{locale} UTF-8\n")
    subprocess.run(["locale-gen"], check=True, stdout=subprocess.DEVNULL)
    Path("/etc/locale.conf").write_text(f"LANG={locale}\nLC_MESSAGES={locale}\n")
    log(f"Locale: {locale}")


def configure_keyboard(layout):
    directory = Path("/etc/X11/xorg.conf.d")
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "00-keyboard.conf").write_text(
        'Section "InputClass"\n    Identifier "system-keyboard"\n    MatchIsKeyboard "on"\n'
        f'    Option "XkbLayout" "{layout}"\n    Option "XkbVariant" ""\nEndSection\n'
    )
    # systemd-localed reads 00-keyboard.conf; niri and the login screen use it.
    for line in Path("/usr/share/systemd/kbd-model-map").read_text().splitlines():
        fields = line.split()
        if len(fields) >= 4 and fields[1] == layout and fields[3] == "-":
            Path("/etc/vconsole.conf").write_text(f"KEYMAP={fields[0]}\n")
            break
    else:
        log(f"No console keymap for {layout}; desktop layout was applied")
    log(f"Keyboard: {layout}")


if __name__ == "__main__":
    settings = json.load(sys.stdin)
    configure_locale(settings["locale"])
    configure_keyboard(settings["layout"])
