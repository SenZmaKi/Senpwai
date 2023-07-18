import sys
from PyQt6.QtGui import QColor, QPalette, QIcon
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt
from windows.main_actual_window import MainWindow
from shared.global_vars_and_funcs import senpwai_icon_path, pahe_normal_color, app_name, settings, key_start_in_fullscreen

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName(app_name)
    app.setWindowIcon(QIcon(senpwai_icon_path))
    # Set the purple theme
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.Window, QColor(
        pahe_normal_color))  # type: ignore
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow()
    if settings[key_start_in_fullscreen]:
        window.showMaximized()
    else:
        window.show()
        window.center_window()
    sys.exit(app.exec())
