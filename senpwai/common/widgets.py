import os
from typing import Any, Callable, cast
import time

from PyQt6.QtCore import QEvent, QMutex, QObject, QSize, Qt, QTimer, QUrl
from PyQt6.QtGui import (
    QIcon,
    QKeyEvent,
    QMovie,
    QPaintEvent,
    QPainter,
    QPainterPath,
    QPen,
    QPixmap,
)
from PyQt6.QtMultimedia import QAudioOutput, QMediaPlayer
from PyQt6.QtWidgets import (
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QTextBrowser,
    QVBoxLayout,
    QWidget,
)

from senpwai.common.classes import SETTINGS
from senpwai.common.static import (
    FOLDER_ICON_PATH,
    GOGO_NORM_MODE,
    GOGO_NORMAL_COLOR,
    PAHE_EXTRA_COLOR,
    PAHE_NORMAL_COLOR,
    PAHE_PRESSED_COLOR,
    Q_480,
    RED_NORMAL_COLOR,
    RED_PRESSED_COLOR,
    fix_qt_path_for_windows,
    open_folder,
    requires_admin_access,
)

PYQT_MAX_INT = 2147483647


def set_minimum_size_policy(object):
    object.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Minimum)
    object.setFixedSize(object.sizeHint())


class BckgImg(QLabel):
    def __init__(self, parent: QWidget, image_path: str) -> None:
        super().__init__(parent)
        pixmap = QPixmap(image_path)
        self.setPixmap(pixmap)
        self.setScaledContents(True)


class Animation(QLabel):
    def __init__(
        self,
        animation_path: str,
        animation_size_x: int,
        animation_size_y: int,
        parent: QWidget | None = None,
    ):
        super().__init__(parent)
        self.animation = QMovie(animation_path)
        self.animation.setScaledSize(QSize(animation_size_x, animation_size_y))
        self.setMovie(self.animation)

    def start(self):
        return self.animation.start()

    def stop(self):
        return self.animation.stop()


class StyledLabel(QLabel):
    def __init__(
        self,
        parent=None,
        font_size: int = 20,
        bckg_color: str = "rgba(0, 0, 0, 220)",
        border_radius=10,
        font_color="white",
    ):
        super().__init__(parent)
        self.setStyleSheet(
            f"""
                    QLabel {{
                        color: {font_color};
                        font-size: {font_size}px;
                        font-family: {SETTINGS.font_family};
                        background-color: {bckg_color};
                        border-radius: {border_radius}px;
                        border: 1px solid black;
                        padding: 5px;
                    }}
                            """
        )


class StyledTextBrowser(QTextBrowser):
    def __init__(
        self,
        parent=None,
        font_size: int = 20,
        bckg_color: str = "rgba(0, 0, 0, 220)",
        border_radius=10,
        font_color="white",
    ):
        super().__init__(parent)
        self.setOpenExternalLinks(True)
        self.setStyleSheet(
            f"""
                    QTextEdit {{
                        color: {font_color};
                        font-size: {font_size}px;
                        font-family: {SETTINGS.font_family};
                        background-color: {bckg_color};
                        border-radius: {border_radius}px;
                        border: 1px solid black;
                        padding: 5px;
                    }}
                            """
        )


class StyledButton(QPushButton):
    def __init__(
        self,
        parent: QWidget | None,
        font_size: int,
        font_color: str,
        normal_color: str,
        hover_color: str,
        pressed_color: str,
        border_radius=12,
    ):
        super().__init__()
        if parent:
            self.setParent(parent)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet(
            f"""
            QPushButton {{
                color: {font_color};
                background-color: {normal_color};
                border: 1px solid black;
                font-size: {font_size}px;
                font-family: {SETTINGS.font_family};
                padding: 10px;
                border-radius: {border_radius}px;
            }}
            QPushButton:hover {{
                background-color: {hover_color};
            }}
            QPushButton:pressed {{  
                background-color: {pressed_color};
            }}
        """
        )
        self.installEventFilter(self)

    def eventFilter(self, a0: QObject | None, a1: QEvent | None):
        if a0 == self:
            if (
                isinstance(a1, QKeyEvent)
                and a1.type() == a1.Type.KeyPress
                and (a1.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter))
            ):
                self.animateClick()
                return True

        return super().eventFilter(a0, a1)


