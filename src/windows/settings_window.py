import os
from sys import platform as sys_platform
from typing import Callable, cast

from pylnk3 import for_file as pylnk3_for_file
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QFileDialog, QHBoxLayout, QLayoutItem, QVBoxLayout, QWidget
from utils.class_utils import SETTINGS
from utils.scraper_utils import try_deleting_safely
from utils.static_utils import (
    AMOGUS_EASTER_EGG,
    APP_NAME,
    DUB,
    GOGO,
    GOGO_HLS_MODE,
    GOGO_NORM_MODE,
    GOGO_NORMAL_COLOR,
    GOGO_PRESSED_COLOR,
    MINIMISED_TO_TRAY_ARG,
    PAHE,
    PAHE_HOVER_COLOR,
    PAHE_NORMAL_COLOR,
    PAHE_PRESSED_COLOR,
    Q_360,
    Q_480,
    Q_720,
    Q_1080,
    RED_HOVER_COLOR,
    RED_NORMAL_COLOR,
    RED_PRESSED_COLOR,
    SETTINGS_WINDOW_BCKG_IMAGE_PATH,
    SRC_DIRECTORY,
    SUB,
    requires_admin_access,
)
from utils.widget_utils import (
    ErrorLabel,
    GogoNormOrHlsButton,
    HorizontalLine,
    NumberInput,
    OptionButton,
    QualityButton,
    ScrollableSection,
    StyledButton,
    StyledLabel,
    SubDubButton,
    fix_qt_path_for_windows,
    set_minimum_size_policy,
)

from windows.download_window import DownloadWindow
from windows.primary_windows import AbstractWindow, MainWindow


class SettingsWindow(AbstractWindow):
    def __init__(self, main_window: MainWindow) -> None:
        super().__init__(main_window, SETTINGS_WINDOW_BCKG_IMAGE_PATH)
        self.font_size = 15
        main_layout = QHBoxLayout()
        main_widget = ScrollableSection(main_layout)
        left_layout = QVBoxLayout()
        left_widget = QWidget()
        left_widget.setLayout(left_layout)
        right_layout = QVBoxLayout()
        right_widget = QWidget()
        right_widget.setLayout(right_layout)
        main_layout.addWidget(left_widget)
        main_layout.addWidget(right_widget)

        self.sub_dub_setting = SubDubSetting(self)
        self.quality_setting = QualitySetting(self)
        self.max_simultaneous_downloads_setting = MaxSimultaneousDownloadsSetting(self)
        self.make_download_complete_notification_setting = AllowNotificationsSetting(
            self
        )
        self.start_in_fullscreen = StartInFullscreenSetting(self)
        self.download_folder_setting = DownloadFoldersSetting(self, main_window)
        self.gogo_norm_or_hls_mode_setting = GogoNormOrHlsSetting(self)
        self.tracked_anime = TrackedAnimeListSetting(
            self,
        )
        self.auto_download_site = AutoDownloadSite(self)
        self.check_for_new_eps_after = CheckForNewEpsAfterSetting(
            self, main_window.download_window
        )
        self.gogo_skip_calculate = GogoSkipCalculate(self)
        if sys_platform == "win32":
            self.run_on_startup = RunOnStartUp(self)
        left_layout.addWidget(self.sub_dub_setting)
        left_layout.addWidget(self.quality_setting)
        left_layout.addWidget(self.max_simultaneous_downloads_setting)
        left_layout.addWidget(self.gogo_norm_or_hls_mode_setting)
        left_layout.addWidget(self.gogo_skip_calculate)
        left_layout.addWidget(self.make_download_complete_notification_setting)
        left_layout.addWidget(self.start_in_fullscreen)
        if sys_platform == "win32":
            left_layout.addWidget(self.run_on_startup)
        right_layout.addWidget(self.download_folder_setting)
        right_layout.addWidget(self.auto_download_site)
        right_layout.addWidget(self.check_for_new_eps_after)
        right_layout.addWidget(self.tracked_anime)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)


