"""List models for QML, and Wi-Fi through NetworkManager's nmcli."""

from PySide6.QtCore import Property, QAbstractListModel, QModelIndex, QProcess, QProcessEnvironment, Qt, QTimer, Signal, Slot


class DictModel(QAbstractListModel):
    """Rows are dicts; every key is a QML role. `count` and `get(i)` match the
    ListModel API the screens were written against."""

    countChanged = Signal()

    def __init__(self, keys, parent=None):
        super().__init__(parent)
        self._keys = list(keys)
        self._rows = []

    def rowCount(self, parent=QModelIndex()):
        return len(self._rows)

    def roleNames(self):
        return {Qt.UserRole + i: key.encode() for i, key in enumerate(self._keys)}

    def data(self, index, role=Qt.DisplayRole):
        slot = role - Qt.UserRole
        if index.isValid() and 0 <= index.row() < len(self._rows) and 0 <= slot < len(self._keys):
            return self._rows[index.row()].get(self._keys[slot])
        return None

    @Slot(int, result="QVariantMap")
    def get(self, row):
        return dict(self._rows[row]) if 0 <= row < len(self._rows) else {}

    @Property(int, notify=countChanged)
    def count(self):
        return len(self._rows)

    def rows(self):
        return self._rows

    def reset(self, rows):
        self.beginResetModel()
        self._rows = [dict(row) for row in rows]
        self.endResetModel()
        self.countChanged.emit()


def parse_scan(text):
    best = {}
    for line in text.splitlines():
        values = line.split(':', 3)
        if len(values) != 4 or not values[3] or not values[0].isdigit():
            continue
        strength, security, in_use, ssid = values
        entry = {"ssid": ssid, "strength": int(strength), "secured": security.strip() not in ('', '--'), "active": in_use == "*"}
        prior = best.get(ssid)
        if prior is None or (entry['active'], entry['strength']) > (prior['active'], prior['strength']):
            best[ssid] = entry
    return sorted(best.values(), key=lambda e: (not e["active"], -e["strength"]))


def parse_devices(text):
    devices = [line.split(':') for line in text.splitlines()]
    network_connected = any(len(row) >= 2 and row[0] in ('wifi', 'ethernet') and row[1] == 'connected' for row in devices)
    wifi = any(len(row) >= 2 and row[0] == 'wifi' and row[1] == 'connected' for row in devices)
    available = any(row[0] == 'wifi' for row in devices)
    return network_connected, wifi, available


class WifiModel(DictModel):
    availableChanged = Signal()
    scanningChanged = Signal()
    connectingChanged = Signal()
    connectedChanged = Signal()
    networkConnectedChanged = Signal()
    errorMessageChanged = Signal()
    connectionSucceeded = Signal()
    connectionFailed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(["ssid", "strength", "secured", "active"], parent)
        self._available = False
        self._scanning = False
        self._connecting = False
        self._network_connected = False
        self._active_ssid = ""
        self._error = ""
        self._job = QProcess(self)
        self._job.errorOccurred.connect(self._job_error)
        self._poller = QProcess(self)
        self._poller.finished.connect(self._polled)
        self._poller.errorOccurred.connect(lambda _: self._set("_error", self.errorMessageChanged, "NetworkManager is unavailable."))
        environment = QProcessEnvironment.systemEnvironment()
        environment.insert('LC_ALL', 'C.UTF-8')
        self._job.setProcessEnvironment(environment)
        self._poller.setProcessEnvironment(environment)
        timer = QTimer(self)
        timer.timeout.connect(self.poll)
        timer.start(3000)
        self.poll()

    available = Property(bool, lambda self: self._available, notify=availableChanged)
    scanning = Property(bool, lambda self: self._scanning, notify=scanningChanged)
    connecting = Property(bool, lambda self: self._connecting, notify=connectingChanged)
    networkConnected = Property(bool, lambda self: self._network_connected, notify=networkConnectedChanged)
    activeSsid = Property(str, lambda self: self._active_ssid, notify=connectedChanged)
    errorMessage = Property(str, lambda self: self._error, notify=errorMessageChanged)

    def _set(self, name, signal, value):
        if getattr(self, name) != value:
            setattr(self, name, value)
            signal.emit()

    def poll(self):
        if self._poller.state() == QProcess.NotRunning:
            self._poller.start("nmcli", ["--wait", "10", "-t", "-f", "TYPE,STATE", "device"])

    def _polled(self, code, _status):
        text = bytes(self._poller.readAllStandardOutput()).decode(errors='replace')
        network_connected, wifi, available = parse_devices(text if code == 0 else '')
        self._set("_available", self.availableChanged, available)
        self._set("_network_connected", self.networkConnectedChanged, network_connected)
        if not wifi:
            self._set("_active_ssid", self.connectedChanged, '')
        if self._available and self.count == 0 and not self._scanning:
            self.requestScan()

    @Slot()
    def requestScan(self):
        if not self._available or self._job.state() != QProcess.NotRunning:
            return
        self._set("_scanning", self.scanningChanged, True)
        self._set("_error", self.errorMessageChanged, "")
        self._job.finished.connect(self._scanned)
        self._job.start("nmcli", ["--wait", "15", "-t", "--escape", "no", "-f", "SIGNAL,SECURITY,IN-USE,SSID", "device", "wifi", "list", "--rescan", "yes"])

    def _scanned(self, code, _status):
        self._job.finished.disconnect(self._scanned)
        text = bytes(self._job.readAllStandardOutput()).decode(errors='replace')
        self._set("_scanning", self.scanningChanged, False)
        if code:
            self._set("_error", self.errorMessageChanged, 'Could not scan for Wi-Fi networks.')
            return
        rows = parse_scan(text)
        self.reset(rows)
        self._set("_active_ssid", self.connectedChanged, next((row['ssid'] for row in rows if row['active']), ''))

    @Slot(int, str)
    def connectToNetwork(self, row, password):
        if not 0 <= row < len(self._rows) or self._job.state() != QProcess.NotRunning:
            return
        if any(c in password for c in "\n\r\0"):
            self.connectionFailed.emit("The Wi-Fi password contains an unsupported character.")
            return
        self._ssid = self._rows[row]["ssid"]
        self._set("_connecting", self.connectingChanged, True)
        self._set("_error", self.errorMessageChanged, "")
        self._job.finished.connect(self._joined)
        self._job.start("nmcli", ["--wait", "45", "--ask", "device", "wifi", "connect", self._ssid])
        self._job.write((password + "\n").encode())
        self._job.closeWriteChannel()

    def _joined(self, code, _status):
        self._job.finished.disconnect(self._joined)
        self._set("_connecting", self.connectingChanged, False)
        if code == 0:
            self.reset({**row, 'active': row['ssid'] == self._ssid} for row in self._rows)
            self._set("_active_ssid", self.connectedChanged, self._ssid)
            self._set("_network_connected", self.networkConnectedChanged, True)
            self.connectionSucceeded.emit()
            return
        self._set("_error", self.errorMessageChanged, "Could not join the network.")
        self.connectionFailed.emit(self._error)

    def _job_error(self, error):
        if error == QProcess.FailedToStart:
            if self._scanning:
                self._scanned(1, QProcess.CrashExit)
            elif self._connecting:
                self._joined(1, QProcess.CrashExit)
            self._set("_error", self.errorMessageChanged, "NetworkManager could not be started.")

    def close(self):
        for timer in self.findChildren(QTimer):
            timer.stop()
        for process in (self._job, self._poller):
            if process.state() != QProcess.NotRunning:
                process.kill()
                process.waitForFinished(1000)