class DualStateButton(StyledButton):
    def __init__(
        self,
        parent: QWidget | None,
        font_size: int,
        font_color: str,
        hover_color: str,
        set_color: str,
        on_text: str,
        off_text: str,
        unset_color="rgba(128, 128, 128, 255)",
        border_radius=12,
    ):
        super().__init__(
            parent,
            font_size,
            font_color,
            unset_color,
            hover_color,
            set_color,
            border_radius,
        )
        self.on = False
        self.on_text = on_text
        self.off_text = off_text
        self.setText(on_text)
        self.off_stylesheet = self.styleSheet()
        styles_to_overwride = f"""
            QPushButton {{
            border-radius: 7px;
            background-color: {set_color};
        }}
        QPushButton:hover {{
            background-color: {hover_color};
        }}
    """
        self.on_stylesheet = self.off_stylesheet + styles_to_overwride
        self.clicked.connect(self.change_status)

    def change_status(self):
        self.on = not self.on
        if self.on:
            self.setStyleSheet(self.on_stylesheet)
            self.setText(self.off_text)
        else:
            self.setStyleSheet(self.off_stylesheet)
            self.setText(self.on_text)
        set_minimum_size_policy(self)


class OptionButton(StyledButton):
    def __init__(
        self,
        parent: QWidget | None,
        option: Any,
        option_displayed: str,
        font_size: int,
        chosen_color: str,
        hover_color: str,
        font_color="white",
    ):
        super().__init__(
            parent,
            font_size,
            font_color,
            "rgba(128, 128, 128, 255)",
            chosen_color,
            hover_color,
        )
        self.not_picked_style_sheet = self.styleSheet()
        styles_to_overwride = f"""
            QPushButton {{
            border-radius: 7px;
            background-color: {chosen_color};
        }}
        QPushButton:hover {{
            background-color: {chosen_color};
        }}
    """
        self.picked_style_sheet = self.not_picked_style_sheet + styles_to_overwride
        self.option = option
        self.setText(option_displayed)
        self.clicked.connect(lambda: self.set_picked_status(True))

    def set_picked_status(self, picked: bool):
        if picked:
            self.setStyleSheet(self.picked_style_sheet)
        else:
            self.setStyleSheet(self.not_picked_style_sheet)


class Icon(QIcon):
    def __init__(self, x: int, y: int, icon_path: str):
        self.x = x
        self.y = y
        pixmap = QPixmap(icon_path).scaled(
            self.x, self.y, Qt.AspectRatioMode.IgnoreAspectRatio
        )
        super().__init__(pixmap)


class IconButton(QPushButton):
    def __init__(
        self, icon: Icon, size_factor: int | float, parent: QWidget | None = None
    ):
        super().__init__(parent)
        self.setFixedSize(icon.x, icon.y)
        self.setIcon(icon)
        self.setIconSize(self.size() / size_factor)
        self.enterEvent = lambda event: self.setIconSize(QSize(icon.x, icon.y))
        self.leaveEvent = lambda a0: self.setIconSize(
            QSize(icon.x, icon.y) / size_factor
        )
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet(
            """
            QPushButton {
                border: none; 
                background-color: transparent;
            }"""
        )
        self.installEventFilter(self)

    def eventFilter(self, a0: QObject | None, a1: QEvent | None):
        if a0 == self:
            if (
                isinstance(a1, QKeyEvent)
                and a1.type() == a1.Type.KeyPress
                and ((a1.key() == Qt.Key.Key_Return) or (a1.key() == Qt.Key.Key_Enter))
            ):
                if isinstance(a0, QPushButton):
                    self.animateClick()
                    return True

        return super().eventFilter(a0, a1)


