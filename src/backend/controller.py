"""Setup flow and Qt bindings"""
from contextlib import suppress
import json
import logging
import os
from pathlib import Path
import subprocess
import threading

from PySide6.QtCore import Property, QObject, Signal, Slot

import backend
from .job import InstallJob
from .prefetch import PrefetchJob
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
    profileChanged = Signal()
    installationChanged = Signal()
    restartRequested = Signal(str)
    _probed = Signal(object)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._route, self._history, self._error = 'Setup', [], ''
        self._languages, self._keyboards, self._timezones = languages(), keyboards(), timezones()
        self._timezone = next(item['value'] for item in self._timezones if item['zone'] == 'UTC')
        self._locale, self._layout = 'en_US.UTF-8', os.environ.get('XKB_DEFAULT_LAYOUT', 'us')
        self._selected_ssid, self._drive, self._option = '', 0, 0
        self._username = self._password = self._confirmation = self._hostname = ''
        self._progress, self._failed, self._failure, self._warnings = 0.0, False, '', []
        self._disks, self._storage_ready, self._installer, self._busy = [], False, None, False
        self._pending_plan = self._pending_profile = None
        self._drives = DictModel(['name', 'detail', 'capacity', 'used', 'available', 'capacityBytes', 'usedBytes', 'empty'], self)
        self._wifi = WifiModel(self)
        self._wifi.connectionFailed.connect(self._connection_failed)
        self._wifi.ethernetConnectedChanged.connect(self._ethernet_changed)
        self._wifi.networkConnectedChanged.connect(self._network_changed)
        self._wifi.countChanged.connect(self.selectedNetworkChanged.emit)
        self.routeChanged.connect(lambda: self._wifi.setScanEnabled(self._route == 'WifiList'))
        self._prefetch = PrefetchJob(self)
        self._prefetch.progressChanged.connect(self._prefetch_progress)
        self._probed.connect(self._set_disks)
        self.profileChanged.connect(lambda: self._set_error(''))
        self._probe_thread = threading.Thread(target=self._probe, daemon=True)
        self._probe_thread.start()
        self._network_changed()

    def _probe(self):
        try:
            self._probed.emit(backend.probe())
        except Exception:
            logging.exception('Drive probe failed')
            self._probed.emit(None)

    def _set_disks(self, disk_rows):
        self._storage_ready = True
        if disk_rows is None:
            self._set_error('Could not read the storage devices.')
            self._disks = []
        else:
            self._set_error('')
            self._disks = [d for d in disk_rows if not d.busy and not d.read_only]
        self._drives.reset(disks.drive_row(d) for d in self._disks)
        self._select_drive(0)
        self.storageReadyChanged.emit()

    def _disk(self):
        return self._disks[self._drive] if 0 <= self._drive < len(self._disks) else None

    def _select_drive(self, index):
        if self._busy:
            return
        self._drive, self._option = index, 0
        self.selectedDriveChanged.emit()
        self.selectedInstallOptionChanged.emit()

    def _options(self):
        return disks.options(self._disk())

    def _network_index(self):
        return next((i for i, row in enumerate(self._wifi.rows()) if row['ssid'] == self._selected_ssid), -1)

    def _select_network(self, index):
        if not self._busy:
            self._selected_ssid = self._wifi.get(index).get('ssid', '')
            self.selectedNetworkChanged.emit()

    def _option_data(self):
        options = self._options()
        if not 0 <= self._option < len(options):
            raise backend.InstallError('Choose an available installation option.')
        return options[self._option]

    def _profile(self):
        zone = next(item['zone'] for item in self._timezones if item['value'] == self._timezone)
        return backend.Profile(self._username.strip(), self._password, self._hostname.strip(),
                               zone, self._locale, self._layout)

    def _go(self, route):
        self._history.append(self._route)
        self._route = route
        self._set_error('')
        self.routeChanged.emit()

    def _set_error(self, message):
        self._error = message
        self.errorMessageChanged.emit()

    def _ethernet_changed(self):
        if self._wifi.ethernetConnected and self._route in ('WifiList', 'WifiPassword'):
            self._go('DriveSelect')

    def _network_changed(self):
        if self._wifi.networkConnected:
            self._prefetch.start()
        elif self._prefetch.active:
            self._prefetch.cancel()

    def _prefetch_progress(self, fraction):
        if self._route == 'Installing' and self._installer is not None:
            self._progressed(0.04 + 0.56 * fraction)

    def _connection_failed(self, message):
        if self._route in ('WifiList', 'WifiPassword'):
            self._set_error(message)

    @Slot()
    def advance(self):
        self._set_error('')
        route = self._route
        if self._busy:
            return
        if route == 'Setup':
            if self._wifi.networkConnected:
                self._go('DriveSelect')
            else:
                self._go('WifiList')
        elif route == 'WifiList':
            network = self._wifi.get(self.selectedNetwork)
            if not network:
                if self._wifi.networkConnected:
                    self._go('DriveSelect')
                else:
                    self._set_error('Select a Wi-Fi network or connect a network cable.')
            elif network['active']:
                self._go('DriveSelect')
            else:
                self._go('WifiPassword')
                if not network['secured']:
                    self.connectSelectedNetwork('')
        elif route == 'WifiPassword' and self._wifi.networkConnected:
            self._go('DriveSelect')
        elif route == 'DriveSelect' and self._disk():
            try:
                backend.plan_install(self._disk(), backend.Mode.REPLACE, boot_mode=backend.current_boot_mode())
                self._go('DiskUse')
            except backend.InstallError as error:
                self._set_error(str(error))
        elif route == 'DiskUse':
            try:
                option = self._option_data()
                self._go('DestructiveConfirm' if option['mode'] == backend.Mode.REPLACE.value else 'Profile')
            except backend.InstallError as error:
                self._set_error(str(error))
        elif route == 'DestructiveConfirm':
            self._go('Profile')
        elif route == 'Profile':
            self.beginInstallation()

    @Slot()
    def back(self):
        while self._history and self._wifi.networkConnected and self._history[-1] in ('WifiList', 'WifiPassword'):
            self._history.pop()
        if self._history:
            self._route = self._history.pop()
            self._set_error('')
            self.routeChanged.emit()

    @Slot(str)
    def connectSelectedNetwork(self, password):
        if self._route not in ('WifiList', 'WifiPassword'):
            return
        self._wifi.connectToNetwork(self._selected_ssid, password)

    @Slot()
    def beginInstallation(self):
        if self._route != 'Profile' or self._installer is not None:
            return
        try:
            problem = self.usernameError or self.passwordError or self.confirmationError or self.hostnameError
            if problem:
                raise backend.InstallError(problem)
            profile = self._profile()
            profile.validate()
            plan = self._option_data()['plan']
        except backend.InstallError as error:
            self._set_error(str(error))
            return
        self._installer = InstallJob(self)
        self._installer.progressChanged.connect(self._progressed)
        self._installer.completed.connect(self._done)
        self._busy = True
        self._pending_plan, self._pending_profile = plan, profile
        self.installationChanged.emit()
        self._go('Installing')
        if self._prefetch.active:
            self._progressed(0.04)
            self._prefetch.finished.connect(self._start_pending_install)
            if not self._prefetch.active:
                self._start_pending_install(True)
        else:
            self._start_pending_install(True)

    def _start_pending_install(self, _ok=True):
        with suppress(TypeError):
            self._prefetch.finished.disconnect(self._start_pending_install)
        plan, profile = self._pending_plan, self._pending_profile
        self._pending_plan = self._pending_profile = None
        if self._installer is None or plan is None:
            return
        self._installer.start(plan, profile, self._prefetch.archive())

    def _progressed(self, value):
        self._progress = max(self._progress, min(1.0, value))
        self.installationChanged.emit()

    def _done(self, ok, message, warnings):
        self._busy, self._failed, self._failure, self._warnings = False, not ok, message, warnings
        if not ok:
            logging.error('Installation failed: %s', message)
        self._password = self._confirmation = ''
        self.profileChanged.emit()
        self.installationChanged.emit()
        self._go('Finished')

    def _power(self, action):
        if self._busy:
            return
        if not self.powerAvailable:
            self._set_error('Power controls are available only in the installer live environment.')
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
        with suppress(TypeError):
            self._prefetch.finished.disconnect(self._start_pending_install)
        self._pending_plan = self._pending_profile = None
        if self._busy and self._installer is not None:
            self._installer.cancel()
            self._installer.wait()
        self._prefetch.close()
        self._wifi.close()
        self._probe_thread.join()

    def _set_layout(self, layout):
        if self._busy or layout == self._layout:
            return
        self._layout = layout
        self.setupChanged.emit()
        if layout != os.environ.get('XKB_DEFAULT_LAYOUT', layout):
            self.restartRequested.emit(layout)

    def _setter(name, signal):
        def set_value(self, value):
            if not self._busy and getattr(self, name) != value:
                setattr(self, name, value)
                getattr(self, signal).emit()
        return set_value

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
    localeName = Property(str, lambda self: self._locale, _setter('_locale', 'setupChanged'), notify=setupChanged)
    layout = Property(str, lambda self: self._layout, _set_layout, notify=setupChanged)
    timezone = Property(str, lambda self: self._timezone, _setter('_timezone', 'setupChanged'), notify=setupChanged)
    selectedNetwork = Property(int, _network_index, _select_network, notify=selectedNetworkChanged)
    selectedSsid = Property(str, lambda self: self._selected_ssid, notify=selectedNetworkChanged)
    selectedNetworkStrength = Property(int, lambda self: int(self._wifi.get(self.selectedNetwork).get('strength', 0)), notify=selectedNetworkChanged)
    selectedDrive = Property(int, lambda self: self._drive, _select_drive, notify=selectedDriveChanged)
    selectedDriveData = Property('QVariantMap', lambda self: self._drives.get(self._drive), notify=selectedDriveChanged)
    installOptions = Property('QVariantList', lambda self: [{k: v for k, v in row.items() if k != 'plan'} for row in self._options()], notify=selectedDriveChanged)
    selectedInstallOption = Property(int, lambda self: self._option, _setter('_option', 'selectedInstallOptionChanged'), notify=selectedInstallOptionChanged)
    username = Property(str, lambda self: self._username, _setter('_username', 'profileChanged'), notify=profileChanged)
    password = Property(str, lambda self: self._password, _setter('_password', 'profileChanged'), notify=profileChanged)
    passwordConfirmation = Property(str, lambda self: self._confirmation, _setter('_confirmation', 'profileChanged'), notify=profileChanged)
    hostname = Property(str, lambda self: self._hostname, _setter('_hostname', 'profileChanged'), notify=profileChanged)
    usernameError = Property(str, lambda self: username_error(self._username), notify=profileChanged)
    passwordError = Property(str, lambda self: password_error(self._password), notify=profileChanged)
    confirmationError = Property(str, lambda self: confirmation_error(self._password, self._confirmation), notify=profileChanged)
    hostnameError = Property(str, lambda self: hostname_error(self._hostname), notify=profileChanged)
    progress = Property(float, lambda self: self._progress, notify=installationChanged)
    failed = Property(bool, lambda self: self._failed, notify=installationChanged)
    powerAvailable = Property(bool, lambda self: os.geteuid() == 0 and Path('/etc/pond-installer-live').is_file(), constant=True)
    failureMessage = Property(str, lambda self: self._failure, notify=installationChanged)
    warnings = Property(str, lambda self: '\n'.join(self._warnings), notify=installationChanged)
