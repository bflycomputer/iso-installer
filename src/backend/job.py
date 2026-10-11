"""Run the installation without forking the Qt application or blocking its event loop."""
import json
import os
import re
import signal
import sys

from PySide6.QtCore import QObject, QProcess, Signal

from .worker import request


class InstallJob(QObject):
    progressChanged = Signal(float)
    completed = Signal(bool, str, list)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.process = QProcess(self)
        self.process.readyReadStandardOutput.connect(self._read)
        self.process.readyReadStandardError.connect(self._download_progress)
        self.process.errorOccurred.connect(self._error)
        self.process.finished.connect(self._finished)
        self.process.started.connect(self._started)
        self._result = None
        self._cancelled = False
        self._download = ''

    def start(self, plan, profile):
        self._result = None
        self._cancelled = False
        self.process.start(sys.executable, ['-m', 'backend.worker'])
        self.process.write(json.dumps(request(plan, profile)).encode())
        self.process.closeWriteChannel()

    def _read(self):
        while self.process.canReadLine():
            try:
                event = json.loads(bytes(self.process.readLine()))
                if event['type'] == 'progress' and not self._cancelled:
                    self.progressChanged.emit(float(event['value']))
                elif event['type'] == 'done':
                    self._result = (True, '', event.get('warnings', []))
                elif event['type'] == 'error':
                    self._result = (False, event['message'], [])
            except (ValueError, KeyError, TypeError):
                self._result = (False, 'The installation process returned an invalid response.', [])

    def _download_progress(self):
        self._download += bytes(self.process.readAllStandardError()).decode(errors='replace')
        lines = self._download.replace('\r', '\n').split('\n')
        self._download = lines.pop()[-256:]
        for line in lines:
            match = re.search(r'(\d+(?:\.\d+)?)%\s*$', line)
            if match and not self._cancelled:
                self.progressChanged.emit(0.04 + 0.56 * float(match[1]) / 100)

    def _error(self, error):
        if error == QProcess.FailedToStart:
            self.completed.emit(False, 'The installation process could not be started.', [])

    def _finished(self, code, status):
        self._read()
        if self._result is None or (self._result[0] and (code != 0 or status != QProcess.NormalExit)):
            self._result = (False, 'The installation process stopped unexpectedly. Check the target before trying again.', [])
        self.completed.emit(*self._result)

    def cancel(self):
        if self._cancelled:
            return
        self._cancelled = True
        self._started()

    def _started(self):
        pid = self.process.processId()
        if pid and self._cancelled:
            try:
                os.kill(pid, signal.SIGINT)
            except ProcessLookupError:
                pass

    def wait(self):
        self.process.waitForFinished(-1)