class AnimationAndText(QWidget):
    def __init__(
        self,
        animation_path: str,
        animation_size_x: int,
        animation_size_y: int,
        text: str,
        paint_x: int,
        paint_y: int,
        font_size: int,
        parent: QWidget | None = None,
    ):
        super().__init__(parent)
        self.animation = Animation(
            animation_path, animation_size_x, animation_size_y, parent
        )
        self.animation_path = animation_path
        self.text_label = OutlinedLabel(parent, paint_x, paint_y)
        self.text_label.setText(text)
        self.text_label.setStyleSheet(
            f"""
                    OutlinedLabel {{
                        color: #FFEF00;
                        font-size: {font_size}px;
                        font-family: {SETTINGS.font_family};
                        }}
                        """
        )
        self.main_layout = QVBoxLayout()
        self.main_layout.addWidget(self.animation)
        self.main_layout.addWidget(self.text_label)
        self.main_layout.setAlignment(self.animation, Qt.AlignmentFlag.AlignCenter)
        self.main_layout.setAlignment(self.text_label, Qt.AlignmentFlag.AlignCenter)
        self.setLayout(self.main_layout)

    def start(self):
        return self.animation.start()

    def stop(self):
        return self.animation.stop()


class OutlinedLabel(QLabel):
    def __init__(self, parent: QWidget | None, paint_x: int, paint_y: int):
        self.paint_x = paint_x
        self.paint_y = paint_y
        super().__init__(parent)

    def paintEvent(self, a0: QPaintEvent | None):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Draw the outline around the text
        pen = QPen()
        pen.setWidth(5)
        painter.setPen(pen)

        path = QPainterPath()
        path.addText(self.paint_x, self.paint_y, self.font(), self.text())
        painter.drawPath(path)

        # Call the parent class's paintEvent to draw the label background and other properties
        painter.end()
        return super().paintEvent(a0)


class OutlinedButton(StyledButton):
    def __init__(
        self,
        paint_x,
        paint_y,
        parent: QWidget | None,
        font_size: int,
        font_color: str,
        normal_color: str,
        hover_color: str,
        pressed_color: str,
        border_radius=12,
    ):
        self.paint_x = paint_x
        self.paint_y = paint_y
        super().__init__(
            parent,
            font_size,
            font_color,
            normal_color,
            hover_color,
            pressed_color,
            border_radius,
        )

    def paintEvent(self, a0: QPaintEvent | None):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Draw the outline around the text
        pen = QPen()
        pen.setWidth(5)
        painter.setPen(pen)

        path = QPainterPath()
        path.addText(self.paint_x, self.paint_y, self.font(), self.text())
        painter.drawPath(path)

        # Call the parent class's paintEvent to draw the button background and other properties
        painter.end()
        return super().paintEvent(a0)


class AudioPlayer(QMediaPlayer):
    def __init__(self, parent: QWidget | None, audio_path: str, volume=50):
        super().__init__(parent)
        audio_output = QAudioOutput(parent)
        self.setAudioOutput(audio_output)
        self.setSource(QUrl.fromLocalFile(audio_path))
        audio_output.setVolume(volume)


class ErrorLabel(StyledLabel):
    def __init__(
        self,
        font_size: int,
        shown_duration_in_secs: int = 3,
        parent: QWidget | None = None,
    ):
        super().__init__(parent, font_size, font_color="red")
        self.shown_duration_in_secs = shown_duration_in_secs
        self.timer = QTimer(self)

    def show(self):
        if not self.timer.isActive():
            self.timer.setSingleShot(True)
            self.timer.timeout.connect(self.hide)
            self.timer.start(self.shown_duration_in_secs * 1000)
            return super().show()


