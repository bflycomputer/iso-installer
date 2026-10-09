"""Pond Installer desktop entry point."""
from pathlib import Path
import sys

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from .controller import Controller


def main():
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
