"""Run installer commands and validate device identifiers."""

from contextlib import suppress
import os
import signal
import subprocess

from .model import InstallError


def run(argv, *, input=None, check=True):
    # Firmware labels need not be UTF-8. Only display text may be replaced;
    # persistent identifiers are checked separately before they are used.
    with subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, errors="replace",
                          start_new_session=True) as process:
        try:
            stdout, stderr = process.communicate(input)
        except BaseException:
            # Stop descendants before cleanup can unmount their target filesystems.
            with suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGTERM)
            with suppress(subprocess.TimeoutExpired):
                process.wait(timeout=5)
            with suppress(ProcessLookupError):
                os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
    result = subprocess.CompletedProcess(argv, process.returncode, stdout, stderr)
    if check and result.returncode:
        # Command arguments/input/output can carry account or network secrets.
        raise InstallError(f"{argv[0]} failed (exit {result.returncode})")
    return result


def identifier(argv):
    value = run(argv).stdout.strip()
    if not value or "\ufffd" in value or "\n" in value:
        raise InstallError("A device identifier is missing or invalid")
    return value
