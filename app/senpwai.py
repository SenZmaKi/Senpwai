import sys
from PyQt6.QtGui import QColor, QPalette, QIcon
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt, QCoreApplication
from windows.main_actual_window import MainWindow
from shared.global_vars_and_funcs import senpwai_icon_path, pahe_normal_color, app_name, settings, key_start_in_fullscreen, log_error

def custom_exception_handler(type_, value, traceback):
    log_error(f"Unhandled exception: {type_.__name__}: {value}")
    sys.__excepthook__(type_, value, traceback)  # Call the default exception handler

def main():
    QCoreApplication.setApplicationName(app_name)
    app = QApplication(sys.argv)
    app.setApplicationName(app_name)
    app.setWindowIcon(QIcon(senpwai_icon_path))
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.Window, QColor(pahe_normal_color))
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow()
    if settings[key_start_in_fullscreen]:
        window.showMaximized()
    else:
        window.show()
        window.center_window()

    sys.excepthook = custom_exception_handler  # Install the custom exception handler
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
