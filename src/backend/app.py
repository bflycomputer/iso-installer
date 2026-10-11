"""Pond Installer desktop entry point."""
from pathlib import Path
import logging
import sys

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from .controller import Controller


def main():
    handlers = [logging.StreamHandler()]
    try:
        handlers.append(logging.FileHandler('/var/log/pond-installer.log'))
    except OSError:
        pass
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s', handlers=handlers)
    app = QGuiApplication(sys.argv)
    app.setApplicationName('Pond Installer')
    app.setDesktopFileName('pond-installer')
    engine = QQmlApplicationEngine()
    controller = Controller()
    app.aboutToQuit.connect(controller.close)
    engine.rootContext().setContextProperty('controller', controller)
    engine.load(QUrl.fromLocalFile(str(Path(__file__).parent.parent / 'frontend/ui/Main.qml')))
    if not engine.rootObjects():
        controller.close()
        return 1
    return app.exec()