class FolderSetting(QWidget):
    def __init__(
        self,
        settings_window: SettingsWindow,
        main_window: MainWindow,
        setting_info: str,
        setting_tool_tip: str | None,
    ):
        super().__init__()
        self.settings_window = settings_window
        self.font_size = settings_window.font_size
        self.main_window = main_window
        self.main_layout = QVBoxLayout()
        settings_label = StyledLabel(font_size=self.font_size + 5)
        settings_label.setText(setting_info)
        if setting_tool_tip:
            settings_label.setToolTip(setting_tool_tip)
        set_minimum_size_policy(settings_label)
        self.error_label = ErrorLabel(18, 6)
        self.error_label.hide()
        add_button = StyledButton(
            self,
            self.font_size,
            "white",
            "green",
            GOGO_NORMAL_COLOR,
            GOGO_PRESSED_COLOR,
        )
        add_button.clicked.connect(self.add_folder_to_settings)
        add_button.setText("ADD")
        set_minimum_size_policy(add_button)
        settings_label_and_add_button_widget = QWidget()
        settings_label_and_add_button_layout = QHBoxLayout()
        settings_label_and_add_button_layout.addWidget(settings_label)
        settings_label_and_add_button_layout.addWidget(add_button)
        settings_label_and_add_button_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        settings_label_and_add_button_widget.setLayout(
            settings_label_and_add_button_layout
        )
        self.main_layout.addWidget(self.error_label)
        self.main_layout.addWidget(settings_label_and_add_button_widget)
        line = HorizontalLine()
        line.setFixedHeight(7)
        self.main_layout.addWidget(line)
        self.folder_widgets_layout = QVBoxLayout()
        for idx, folder in enumerate(SETTINGS.download_folder_paths):
            self.folder_widgets_layout.addWidget(
                FolderWidget(main_window, self, 14, folder, idx),
                alignment=Qt.AlignmentFlag.AlignTop,
            )
        folder_widgets_widget = ScrollableSection(self.folder_widgets_layout)
        self.main_layout.addWidget(folder_widgets_widget)
        self.setLayout(self.main_layout)

    def error(self, error_message: str):
        self.error_label.setText(error_message)
        self.error_label.update()
        set_minimum_size_policy(self.error_label)
        self.error_label.show()

    def is_valid_new_folder(self, new_folder_path: str) -> bool:
        if requires_admin_access(new_folder_path):
            self.error("The folder you chose requires admin access so i've ignored it")
            return False
        elif not os.path.isdir(new_folder_path):
            self.error("Choose a valid folder, onegaishimasu")
            return False
        elif new_folder_path in SETTINGS.download_folder_paths:
            self.error("Baka!!! that folder is already in the settings")
            return False
        else:
            return True

    def update_widget_indices(self):
        for idx in range(self.folder_widgets_layout.count()):
            cast(
                FolderWidget,
                cast(QLayoutItem, self.folder_widgets_layout.itemAt(idx)).widget(),
            ).index = idx

    def change_from_folder_settings(self, new_folder_path: str, folder_widget: QWidget):
        folder_widget = cast(FolderWidget, folder_widget)
        SETTINGS.change_download_folder_path(folder_widget.index, new_folder_path)
        folder_widget.folder_path = new_folder_path
        folder_widget.folder_label.setText(new_folder_path)
        set_minimum_size_policy(folder_widget.folder_label)
        folder_widget.folder_label.update()

    def remove_from_folder_settings(self, folder_widget: QWidget):
        folder_widget = cast(FolderWidget, folder_widget)
        SETTINGS.pop_download_folder_path(folder_widget.index)
        folder_widget.deleteLater()
        self.update_widget_indices()

    def add_folder_to_settings(self):
        added_folder_path = QFileDialog.getExistingDirectory(
            self.main_window, "Choose folder"
        )
        added_folder_path = fix_qt_path_for_windows(added_folder_path)
        if not self.is_valid_new_folder(added_folder_path):
            return
        SETTINGS.add_download_folder_path(added_folder_path)
        self.folder_widgets_layout.addWidget(
            FolderWidget(
                self.main_window,
                self,
                14,
                added_folder_path,
                self.folder_widgets_layout.count(),
            ),
            alignment=Qt.AlignmentFlag.AlignTop,
        )


