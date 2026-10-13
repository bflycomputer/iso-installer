"""Run installer commands."""

from contextlib import suppress
import os
import signal
import subprocess

from .model import InstallError


def run(argv, *, input=None, check=True, stderr=subprocess.PIPE):
    # Firmware labels need not be UTF-8. Only display text may be replaced;
    # persistent identifiers are checked separately before they are used.
    with subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          stderr=stderr, text=True, errors="replace",
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
        detail = f": {result.stderr.strip()}" if result.stderr else ""
        if len(detail) > 1000:
            detail = f"{detail[:480]}\n... [stderr truncated] ...\n{detail[-480:]}"
        raise InstallError(f"{argv[0]} failed (exit {result.returncode}){detail}")
    return result
