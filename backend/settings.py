"""Live-system setup choices and profile field validation."""
import re
from pathlib import Path
from PySide6.QtCore import QDateTime, QLocale, QTimeZone

from .model import HOSTNAME, MAX_PASSWORD_LENGTH, USERNAME

LANGUAGE_PRIORITY = ["en_US.UTF-8", "en_GB.UTF-8", "fr_FR.UTF-8", "de_DE.UTF-8", "es_ES.UTF-8", "ar_SA.UTF-8",
                     "bn_BD.UTF-8"]


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
        return "Use up to 63 letters, numbers, underscores, or dashes; do not start or end with a dash."
    return ""


def languages(path="/usr/share/i18n/SUPPORTED"):
    items = []
    for line in Path(path).read_text().splitlines():
        columns = line.split()
        if len(columns) == 2 and columns[1] == "UTF-8":
            locale = QLocale(columns[0].split(".")[0].split("@")[0])
            if locale.name() != "C":
                items.append({"label": "{} ({})".format(QLocale.languageToString(locale.language()),
                                                        QLocale.territoryToString(locale.territory())),
                              "value": columns[0]})
    items.sort(key=lambda i: (LANGUAGE_PRIORITY.index(i["value"]) if i["value"] in LANGUAGE_PRIORITY
                              else len(LANGUAGE_PRIORITY), i["label"]))
    return items


def keyboards(path="/usr/share/X11/xkb/rules/base.lst"):
    items, section = [], ""
    for line in Path(path).read_text().splitlines():
        if line.startswith("!"):
            section = line.split()[1]
            continue
        match = re.match(r"\s+(\S+)\s+(.+?)\s*$", line)
        if not match:
            continue
        if section == "layout":
            items.append({"label": match[2], "value": match[1], "variant": "", "detail": ""})
        elif section == "variant":
            layout, _, label = match[2].partition(": ")
            items.append({"label": label, "value": layout, "variant": match[1], "detail": ""})
    items.sort(key=lambda i: (i["value"] != "us" or i["variant"] != "", i["label"]))
    return items


def timezones(current, path="/usr/share/zoneinfo/zone.tab"):
    identifiers = sorted(line.split("\t")[2].strip() for line in Path(path).read_text().splitlines()
                         if line and not line.startswith("#"))
    now, english, groups = QDateTime.currentDateTimeUtc(), QLocale("en_US"), {}
    for identifier in [current, "UTC", *identifiers]:
        zone = QTimeZone(identifier.encode())
        offset = zone.offsetFromUtc(now)
        label = zone.displayName(now, QTimeZone.NameType.LongName, english)
        transitions = tuple((change.atUtc.toSecsSinceEpoch(), change.offsetFromUtc)
                            for change in zone.transitions(now, now.addYears(1)))
        groups.setdefault((label, offset, transitions), {
            "value": identifier, "label": label,
            "detail": f'GMT{"-" if offset < 0 else "+"}{abs(offset) // 3600:02}:{abs(offset) // 60 % 60:02}',
            "search": zone.abbreviation(now),
        })
    labels = [item["label"] for item in groups.values()]
    for item in groups.values():
        if labels.count(item["label"]) > 1:
            item["label"] = item["value"].rpartition("/")[2].replace("_", " ") + " – " + item["label"]
    return [item for key, item in sorted(groups.items(), key=lambda entry: (entry[0][1], entry[1]["label"]))]


def device_name():
    try:
        return Path("/sys/class/dmi/id/product_name").read_text().strip() or "Pond"
    except OSError:
        return "Pond"

