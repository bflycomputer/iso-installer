"""Setup flow and Qt bindings for the Pond installer."""
import json
import os
from pathlib import Path
import subprocess
import threading

from PySide6.QtCore import Property, QObject, QTimeZone, Signal, Slot

import backend
from .job import InstallJob
from .model import MIN_ALLOCATION_GIB, max_allocation_gib
from .settings import confirmation_error, device_name, hostname_error, keyboards, languages, password_error, timezones, username_error
from . import disks
from .wifi import DictModel, WifiModel


class Controller(QObject):
    routeChanged = Signal()
    errorMessageChanged = Signal()
    storageReadyChanged = Signal()
    setupChanged = Signal()
    selectedNetworkChanged = Signal()
    selectedDriveChanged = Signal()
    selectedInstallOptionChanged = Signal()
    installOptionsChanged = Signal()
    allocationChanged = Signal()
    profileChanged = Signal()
    installationChanged = Signal()
    _probed = Signal(object)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._route, self._history, self._error = 'Setup', [], ''
        self._timezone = bytes(QTimeZone.systemTimeZoneId()).decode()
        self._languages, self._keyboards, self._timezones = languages(), keyboards(), timezones(self._timezone)
        self._locale, self._layout, self._variant = 'en_US.UTF-8', 'us', ''
        self._network, self._drive, self._option, self._allocation = -1, 0, 0, MIN_ALLOCATION_GIB
        self._username = self._password = self._confirmation = self._hostname = ''
        self._status, self._failed, self._failure, self._warnings = 'Preparing the installation…', False, '', []
        self._disks, self._storage_ready, self._installer, self._busy = [], False, None, False
        self._drives = DictModel(['name', 'detail', 'capacity', 'used', 'available', 'capacityBytes', 'usedBytes', 'empty'], self)
        self._wifi = WifiModel(self)
        self._wifi.connectionSucceeded.connect(self._connected)
        self._wifi.connectionFailed.connect(self._set_error)
        self._probed.connect(self._set_disks)
        self._probe_thread = None
        self.refreshDisks()

    @Slot()
    def refreshDisks(self):
        if self._busy or (self._probe_thread and self._probe_thread.is_alive()):
            return
        self._storage_ready = False
        self.storageReadyChanged.emit()
        self._probe_thread = threading.Thread(target=self._probe, daemon=True)
        self._probe_thread.start()

    def _probe(self):
        try:
            self._probed.emit(backend.probe())
        except Exception:
            self._probed.emit(None)

    def _set_disks(self, disk_rows):
        self._storage_ready = True
        if disk_rows is None:
            self._set_error('Could not read the storage devices. Try refreshing the list.')
            self._disks = []
        else:
            self._set_error('')
            self._disks = [d for d in disk_rows if not d.busy and not d.read_only and d.identity]
        self._drives.reset(disks.drive_row(d) for d in self._disks)
        self._select_drive(0)
        self.storageReadyChanged.emit()

    def _disk(self):
        return self._disks[self._drive] if 0 <= self._drive < len(self._disks) else None

    def _select_drive(self, index):
        if self._busy:
            return
        self._drive, self._option = index, 0
        disk = self._disk()
        self._allocation = max(MIN_ALLOCATION_GIB, max_allocation_gib(disk)) if disk else MIN_ALLOCATION_GIB
        self.selectedDriveChanged.emit()
        self.selectedInstallOptionChanged.emit()
        self.allocationChanged.emit()
        self.installOptionsChanged.emit()

    def _options(self):
        return disks.options(self._disk(), self._allocation)

    def _option_data(self):
        options = self._options()
        if not 0 <= self._option < len(options):
            raise backend.InstallError('Choose an available installation option.')
        return options[self._option]

    def _profile(self):
        return backend.Profile(self._username.strip(), self._password, self._hostname.strip(),
                               self._timezone, self._locale, self._locale, self._layout, self._variant)

    def _go(self, route):
        self._history.append(self._route)
        self._route = route
        self._set_error('')
        self.routeChanged.emit()

    def _set_error(self, message):
        self._error = message
        self.errorMessageChanged.emit()

    def _connected(self):
        if self._route in ('WifiList', 'WifiPassword'):
            self._go('DriveSelect')

    @Slot()
    def advance(self):
        self._set_error('')
        route = self._route
        if self._busy:
            return
        if route == 'Setup':
            self._wifi.requestScan()
            self._go('WifiList')
        elif route == 'WifiList':
            rows = self._wifi.rows()
            if not 0 <= self._network < len(rows):
                if self._wifi.networkConnected:
                    self._go('DriveSelect')
                else:
                    self._set_error('Select a Wi-Fi network or connect a network cable.')
            elif rows[self._network]['active']:
                self._go('DriveSelect')
            elif rows[self._network]['secured']:
                self._go('WifiPassword')
            else:
                self.connectSelectedNetwork('')
        elif route == 'DriveSelect':
            if not self._storage_ready or not self._options():
                self._set_error('Select a disk with enough usable space for Pond.')
            else:
                self._go('DiskUse' if self._disk().partitions else 'Profile')
        elif route == 'DiskUse':
            try:
                option = self._option_data()
                self._go('DestructiveConfirm' if option['mode'] == backend.Mode.REPLACE.value else 'Allocation')
            except backend.InstallError as error:
                self._set_error(str(error))
        elif route in ('DestructiveConfirm', 'Allocation'):
            self._go('Profile')
        elif route == 'Profile':
            problem = self.usernameError or self.passwordError or self.confirmationError or self.hostnameError
            if problem:
                self._set_error(problem)
            else:
                self._go('Confirm')

    @Slot()
    def back(self):
        if self._history and not self._busy and self._route != 'Finished' and not self._wifi.connecting:
            self._route = self._history.pop()
            self._set_error('')
            self.routeChanged.emit()

    @Slot(str)
    def connectSelectedNetwork(self, password):
        if self._route not in ('WifiList', 'WifiPassword'):
            return
        self._wifi.connectToNetwork(self._network, password)

    @Slot()
    def continueConnected(self):
        if self._route == 'WifiList' and self._wifi.networkConnected and not self._wifi.connecting:
            self._go('DriveSelect')

    @Slot()
    def beginInstallation(self):
        if self._route != 'Confirm' or self._installer is not None:
            return
        try:
            profile = self._profile()
            profile.validate()
            if self.confirmationError:
                raise backend.InstallError(self.confirmationError)
            plan = self._option_data()['plan']
        except backend.InstallError as error:
            self._set_error(str(error))
            return
        self._installer = InstallJob(self)
        self._installer.statusChanged.connect(self._status_changed)
        self._installer.completed.connect(self._done)
        self._busy = True
        self.installationChanged.emit()
        self._go('Installing')
        self._installer.start(plan, profile)

    def _status_changed(self, status):
        self._status = status
        self.installationChanged.emit()

    def _done(self, ok, message, warnings):
        self._busy, self._failed, self._failure, self._warnings = False, not ok, message, warnings
        self._password = self._confirmation = ''
        self.profileChanged.emit()
        self.installationChanged.emit()
        self._go('Finished')

    @Slot()
    def cancelInstallation(self):
        if self._busy and self._installer:
            self._status_changed('Cancelling and cleaning up…')
            self._installer.cancel()

    def _power(self, action):
        if self._busy:
            return
        if os.geteuid() != 0 or not Path('/etc/pond-installer-live').is_file():
            self._set_error('Power controls are available only in the Pond live environment.')
            return
        try:
            subprocess.Popen(['systemctl', action])
        except OSError:
            self._set_error('The power command could not be started.')

    @Slot()
    def restartComputer(self):
        self._power('reboot')

    @Slot()
    def powerOffComputer(self):
        self._power('poweroff')

    def close(self):
        if self._busy:
            self._installer.cancel()
            self._installer.wait()
        self._wifi.close()
        if self._probe_thread:
            self._probe_thread.join()

    def _choices(self, row):
        return (self._languages, self._keyboards, self._timezones)[row]

    @Slot(int, result=int)
    def setupChoiceIndex(self, row):
        if not 0 <= row <= 2:
            return 0
        for index, item in enumerate(self._choices(row)):
            if (row == 0 and item['value'] == self._locale) or (row == 2 and item['value'] == self._timezone) \
                    or (row == 1 and item['value'] == self._layout and item['variant'] == self._variant):
                return index
        return 0

    @Slot(int, int)
    def selectSetupChoice(self, row, index):
        if self._busy or not 0 <= row <= 2 or not 0 <= index < len(self._choices(row)):
            return
        item = self._choices(row)[index]
        if row == 0:
            self._locale = item['value']
        elif row == 1:
            self._layout, self._variant = item['value'], item['variant']
        else:
            self._timezone = item['value']
        self.setupChanged.emit()

    def _label(self, row):
        return self._choices(row)[self.setupChoiceIndex(row)]['label']

    def _setter(name, signal):
        def set_value(self, value):
            if not self._busy and getattr(self, name) != value:
                setattr(self, name, value)
                getattr(self, signal).emit()
        return set_value

    def _set_allocation(self, value):
        disk = self._disk()
        if disk and not self._busy and MIN_ALLOCATION_GIB <= value <= max_allocation_gib(disk):
            self._allocation = value
            self.allocationChanged.emit()
            self.installOptionsChanged.emit()

    route = Property(str, lambda self: self._route, notify=routeChanged)
    routeTrail = Property('QVariantList', lambda self: self._history + [self._route], notify=routeChanged)
    errorMessage = Property(str, lambda self: self._error, notify=errorMessageChanged)
    storageReady = Property(bool, lambda self: self._storage_ready, notify=storageReadyChanged)
    drives = Property(QObject, lambda self: self._drives, constant=True)
    wifi = Property(QObject, lambda self: self._wifi, constant=True)
    deviceName = Property(str, lambda self: device_name(), constant=True)
    languageChoices = Property(str, lambda self: json.dumps(self._languages), constant=True)
    keyboardChoices = Property(str, lambda self: json.dumps(self._keyboards), constant=True)
    timezoneChoices = Property(str, lambda self: json.dumps(self._timezones), constant=True)
    localeName = Property(str, lambda self: self._locale, notify=setupChanged)
    languageLabel = Property(str, lambda self: self._label(0), notify=setupChanged)
    keyboardLayout = Property(str, lambda self: self._layout, notify=setupChanged)
    keyboardLabel = Property(str, lambda self: self._label(1), notify=setupChanged)
    timezoneLabel = Property(str, lambda self: self._label(2), notify=setupChanged)
    selectedNetwork = Property(int, lambda self: self._network, _setter('_network', 'selectedNetworkChanged'), notify=selectedNetworkChanged)
    selectedSsid = Property(str, lambda self: self._wifi.get(self._network).get('ssid', ''), notify=selectedNetworkChanged)
    selectedNetworkStrength = Property(int, lambda self: int(self._wifi.get(self._network).get('strength', 0)), notify=selectedNetworkChanged)
    selectedDrive = Property(int, lambda self: self._drive, _select_drive, notify=selectedDriveChanged)
    selectedDriveData = Property('QVariantMap', lambda self: self._drives.get(self._drive), notify=selectedDriveChanged)
    installOptions = Property('QVariantList', lambda self: [{k: v for k, v in row.items() if k != 'plan'} for row in self._options()], notify=installOptionsChanged)
    selectedInstallOption = Property(int, lambda self: self._option, _setter('_option', 'selectedInstallOptionChanged'), notify=selectedInstallOptionChanged)
    allocationGiB = Property(int, lambda self: self._allocation, _set_allocation, notify=allocationChanged)
    minimumAllocationGiB = Property(int, lambda self: MIN_ALLOCATION_GIB, constant=True)
    maximumAllocationGiB = Property(int, lambda self: max(MIN_ALLOCATION_GIB, max_allocation_gib(self._disk())) if self._disk() else MIN_ALLOCATION_GIB, notify=selectedDriveChanged)
    username = Property(str, lambda self: self._username, _setter('_username', 'profileChanged'), notify=profileChanged)
    password = Property(str, lambda self: self._password, _setter('_password', 'profileChanged'), notify=profileChanged)
    passwordConfirmation = Property(str, lambda self: self._confirmation, _setter('_confirmation', 'profileChanged'), notify=profileChanged)
    hostname = Property(str, lambda self: self._hostname, _setter('_hostname', 'profileChanged'), notify=profileChanged)
    usernameError = Property(str, lambda self: username_error(self._username), notify=profileChanged)
    passwordError = Property(str, lambda self: password_error(self._password), notify=profileChanged)
    confirmationError = Property(str, lambda self: confirmation_error(self._password, self._confirmation), notify=profileChanged)
    hostnameError = Property(str, lambda self: hostname_error(self._hostname), notify=profileChanged)
    busy = Property(bool, lambda self: self._busy, notify=installationChanged)
    status = Property(str, lambda self: self._status, notify=installationChanged)
    failed = Property(bool, lambda self: self._failed, notify=installationChanged)
    failureMessage = Property(str, lambda self: self._failure, notify=installationChanged)
    warnings = Property(str, lambda self: '\n'.join(self._warnings), notify=installationChanged)
