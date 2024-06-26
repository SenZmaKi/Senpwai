#!/usr/bin/env python3

import ctypes
import sys

from PyQt6.QtCore import QCoreApplication, Qt
from PyQt6.QtGui import QPalette
from PyQt6.QtWidgets import QApplication
from senpwai.common.static import APP_NAME, custom_exception_handler, OS
from senpwai.windows.main import MainWindow


def windows_app_initialisation():
    # Change App ID to ensure task bar icon is Swnpwai's icon instead of Python for pip installs
    # StackOverflow Answer link: https://stackoverflow.com/questions/1551605/how-to-set-applications-taskbar-icon-in-windows-7/1552105#1552105
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_NAME)
    # Convert the app title to a null-terminated C string
    app_title_c = (APP_NAME + "\0").encode("UTF-8")
    # Check if the app is already running by searching for its window
    window = ctypes.windll.user32.FindWindowA(None, app_title_c)
    if window != 0:
        # If the app is running, bring it into focus
        ctypes.windll.user32.ShowWindow(window, 9)  # 9 is SW_RESTORE
        ctypes.windll.user32.SetForegroundWindow(window)
        sys.exit(0)


def main():
    if OS.is_windows:
        windows_app_initialisation()

    QCoreApplication.setApplicationName(APP_NAME)
    args = sys.argv
    app = QApplication(args)
    app.setApplicationName(APP_NAME)
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow(app)
    app.setWindowIcon(window.senpwai_icon)
    window.show_with_settings(args)
    sys.excepthook = custom_exception_handler
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
