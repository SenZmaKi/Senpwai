import ctypes
import sys

from PyQt6.QtCore import QCoreApplication, Qt
from PyQt6.QtGui import QPalette
from PyQt6.QtWidgets import QApplication
from senpwai.utils.static_utils import APP_NAME, custom_exception_handler
from senpwai.windows.primary_windows import MainWindow


def windows_app_initialisation():
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
    if sys.platform == "win32":
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
