"""Live-system setup choices and profile field validation."""
from collections import Counter
import xml.etree.ElementTree as ET
from pathlib import Path
from PySide6.QtCore import QDateTime, QLocale, QTimeZone

from .model import HOSTNAME, MAX_PASSWORD_LENGTH, USERNAME

LANGUAGE_PRIORITY = ["en", "fr", "de", "es", "ar", "bn"]
SCRIPT_MODIFIERS = {"latin": "Latn", "cyrillic": "Cyrl", "devanagari": "Deva"}


# Trim account names, but preserve passwords exactly as entered.
def username_error(value):
    value = value.strip()
    if not value:
        return "Enter a username."
    if len(value) > 32:
        return "Username must be 32 characters or fewer."
    if value[0] != "_" and not "a" <= value[0] <= "z":
        return "Username must start with a lowercase letter or underscore."
    if not USERNAME.fullmatch(value):
        return "Only lowercase letters, numbers, underscore and hyphen are allowed."
    return ""


def password_error(value):
    if not value:
        return "Enter a password."
    if len(value) > MAX_PASSWORD_LENGTH:
        return f"Use at most {MAX_PASSWORD_LENGTH} characters."
    if any(character in value for character in "\n\r\0"):
        return "Passwords cannot contain newlines, carriage returns, or NUL characters."
    return ""


def confirmation_error(value, confirmation):
    return "" if value == confirmation else "The passwords do not match."


def hostname_error(value):
    value = value.strip()
    if not value:
        return "Enter a computer name."
    if not HOSTNAME.fullmatch(value):
        return "Use up to 63 letters, numbers, or dashes; do not start or end with a dash."
    return ""


def languages(path="/usr/share/i18n/SUPPORTED"):
    groups = {}
    for line in Path(path).read_text().splitlines():
        columns = line.split()
        if len(columns) == 2 and columns[1] == "UTF-8":
            base, _, modifier = columns[0].split(".")[0].partition("@")
            locale = QLocale(base)
            if locale.name() != "C":
                script = QLocale.codeToScript(SCRIPT_MODIFIERS[modifier]) if modifier in SCRIPT_MODIFIERS else locale.script()
                variant = "" if modifier in SCRIPT_MODIFIERS else modifier
                groups.setdefault((locale.language(), script, variant), {}).setdefault(base.partition("_")[2], columns[0])
    scripts = Counter(language for language, _, variant in groups if not variant)
    items = []
    for (language, script, variant), locales in groups.items():
        detail = variant.title() or (QLocale.scriptToString(script) if scripts[language] > 1 else "")
        default = QLocale.territoryToCode(QLocale(language, script, QLocale.AnyTerritory).territory())
        items.append({"label": QLocale.languageToString(language) + (f" ({detail})" if detail else ""),
                      "value": locales.get(default, next(iter(locales.values())))})
    rank = lambda item: item["value"].split("_")[0]
    return sorted(items, key=lambda item: (LANGUAGE_PRIORITY.index(rank(item)) if rank(item) in LANGUAGE_PRIORITY
                                           else len(LANGUAGE_PRIORITY), item["label"]))


def keyboards(path="/usr/share/X11/xkb/rules/evdev.xml"):
    items = []
    for layout in ET.parse(path).iterfind("layoutList/layout"):
        name = layout.findtext("configItem/name")
        if name != "custom":
            items.append({"label": layout.findtext("configItem/description"), "value": name})
    return sorted(items, key=lambda item: item["label"].casefold())


def timezones(directory=Path("/usr/share/zoneinfo")):
    now, english, representatives, entries = QDateTime.currentDateTimeUtc(), QLocale("en_US"), {}, {}
    for identifier in ["UTC", *(line.split("\t")[2].strip() for table in ("zonenow.tab", "zone.tab")
                                for line in (directory / table).read_text().splitlines()
                                if line and not line.startswith("#"))]:
        zone = QTimeZone(identifier.encode())
        changes = zone.transitions(now, now.addYears(20))
        representative = representatives.setdefault((zone.offsetFromUtc(now), zone.abbreviation(now), *(
            (change.atUtc.toSecsSinceEpoch(), change.offsetFromUtc, change.abbreviation) for change in changes)), identifier)
        for date in [now, *(change.atUtc for change in changes)]:
            name, offset = zone.displayName(date, QTimeZone.NameType.LongName, english), zone.offsetFromUtc(date)
            entry = entries.setdefault(name, {}).setdefault(representative, {"zone": identifier, "offset": offset, "aliases": {name}})
            entry["aliases"].update({zone.abbreviation(date),
                                     f'GMT{"-" if offset < 0 else "+"}{abs(offset) // 3600:02}:{abs(offset) // 60 % 60:02}'})
    items = {}
    for name, zones in entries.items():
        for entry in zones.values():
            label = name if len(zones) == 1 else f'{name} – {entry["zone"].rpartition("/")[2].replace("_", " ")}'
            items[label] = {"value": label, "label": label, "zone": entry["zone"], "offset": entry["offset"],
                            "aliases": sorted(entry["aliases"] | {label})}
    return sorted(items.values(), key=lambda item: (item["offset"], item["label"]))


def device_name():
    try:
        return Path("/sys/class/dmi/id/product_name").read_text().strip() or "Pond"
    except OSError:
        return "Pond"