class ProgressBarWithoutButtons(QWidget):
    ongoing_stylesheet = f"""
            QProgressBar {{
                border: 1px solid black;
                color: black;
                text-align: center;
                border-radius: 10px;
                background-color: rgba(255, 255, 255, 150);
                font-size: 22px;
                font-family: {SETTINGS.font_family};
            }}

            QProgressBar::chunk {{
                background-color: {PAHE_NORMAL_COLOR};
                border-radius: 10px;
            }}
        """
    styles_to_overwride = """
            QProgressBar::chunk {
                background-color: #FFA756;
                border-radius: 10px;
            }
        """
    paused_stylesheet = ongoing_stylesheet + styles_to_overwride
    styles_to_overwride = f"""
            QProgressBar::chunk {{
                background-color: {GOGO_NORMAL_COLOR};
            }}"""
    completed_stylesheet = s = ongoing_stylesheet + styles_to_overwride
    styles_to_overwride = f"""
            QProgressBar::chunk {{
            background-color: {RED_NORMAL_COLOR}
            }}"""
    cancelled_stylesheet = ongoing_stylesheet + styles_to_overwride
    text_style_sheet = f"""
                    OutlinedLabel {{
                    color: white;
                    font-size: 26px;
                    font-family: {SETTINGS.font_family};
                        }}
                        """

    def __init__(
        self,
        parent: QWidget | None,
        task_title: str,
        item_task_is_applied_on: str,
        total_value: int,
        units: str,
        units_divisor: int = 1,
        delete_on_completion=True,
    ):
        super().__init__(parent)
        self.item_task_is_applied_on = item_task_is_applied_on
        self.total_value = total_value
        self.units = units
        self.units_divisor = units_divisor
        self.mutex = QMutex()
        self.items_layout = QHBoxLayout(self)
        self.delete_on_completion = delete_on_completion
        self.setLayout(self.items_layout)
        self.paused = False
        self.cancelled = False

        self.bar = QProgressBar(self)
        self.bar.setValue(0)
        self.bar.setMaximum(total_value)
        self.task_title = task_title
        self.bar.setFormat(f"{task_title} {item_task_is_applied_on}")
        self.bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.bar.setStyleSheet(self.ongoing_stylesheet)
        height = 50
        self.percentage = OutlinedLabel(self, 1, 35)
        self.percentage.setText("0 %")
        self.percentage.setFixedHeight(height)
        self.percentage.setStyleSheet(self.text_style_sheet)

        self.rate = OutlinedLabel(self, 1, 40)
        self.rate.setText(f" ? {units}/s")
        self.rate.setFixedHeight(height)
        self.rate.setStyleSheet(self.text_style_sheet)

        self.eta = OutlinedLabel(self, 1, 40)
        self.eta.setText("? secs left")
        self.eta.setFixedHeight(height)
        self.eta.setStyleSheet(self.text_style_sheet)

        self.current_against_max_values = OutlinedLabel(self, 1, 40)
        self.current_against_max_values.setText(
            f"0/{round(total_value / units_divisor)} {units}"
        )
        self.current_against_max_values.setFixedHeight(height)
        self.current_against_max_values.setStyleSheet(self.text_style_sheet)

        self.items_layout.addWidget(self.percentage)
        self.items_layout.addWidget(self.bar)
        self.items_layout.addWidget(self.eta)
        self.items_layout.addWidget(self.rate)
        self.items_layout.addWidget(self.current_against_max_values)
        self.prev_time = time.time()

    def delete_after_timer(self) -> None:
        QTimer(self).singleShot(40000, self.deleteLater)

    def is_complete(self) -> bool:
        return self.bar.value() >= self.total_value

    def cancel(self):
        if not self.paused and not self.is_complete() and not self.cancelled:
            self.bar.setFormat(f"Cancelled {self.item_task_is_applied_on}")
            self.cancelled = True
            self.bar.setStyleSheet(self.cancelled_stylesheet)
            if self.delete_on_completion:
                self.delete_after_timer()

    def pause_or_resume(self):
        if not self.cancelled and not self.is_complete():
            self.paused = not self.paused
            if self.paused:
                self.bar.setStyleSheet(self.paused_stylesheet)
                self.bar.setFormat(f"Paused {self.item_task_is_applied_on}")
            else:
                self.bar.setStyleSheet(self.ongoing_stylesheet)
                self.bar.setFormat(f"{self.task_title} {self.item_task_is_applied_on}")

    def update_bar(self, added_value: int):
        self.mutex.lock()
        curr_time = time.time()
        new_value = self.bar.value() + added_value
        time_elapsed = curr_time - self.prev_time
        max_value = self.bar.maximum()
        complete = False
        if new_value >= max_value:
            new_value = max_value
            self.bar.setFormat(f"Completed {self.item_task_is_applied_on}")
            self.bar.setStyleSheet(self.completed_stylesheet)
            complete = True
        self.bar.setValue(new_value)
        percent_new_value = round(new_value / max_value * 100)
        self.percentage.setText(f"{percent_new_value}%")
        self.current_against_max_values.setText(
            f" {round(new_value / self.units_divisor)}/{round(max_value / self.units_divisor)} {self.units}"
        )
        # If statement to handle division by zero error where downloads update super quick so elapsed time is roughly zero
        if time_elapsed > 0 and added_value > 0:
            rate = added_value / time_elapsed
            eta = (max_value - new_value) * (1 / rate)
            if eta >= 3600:
                self.eta.setText(f"{round(eta / 3600, 1)} hrs left")
            elif eta >= 60:
                self.eta.setText(f"{round(eta / 60)} mins left")
            else:
                self.eta.setText(f"{round(eta)} secs left")
            self.rate.setText(f" {round(rate / self.units_divisor, 1)} {self.units}/s")
            self.prev_time = curr_time
        if complete and self.delete_on_completion:
            self.delete_after_timer()
        self.mutex.unlock()


