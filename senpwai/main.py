#!/usr/bin/env python3

import ctypes
import sys

from PyQt6.QtCore import QCoreApplication, Qt
from PyQt6.QtGui import QPalette
from PyQt6.QtWidgets import QApplication
from senpwai.common.static import APP_NAME, OS
from senpwai.windows.main import MainWindow


def windows_set_app_user_model_id():
    # Change App ID to ensure task bar icon is Senpwai's icon instead of Python for pip installs
    # Stack Overflow answer link: https://stackoverflow.com/questions/1551605/how-to-set-applications-taskbar-icon-in-windows-7/1552105#1552105
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_NAME)


def windows_focus_app_if_is_already_running():
    # Convert the app name to a null-terminated C string
    app_title_c = (APP_NAME + "\0").encode()
    # Find the app's already running window
    window = ctypes.windll.user32.FindWindowA(None, app_title_c)
    if window == 0:
        return
    # If the app is already running, bring it into focus then exit
    ctypes.windll.user32.ShowWindow(window, 9)  # 9 is SW_RESTORE
    ctypes.windll.user32.SetForegroundWindow(window)
    sys.exit(0)


def init():
    if OS.is_windows:
        windows_set_app_user_model_id()
        if "--force" not in sys.argv:
            windows_focus_app_if_is_already_running()


def main():
    init()
    QCoreApplication.setApplicationName(APP_NAME)
    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)
    window = MainWindow(app)
    app.setWindowIcon(window.senpwai_icon)
    window.show_with_settings()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
