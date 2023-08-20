import sys
from PyQt6.QtGui import QColor, QPalette, QIcon
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt, QCoreApplication
from windows.main_actual_window import MainWindow
from shared.global_vars_and_funcs import SENPWAI_ICON_PATH, PAHE_NORMAL_COLOR, APP_NAME, settings, KEY_START_IN_FULLSCREEN, log_error
from types import TracebackType
from typing import cast


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

    window = MainWindow()
    if cast(bool, settings[KEY_START_IN_FULLSCREEN]):
        if sys.platform == "win32":
            window.showMaximized()
        else:
            # TO-DO: Fix bug where window.showMaxmized() does not work on Linux, also maximize window button does not work
            window.showFullScreen()
    else:
        window.show()
        window.center_window()

    sys.excepthook = custom_exception_handler
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