class ProgressBarWithButtons(ProgressBarWithoutButtons):
    def __init__(
        self,
        parent: QWidget | None,
        task_title: str,
        item_task_is_applied_on: str,
        total_value: int,
        units: str,
        units_divisor: int,
        pause_icon: Icon,
        resume_icon: Icon,
        cancel_icon: Icon,
        pause_callback: Callable[[], None] | None = None,
        cancel_callback: Callable[[], None] | None = None,
        delete_on_completion=True,
    ):
        super().__init__(
            parent,
            task_title,
            item_task_is_applied_on,
            total_value,
            units,
            units_divisor,
            delete_on_completion=delete_on_completion,
        )
        self.pause_icon = pause_icon
        self.resume_icon = resume_icon
        self.pause_callback = pause_callback
        self.cancel_callback = cancel_callback
        self.pause_button = IconButton(pause_icon, 1.3, self)
        self.cancel_button: IconButton = IconButton(cancel_icon, 1.3, self)
        self.pause_button.clicked.connect(self.pause_or_resume)
        self.cancel_button.clicked.connect(self.cancel)
        self.items_layout.addWidget(self.pause_button)
        self.items_layout.addWidget(self.cancel_button)

    def pause_or_resume(self):
        if self.pause_callback:
            self.pause_callback()
        super().pause_or_resume()
        if self.paused:
            return self.pause_button.setIcon(self.resume_icon)
        self.pause_button.setIcon(self.pause_icon)

    def cancel(self):
        if self.cancel_callback:
            self.cancel_callback()
        super().cancel()


class ScrollableSection(QScrollArea):
    def __init__(self, layout: QHBoxLayout | QVBoxLayout):
        super().__init__()
        self.setWidgetResizable(True)
        self.main_widget = QWidget()
        self.main_widget.setLayout(layout)
        self.main_layout = self.layout()
        self.setWidget(self.main_widget)
        self.setStyleSheet(
            """
                    QWidget {
                        background-color: transparent;
                        border: None;
                        }"""
        )


class FolderPickerButton(IconButton):
    def __init__(
        self,
        size_x: int,
        size_y: int,
        path: str | None = None,
        parent: QWidget | None = None,
        picker_dialog_title: str | None = None,
        picker_error_callback: Callable[[str], None] | None = None,
        picker_success_callback: Callable[[str], None] | None = None,
    ):
        super().__init__(Icon(size_x, size_y, FOLDER_ICON_PATH), 1.3, parent)
        self.path = path
        self.picker_error_callback = picker_error_callback
        self.picker_success_callback = picker_success_callback
        self.picker_dialog_title = picker_dialog_title
        if path:
            self.set_folder_path(path)
        self.clicked.connect(self.pick_folder)

    def set_folder_path(self, path: str) -> None:
        self.path = path
        self.setToolTip(f"{path}\nClick to choose a new folder")

    def pick_folder(self):
        folder = QFileDialog.getExistingDirectory(
            self, directory=self.path, caption=self.picker_dialog_title
        )
        folder = fix_qt_path_for_windows(folder)
        error = None
        if requires_admin_access(folder):
            error = "That folder requires admin access, kisama da"
        elif not os.path.isdir(folder):
            error = "Yare yare daze, that folder is invalid"
        if error:
            if self.picker_error_callback:
                self.picker_error_callback(error)
            return
        self.set_folder_path(folder)
        if self.picker_success_callback:
            self.picker_success_callback(folder)