class DownloadFoldersSetting(FolderSetting):
    def __init__(self, settings_window: SettingsWindow, main_window: MainWindow):
        super().__init__(
            settings_window,
            main_window,
            "Download folders",
            "Senpwai will search these folders for anime episodes, in the order shown",
        )

    def remove_from_folder_settings(self, download_folder_widget: QWidget):
        if len(SETTINGS.download_folder_paths) == 1:
            return self.error("Yarou!!! You must have at least one download folder")
        return super().remove_from_folder_settings(download_folder_widget)


class FolderWidget(QWidget):
    def __init__(
        self,
        main_window: MainWindow,
        folder_setting: FolderSetting,
        font_size: int,
        folder_path: str,
        index: int,
    ):
        super().__init__()
        self.main_window = main_window
        self.folder_path = folder_path
        self.folder_setting = folder_setting
        self.index = index
        main_layout = QHBoxLayout()
        self.folder_label = StyledLabel(font_size=font_size)
        self.folder_label.setText(folder_path)
        set_minimum_size_policy(self.folder_label)
        self.change_button = StyledButton(
            self,
            font_size,
            "white",
            PAHE_NORMAL_COLOR,
            PAHE_HOVER_COLOR,
            PAHE_PRESSED_COLOR,
        )
        self.change_button.clicked.connect(self.change_folder)
        self.change_button.setText("CHANGE")
        set_minimum_size_policy(self.change_button)
        remove_button = StyledButton(
            self,
            font_size,
            "white",
            RED_NORMAL_COLOR,
            RED_HOVER_COLOR,
            RED_PRESSED_COLOR,
        )
        remove_button.setText("REMOVE")
        remove_button.clicked.connect(
            lambda: self.folder_setting.remove_from_folder_settings(self)
        )
        set_minimum_size_policy(remove_button)
        main_layout.addWidget(self.folder_label)
        main_layout.addWidget(self.change_button)
        main_layout.addWidget(remove_button)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(main_layout)

    def change_folder(self):
        new_folder_path = QFileDialog.getExistingDirectory(
            self.main_window, "Choose folder"
        )
        new_folder_path = fix_qt_path_for_windows(new_folder_path)
        if self.folder_setting.is_valid_new_folder(new_folder_path):
            self.folder_setting.change_from_folder_settings(new_folder_path, self)


class YesOrNoButton(OptionButton):
    def __init__(self, yes_or_no: bool, font_size):
        super().__init__(
            None,
            yes_or_no,
            "YES" if yes_or_no else "NO",
            font_size,
            PAHE_NORMAL_COLOR,
            PAHE_PRESSED_COLOR,
        )


class SettingWidget(QWidget):
    def __init__(
        self,
        settings_window: SettingsWindow,
        setting_info: str,
        widgets_to_add: list,
        horizontal_layout=True,
        all_on_one_line=False,
    ):
        super().__init__()
        self.setting_label = StyledLabel(font_size=settings_window.font_size + 5)
        self.setting_label.setText(setting_info)
        set_minimum_size_policy(self.setting_label)
        if horizontal_layout:
            main_layout = QHBoxLayout()
        else:
            main_layout = QVBoxLayout()
        main_layout.addWidget(self.setting_label)
        for button in widgets_to_add:
            main_layout.addWidget(button)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(main_layout)


class RemovableWidget(QWidget):
    def __init__(self, text: str, font_size: int = 20):
        super().__init__()
        main_layout = QHBoxLayout()
        self.text = text
        label = StyledLabel(self, font_size)
        label.setText(text)
        self.remove_button = StyledButton(
            self,
            font_size,
            "white",
            RED_NORMAL_COLOR,
            RED_HOVER_COLOR,
            RED_PRESSED_COLOR,
        )
        self.remove_button.setText("REMOVE")
        self.remove_button.clicked.connect(self.deleteLater)
        set_minimum_size_policy(self.remove_button)
        main_layout.addWidget(label)
        main_layout.addWidget(self.remove_button)
        self.setLayout(main_layout)


class TrackedAnimeListSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        self.main_layout = QVBoxLayout()
        self.settings_window = settings_window
        main_widget = ScrollableSection(self.main_layout)
        self.anime_buttons: list[RemovableWidget] = []
        for anime in SETTINGS.tracked_anime:
            wid = RemovableWidget(anime, font_size=14)
            self.setup_anime_widget(wid)
        line = HorizontalLine()
        line.setFixedHeight(7)
        super().__init__(
            settings_window,
            "Track for new episodes then auto download",
            [line, main_widget],
            False,
        )
        self.setting_label.setToolTip(
            "When you start the app, Senpwai will check for new episodes\nof these anime then download them automatically"
        )

    def setup_anime_widget(self, wid: RemovableWidget):
        wid.remove_button.clicked.connect(
            lambda garbage_bool, txt=wid.text: SETTINGS.remove_tracked_anime(txt)
        )
        wid.remove_button.clicked.connect(lambda: self.anime_buttons.remove(wid))
        set_minimum_size_policy(wid)
        self.main_layout.addWidget(wid, alignment=Qt.AlignmentFlag.AlignTop)
        self.anime_buttons.append(wid)

    def remove_anime(self, title: str):
        for anime in self.anime_buttons:
            if anime.text == title:
                return anime.remove_button.click()

    def add_anime(self, title: str):
        for anime in self.anime_buttons:
            if anime.text == title:
                return
        wid = RemovableWidget(title, 16)
        self.setup_anime_widget(wid)
        SETTINGS.add_tracked_anime(title)


