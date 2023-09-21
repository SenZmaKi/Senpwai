import sys
from PyQt6.QtGui import QPalette
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt, QCoreApplication
from windows.main_actual_window import MainWindow
from shared.global_vars_and_funcs import APP_NAME, log_error, COMPANY_NAME, VERSION
from types import TracebackType
import ctypes

if sys.platform == "win32":
    # Change App ID to ensure task bar icon is Swnpwai's icon instead of Python
    # StackOverflow Answer link: https://stackoverflow.com/questions/1551605/how-to-set-applications-taskbar-icon-in-windows-7/1552105#1552105 
    myappid = f"{COMPANY_NAME}.{APP_NAME}.{VERSION}"
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)

def custom_exception_handler(type_: type[BaseException], value: BaseException, traceback: TracebackType | None):
    log_error(f"Unhandled exception: {type_.__name__}: {value}")
    sys.__excepthook__(type_, value, traceback)


def main():
    QCoreApplication.setApplicationName(APP_NAME)
    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow(app)
    app.setWindowIcon(window.senpwai_icon)
    window.show_with_settings()
    sys.excepthook = custom_exception_handler
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
