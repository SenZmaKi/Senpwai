import sys
from PyQt6.QtGui import QColor, QPalette, QIcon
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt, QCoreApplication
from windows.main_actual_window import MainWindow
from shared.global_vars_and_funcs import SENPWAI_ICON_PATH, PAHE_NORMAL_COLOR, APP_NAME, settings, KEY_START_IN_FULLSCREEN, log_error, KEY_START_MINIMISED, COMPANY_NAME, VERSION
from types import TracebackType
from typing import cast
from scrapers.gogo import DRIVER_MANAGER
import ctypes

if sys.platform == "win32":
    # Change App ID to ensure task bar icon is Swnpwai's icon instead of Python
    # StackOverflow link: https://stackoverflow.com/questions/1551605/how-to-set-applications-taskbar-icon-in-windows-7/1552105#1552105 
    myappid = f"{COMPANY_NAME}.{APP_NAME}.{VERSION}"
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)

def custom_exception_handler(type_: type[BaseException], value: BaseException, traceback: TracebackType | None):
    log_error(f"Unhandled exception: {type_.__name__}: {value}")
    sys.__excepthook__(type_, value, traceback)


def main():
    QCoreApplication.setApplicationName(APP_NAME)
    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setWindowIcon(QIcon(SENPWAI_ICON_PATH))
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.Window, QColor(PAHE_NORMAL_COLOR))
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow(app)
    app.aboutToQuit.connect(DRIVER_MANAGER.close_driver)
    if cast(bool, settings[KEY_START_MINIMISED]):
         window.hide()
    elif cast(bool, settings[KEY_START_IN_FULLSCREEN]):
            window.showMaximized()
    else:
        window.showNormal()
        window.center_window()
        window.setWindowState(Qt.WindowState.WindowActive)

    sys.excepthook = custom_exception_handler
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
