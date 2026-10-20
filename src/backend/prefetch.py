"""Prefetch rootfs download into live storage when free space allows."""

from contextlib import suppress
import logging
import os
from pathlib import Path
import re
import signal

from PySide6.QtCore import QObject, QProcess, Signal

from .model import ROOTFS_STAGING_RESERVE, ROOTFS_URL
from .system import verify_rootfs

CACHE_DIR = Path("/var/tmp/pond-rootfs-cache")
ARCHIVE_NAME = "pond-rootfs.tar.zst"
READY_MARKER = ARCHIVE_NAME + ".ready"


def staging_dir() -> Path:
    return CACHE_DIR


def archive_path() -> Path:
    return CACHE_DIR / ARCHIVE_NAME


def _ready_marker() -> Path:
    return CACHE_DIR / READY_MARKER


def parse_content_length(headers: str) -> int | None:
    length = None
    for line in headers.splitlines():
        if line.lower().startswith("content-length:"):
            with suppress(ValueError):
                length = int(line.split(":", 1)[1].strip())
    return length if length and length > 0 else None


def can_stage(size: int, directory: Path | None = None) -> bool:
    """True when directory's filesystem can hold size bytes plus a live reserve."""
    if size <= 0:
        return False
    path = Path(directory or CACHE_DIR)
    try:
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        space = os.statvfs(path)
    except OSError:
        return False
    free = space.f_bavail * space.f_frsize
    existing = 0
    with suppress(OSError):
        existing = (path / ARCHIVE_NAME).stat().st_size
    return free + existing >= size + ROOTFS_STAGING_RESERVE


def discard_incomplete():
    with suppress(OSError):
        _ready_marker().unlink()
    with suppress(OSError):
        archive_path().unlink()


def ready_archive() -> Path | None:
    """Return a cache path marked verified; install re-verifies the checksum."""
    path = archive_path()
    if not path.is_file() or not _ready_marker().is_file():
        return None
    try:
        if path.stat().st_size <= 0:
            discard_incomplete()
            return None
    except OSError:
        discard_incomplete()
        return None
    return path


class PrefetchJob(QObject):
    """Download and verify the rootfs in the background when staging space exists."""

    readyChanged = Signal()
    progressChanged = Signal(float)
    finished = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._probe = QProcess(self)
        self._probe.finished.connect(self._probed)
        self._probe.errorOccurred.connect(self._probe_error)
        self._process = QProcess(self)
        self._process.readyReadStandardError.connect(self._progress)
        self._process.finished.connect(self._finished)
        self._process.errorOccurred.connect(self._error)
        self._download = ""
        self._ready = False
        self._cancelled = False
        self._active = False

    @property
    def ready(self):
        return self._ready

    @property
    def active(self):
        return self._active

    def archive(self) -> Path | None:
        path = ready_archive()
        self._ready = path is not None
        return path

    def start(self):
        if self._active or self._process.state() != QProcess.NotRunning or self._probe.state() != QProcess.NotRunning:
            return
        if ready_archive() is not None:
            self._ready = True
            self.readyChanged.emit()
            self.finished.emit(True)
            return
        self._ready = False
        self._cancelled = False
        self._active = True
        self._probe.start("curl", [
            "--fail", "--silent", "--show-error", "--location",
            "--proto", "=https", "--head", "--max-time", "15", ROOTFS_URL,
        ])

    def cancel(self):
        if not self._active and self._process.state() == QProcess.NotRunning and self._probe.state() == QProcess.NotRunning:
            return
        self._cancelled = True
        for process in (self._probe, self._process):
            pid = process.processId()
            if not pid:
                continue
            with suppress(ProcessLookupError):
                os.kill(pid, signal.SIGTERM)
            process.waitForFinished(5000)
            if process.state() != QProcess.NotRunning:
                with suppress(ProcessLookupError):
                    os.kill(pid, signal.SIGKILL)
                process.waitForFinished(1000)
        self._active = False
        if not self._ready:
            discard_incomplete()

    def wait(self, timeout_ms=-1):
        if self._probe.state() != QProcess.NotRunning:
            self._probe.waitForFinished(timeout_ms)
        if self._process.state() != QProcess.NotRunning:
            self._process.waitForFinished(timeout_ms)

    def close(self):
        self.cancel()
        self._ready = False
        discard_incomplete()

    def _probe_error(self, error):
        if error == QProcess.FailedToStart:
            logging.warning("Rootfs size probe could not start curl")

    def _probed(self, code, status):
        if self._cancelled:
            self._active = False
            self.finished.emit(False)
            return
        headers = bytes(self._probe.readAllStandardOutput()).decode(errors="replace")
        size = parse_content_length(headers) if code == 0 and status == QProcess.NormalExit else None
        if size is None or not can_stage(size):
            self._active = False
            if size is None:
                logging.warning("Rootfs size probe failed (exit %s)", code)
            self.finished.emit(False)
            return
        discard_incomplete()
        CACHE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
        self._download = ""
        path = archive_path()
        self._process.start("curl", [
            "--fail", "--location", "--proto", "=https", "--retry", "3",
            "--retry-all-errors", "--progress-bar", "--output", str(path), ROOTFS_URL,
        ])

    def _progress(self):
        self._download += bytes(self._process.readAllStandardError()).decode(errors="replace")
        lines = self._download.replace("\r", "\n").split("\n")
        self._download = lines.pop()[-256:]
        for line in lines:
            match = re.search(r"(\d+(?:\.\d+)?)%\s*$", line)
            if match and not self._cancelled:
                self.progressChanged.emit(float(match[1]) / 100)

    def _error(self, error):
        if error == QProcess.FailedToStart:
            logging.warning("Prefetch could not start curl")

    def _finished(self, code, status):
        self._active = False
        if self._cancelled:
            discard_incomplete()
            self.finished.emit(False)
            return
        path = archive_path()
        if code != 0 or status != QProcess.NormalExit or not path.is_file():
            discard_incomplete()
            logging.warning("Prefetch failed (exit %s)", code)
            self.finished.emit(False)
            return
        try:
            verify_rootfs(path)
            _ready_marker().write_text(ROOTFS_URL + "\n")
        except Exception:
            discard_incomplete()
            logging.exception("Prefetch checksum failed")
            self.finished.emit(False)
            return
        self._ready = True
        self.readyChanged.emit()
        self.finished.emit(True)