class FolderButton(IconButton):
    def __init__(
        self, path: str, size_x: int, size_y: int, parent: QWidget | None = None
    ):
        super().__init__(Icon(size_x, size_y, FOLDER_ICON_PATH), 1.3, parent)
        self.set_folder_path(path)

    def set_folder_path(self, path: str):
        self.folder_path = path
        self.setToolTip(path)
        self.clicked.connect(lambda: open_folder(self.folder_path))


class NumberInput(QLineEdit):
    def __init__(self, font_size: int = 14, parent: QWidget | None = None):
        super().__init__(parent)
        self.installEventFilter(self)
        self.setStyleSheet(
            f"""
            QLineEdit{{
                border: 2px solid black;
                border-radius: 12px;
                padding: 5px;
                color: black;
                font-size: {font_size}px;
                font-family: {SETTINGS.font_family};
                background-color: white;
            }}
        """
        )

    def eventFilter(self, a0: QObject | None, a1: QEvent | None):
        if a1 is not None and cast(QEvent, a1.type()) == QKeyEvent.Type.KeyPress:
            if cast(QKeyEvent, a1).key() in (
                Qt.Key.Key_0,
                Qt.Key.Key_1,
                Qt.Key.Key_2,
                Qt.Key.Key_3,
                Qt.Key.Key_4,
                Qt.Key.Key_5,
                Qt.Key.Key_6,
                Qt.Key.Key_7,
                Qt.Key.Key_8,
                Qt.Key.Key_9,
                Qt.Key.Key_Backspace,
                Qt.Key.Key_Delete,
                Qt.Key.Key_Left,
                Qt.Key.Key_Right,
            ):
                return False
            else:
                return True
        return super().eventFilter(a0, a1)


class QualityButton(OptionButton):
    def __init__(self, window: QWidget, quality: str, font_size: int):
        super().__init__(
            window, quality, quality, font_size, PAHE_NORMAL_COLOR, PAHE_PRESSED_COLOR
        )
        self.quality = quality
        if quality == Q_480:
            self.setToolTip("Usually only available on Gogoanime")


class SubDubButton(OptionButton):
    def __init__(self, window: QWidget, sub_or_dub: str, font_size: int):
        super().__init__(
            window,
            sub_or_dub,
            sub_or_dub.upper(),
            font_size,
            PAHE_NORMAL_COLOR,
            PAHE_PRESSED_COLOR,
        )
        self.sub_or_dub = sub_or_dub


class GogoNormOrHlsButton(OptionButton):
    def __init__(self, window: QWidget | None, norm_or_hls: str, font_size: int):
        super().__init__(
            window,
            norm_or_hls,
            norm_or_hls.upper(),
            font_size,
            RED_NORMAL_COLOR,
            RED_PRESSED_COLOR,
        )
        self.norm_or_hls = norm_or_hls
        if self.norm_or_hls == GOGO_NORM_MODE:
            return self.setToolTip(
                "Normal download functionality, similar to Animepahe but may occassionally fail"
            )
        self.setToolTip(
            "Guaranteed to work and usually downloads are faster, it's like downloading a live stream as opposed to a file\nYou need to install FFmpeg for it to work but Senpwai will try to automatically install it"
        )


class HorizontalLine(QFrame):
    def __init__(self, color: str = "black", parent: QWidget | None = None):
        super().__init__(parent)
        self.setFrameShape(QFrame.Shape.HLine)
        self.setStyleSheet(
            f"""
                        QFrame {{ 
                            background-color: {color}; 
                            }}
                            """
        )


class Title(StyledLabel):
    def __init__(self, text: str, font=33):
        super().__init__(None, font, PAHE_EXTRA_COLOR, font_color="black")
        set_minimum_size_policy(self)
        self.setText(text)