class AutoDownloadSite(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        self.font_size = settings_window.font_size
        pahe_button = OptionButton(
            None, PAHE, "PAHE", self.font_size, PAHE_NORMAL_COLOR, PAHE_PRESSED_COLOR
        )
        gogo_button = OptionButton(
            None, GOGO, "GOGO", self.font_size, GOGO_NORMAL_COLOR, GOGO_PRESSED_COLOR
        )
        pahe_button.clicked.connect(lambda: gogo_button.set_picked_status(False))
        pahe_button.clicked.connect(
            lambda: SETTINGS.update_auto_download_site(cast(str, pahe_button.option))
        )
        gogo_button.clicked.connect(lambda: pahe_button.set_picked_status(False))
        gogo_button.clicked.connect(
            lambda: SETTINGS.update_auto_download_site(cast(str, gogo_button.option))
        )
        if SETTINGS.auto_download_site == PAHE:
            pahe_button.set_picked_status(True)
        else:
            gogo_button.set_picked_status(True)

        super().__init__(
            settings_window, "Auto download site", [pahe_button, gogo_button]
        )
        self.setting_label.setToolTip(
            "If Senpwai can't find the anime in the specified site it will try the other"
        )


class YesOrNoSetting(SettingWidget):
    def __init__(
        self,
        settings_window: SettingsWindow,
        setting_info: str,
        tooltip: str | None = None,
    ):
        self.yes_button = YesOrNoButton(True, settings_window.font_size)
        self.no_button = YesOrNoButton(False, settings_window.font_size)
        self.yes_button.clicked.connect(lambda: self.no_button.set_picked_status(False))
        self.no_button.clicked.connect(lambda: self.yes_button.set_picked_status(False))
        set_minimum_size_policy(self.yes_button)
        set_minimum_size_policy(self.no_button)
        super().__init__(
            settings_window, setting_info, [self.yes_button, self.no_button]
        )

        if tooltip:
            self.setting_label.setToolTip(tooltip)


class GogoSkipCalculate(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Skip calculating download size for Gogo")
        if SETTINGS.gogo_skip_calculate:
            self.yes_button.set_picked_status(True)
        else:
            self.no_button.set_picked_status(True)
        self.yes_button.clicked.connect(
            lambda: SETTINGS.update_gogo_skip_calculate(True)
        )
        self.no_button.clicked.connect(
            lambda: SETTINGS.update_gogo_skip_calculate(False)
        )


class StartInFullscreenSetting(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Start app in fullscreen")
        if SETTINGS.start_in_fullscreen:
            self.yes_button.set_picked_status(True)
        else:
            self.no_button.set_picked_status(True)
        self.yes_button.clicked.connect(
            lambda: SETTINGS.update_start_in_fullscreen(True)
        )
        self.no_button.clicked.connect(
            lambda: SETTINGS.update_start_in_fullscreen(False)
        )


class RunOnStartUp(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Run on start up")
        appdata_folder = cast(str, os.environ.get("APPDATA"))
        self.lnk_path = os.path.join(
            appdata_folder,
            "Microsoft",
            "Windows",
            "Start Menu",
            "Programs",
            "Startup",
            f"{APP_NAME}.lnk",
        )
        if SETTINGS.run_on_startup:
            self.yes_button.set_picked_status(True)
        else:
            self.no_button.set_picked_status(True)
        self.yes_button.clicked.connect(lambda: SETTINGS.update_run_on_startup(True))
        self.yes_button.clicked.connect(self.make_startup_lnk)
        self.no_button.clicked.connect(lambda: SETTINGS.update_run_on_startup(False))
        self.no_button.clicked.connect(self.remove_startup_lnk)

    def make_startup_lnk(self):
        self.remove_startup_lnk()
        lnk = pylnk3_for_file(
            os.path.join(SRC_DIRECTORY, f"{APP_NAME}.exe"),
            APP_NAME,
            MINIMISED_TO_TRAY_ARG,
            "Senpwai startup shortcut",
            work_dir=os.path.abspath("."),
        )
        lnk.save(self.lnk_path)
        # pylnk3 seems to generate a garbage lnk file with no extension in the current directory
        garbage_lnk = APP_NAME
        if os.path.isfile(garbage_lnk):
            os.unlink(garbage_lnk)

    def remove_startup_lnk(self):
        if os.path.isfile(self.lnk_path):
            try_deleting_safely(self.lnk_path)


class AllowNotificationsSetting(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Allow notifications uWu?")
        if SETTINGS.allow_notifications:
            self.yes_button.set_picked_status(True)
        else:
            self.no_button.set_picked_status(True)
        self.yes_button.clicked.connect(
            lambda: SETTINGS.update_allow_notifications(True)
        )
        self.no_button.clicked.connect(
            lambda: SETTINGS.update_allow_notifications(False)
        )


class GogoNormOrHlsSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        norm_button = GogoNormOrHlsButton(
            settings_window, GOGO_NORM_MODE, settings_window.font_size
        )
        set_minimum_size_policy(norm_button)
        hls_button = GogoNormOrHlsButton(
            settings_window, GOGO_HLS_MODE, settings_window.font_size
        )
        set_minimum_size_policy(hls_button)
        if SETTINGS.gogo_norm_or_hls_mode == GOGO_HLS_MODE:
            hls_button.set_picked_status(True)
        else:
            norm_button.set_picked_status(True)
        norm_button.clicked.connect(lambda: hls_button.set_picked_status(False))
        hls_button.clicked.connect(lambda: norm_button.set_picked_status(False))
        norm_button.clicked.connect(
            lambda: SETTINGS.update_gogo_norm_or_hls_mode(GOGO_NORM_MODE)
        )
        hls_button.clicked.connect(
            lambda: SETTINGS.update_gogo_norm_or_hls_mode(GOGO_HLS_MODE)
        )
        super().__init__(
            settings_window, "Gogo Normal or HLS mode", [norm_button, hls_button]
        )
        self.setting_label.setToolTip(hls_button.toolTip())


class NonZeroNumberInputSetting(SettingWidget):
    def __init__(
        self,
        settings_window: SettingsWindow,
        initial_value: int,
        setting_updater_callback: Callable[[int], None],
        setting_info: str,
        error_on_zero_text: str,
        units: str | None,
        tooltip: str | None = None,
    ):
        self.settings_window = settings_window
        self.setting_updater_callback = setting_updater_callback
        self.number_input = NumberInput(font_size=settings_window.font_size)
        self.number_input.setFixedWidth(60)
        self.number_input.setPlaceholderText(AMOGUS_EASTER_EGG)
        self.number_input.setText(str(initial_value))
        self.input_layout = QHBoxLayout()
        input_widget = QWidget()
        input_widget.setLayout(self.input_layout)
        self.input_layout.addWidget(
            self.number_input, alignment=Qt.AlignmentFlag.AlignLeft
        )
        if units:
            units_label = StyledLabel(None, settings_window.font_size)
            units_label.setText(units)
            set_minimum_size_policy(units_label)
            self.input_layout.addWidget(
                units_label, alignment=Qt.AlignmentFlag.AlignLeft
            )
        else:
            # just to avoid type errors
            units_label = None
        main_layout = QVBoxLayout()
        self.error = ErrorLabel(settings_window.font_size)
        self.error.setText(error_on_zero_text)
        set_minimum_size_policy(self.error)
        self.error.hide()

        main_widget = QWidget()
        main_widget.setLayout(main_layout)
        main_layout.addWidget(self.error)
        main_layout.addWidget(input_widget)
        super().__init__(settings_window, setting_info, [main_widget])
        self.number_input.textChanged.connect(self.text_changed)
        if tooltip:
            self.setting_label.setToolTip(tooltip)
            if units:
                cast(StyledLabel, units_label).setToolTip(tooltip)

    def text_changed(self, text: str):
        if not text.isdigit():
            return
        new_setting = int(text)
        if new_setting == 0:
            self.error.show()
            self.number_input.setText("")
            return
        self.setting_updater_callback(new_setting)


class MaxSimultaneousDownloadsSetting(NonZeroNumberInputSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(
            settings_window,
            SETTINGS.max_simultaneous_downloads,
            SETTINGS.update_max_simultaneous_downloads,
            "Only allow",
            "Bruh, max simultaneous downloads cannot be zero",
            "simultaneous downloads",
            "The maximum number of downloads allowed to occur at the same time",
        )


class CheckForNewEpsAfterSetting(NonZeroNumberInputSetting):
    def __init__(
        self, settings_window: SettingsWindow, download_window: DownloadWindow
    ):
        self.download_window = download_window
        super().__init__(
            settings_window,
            SETTINGS.check_for_new_eps_after,
            SETTINGS.update_check_for_new_eps_after,
            "Check for new episodes after",
            "Bruh, time intervals can't be zero",
            "hours",
            "Senpwai will check for new episodes of your tracked anime when you start the app\nthen in intervals of the hours you specify so long as it is running",
        )

    def text_changed(self, text: str):
        super().text_changed(text)
        self.download_window.setup_auto_download_timer()
        self.download_window.start_auto_download()


class QualitySetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        font_size = settings_window.font_size
        self.settings_window = settings_window
        button_1080 = QualityButton(settings_window, Q_1080, font_size)
        button_720 = QualityButton(settings_window, Q_720, font_size)
        button_480 = QualityButton(settings_window, Q_480, font_size)
        button_360 = QualityButton(settings_window, Q_360, font_size)
        self.quality_buttons_list = [button_1080, button_720, button_480, button_360]
        for button in self.quality_buttons_list:
            set_minimum_size_policy(button)
            quality = button.quality
            button.clicked.connect(
                lambda garbage_bool, quality=quality: self.update_quality(quality)
            )
            if button.quality == SETTINGS.quality:
                button.set_picked_status(True)
        super().__init__(settings_window, "Download quality", self.quality_buttons_list)

    def update_quality(self, quality: str):
        SETTINGS.update_quality(quality)
        for button in self.quality_buttons_list:
            if button.quality != quality:
                button.set_picked_status(False)


class SubDubSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        sub_button = SubDubButton(settings_window, SUB, settings_window.font_size)
        set_minimum_size_policy(sub_button)
        dub_button = SubDubButton(settings_window, DUB, settings_window.font_size)
        set_minimum_size_policy(dub_button)
        if SETTINGS.sub_or_dub == SUB:
            sub_button.set_picked_status(True)
        else:
            dub_button.set_picked_status(True)
        sub_button.clicked.connect(lambda: dub_button.set_picked_status(False))
        dub_button.clicked.connect(lambda: sub_button.set_picked_status(False))
        sub_button.clicked.connect(lambda: SETTINGS.update_sub_or_dub(SUB))
        dub_button.clicked.connect(lambda: SETTINGS.update_sub_or_dub(DUB))
        super().__init__(settings_window, "Sub or Dub", [sub_button, dub_button])
