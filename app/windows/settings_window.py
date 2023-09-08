from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QFileDialog
from PyQt6.QtCore import Qt
from shared.global_vars_and_funcs import ALLOWED_SETTINGS_TYPES, validate_settings_json, settings_file_path, fix_qt_path_for_windows, set_minimum_size_policy, amogus_easter_egg, requires_admin_access, settings_window_bckg_image_path, GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR
from shared.global_vars_and_funcs import settings, KEY_GOGO_DEFAULT_BROWSER, KEY_MAKE_DOWNLOAD_COMPLETE_NOTIFICATION, KEY_QUALITY, KEY_MAX_SIMULTANEOUS_DOWNLOADS, KEY_SUB_OR_DUB, KEY_DOWNLOAD_FOLDER_PATHS, KEY_START_IN_FULLSCREEN, KEY_GOGO_NORM_OR_HLS_MODE, KEY_AUTO_DOWNLOAD_FOLDERS
from shared.global_vars_and_funcs import PAHE_NORMAL_COLOR, PAHE_PRESSED_COLOR, PAHE_HOVER_COLOR, RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR, SUB, DUB, CHROME, EDGE, FIREFOX, Q_1080, Q_720, Q_480, Q_360, GOGO_NORM_MODE, GOGO_HLS_MODE, GOGO_PRESSED_COLOR
from shared.shared_classes_and_widgets import ScrollableSection, StyledLabel, OptionButton, SubDubButton, NumberInput, GogoBrowserButton, GogoNormOrHlsButton, QualityButton, StyledButton, ErrorLabel, HorizontalLine
from windows.main_actual_window import MainWindow, Window
import json
import os
from typing import cast


class SettingsWindow(Window):
    def __init__(self, main_window: MainWindow) -> None:
        super().__init__(main_window, settings_window_bckg_image_path)
        self.font_size = 18
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
        self.max_simultaneous_downloads_setting = MaxSimultaneousDownloadsSetting(
            self)
        self.gogo_default_browser_setting = GogoDefaultBrowserSetting(self)
        self.make_download_complete_notification_setting = MakeDownloadCompleteNotificationSetting(
            self)
        self.start_in_fullscreen = StartInFullscreenSetting(self)
        self.download_folder_setting = DownloadFoldersSetting(
            self, main_window)
        self.gogo_norm_or_hls_mode_setting = GogoNormOrHlsSetting(self)
        self.auto_download_folders = AutoDownloadFoldersSetting(self, main_window)
        left_layout.addWidget(self.sub_dub_setting)
        left_layout.addWidget(self.quality_setting)
        left_layout.addWidget(self.max_simultaneous_downloads_setting)
        left_layout.addWidget(self.gogo_default_browser_setting)
        left_layout.addWidget(self.gogo_norm_or_hls_mode_setting)
        left_layout.addWidget(
            self.make_download_complete_notification_setting)
        left_layout.addWidget(self.start_in_fullscreen)
        right_layout.addWidget(self.download_folder_setting)
        right_layout.addWidget(self.auto_download_folders)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)

    def update_settings_json(self, key: str, new_value: ALLOWED_SETTINGS_TYPES):
        settings[key] = new_value
        validated = validate_settings_json(settings)
        with open(settings_file_path, "w") as f:
            json.dump(validated, f, indent=4)


class FolderSetting(QWidget):
    def __init__(self, settings_window: SettingsWindow, main_window: MainWindow, setting_info: str, setting_key: str, setting_tool_tip: str | None):
        super().__init__()
        self.settings_window = settings_window
        self.font_size = settings_window.font_size
        self.main_window = main_window
        self.main_layout = QVBoxLayout()
        self.setting_key = setting_key
        settings_label = StyledLabel(font_size=self.font_size+5)
        settings_label.setText(setting_info)
        if setting_tool_tip:
            settings_label.setToolTip(setting_tool_tip)
        set_minimum_size_policy(settings_label)
        self.error_label = ErrorLabel(18, 6)
        self.error_label.hide()
        add_button = StyledButton(self, self.font_size, "white",
                                  GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
        add_button.clicked.connect(self.add_folder_to_settings)
        add_button.setText("ADD")
        set_minimum_size_policy(add_button)
        settings_label_and_add_button_widget = QWidget()
        settings_label_and_add_button_layout = QHBoxLayout()
        settings_label_and_add_button_layout.addWidget(settings_label)
        settings_label_and_add_button_layout.addWidget(add_button)
        settings_label_and_add_button_layout.setAlignment(
            Qt.AlignmentFlag.AlignLeft)
        settings_label_and_add_button_widget.setLayout(
            settings_label_and_add_button_layout)
        self.main_layout.addWidget(self.error_label)
        self.main_layout.addWidget(settings_label_and_add_button_widget)
        self.folder_widgets_layout = QVBoxLayout()
        for idx, folder in enumerate(cast(list[str], settings[self.setting_key])):
            self.folder_widgets_layout.addWidget(FolderWidget(
                main_window, self, self.font_size - 5, folder, idx), alignment=Qt.AlignmentFlag.AlignTop)
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
            self.error(
                "The folder you chose requires admin access so i've ignored it")
            return False
        elif not os.path.isdir(new_folder_path):
            self.error("Choose a valid folder, onegaishimasu")
            return False
        elif new_folder_path in cast(list[str], settings[self.setting_key]):
            self.error("Baka!!! that folder is already in the settings")
            return False
        else:
            return True

    def update_widget_indices(self):
        for idx in range(self.folder_widgets_layout.count()):

            cast(FolderWidget, self.folder_widgets_layout.itemAt(
                idx).widget()).index = idx

    def change_from_folder_settings(self, new_folder_path: str, folder_widget: QWidget):
        folder_widget = cast(
            FolderWidget, folder_widget)
        new_folders_settings = cast(list, settings[self.setting_key])
        new_folders_settings[folder_widget.index] = new_folder_path
        folder_widget.folder_path = new_folder_path
        folder_widget.folder_label.setText(new_folder_path)
        set_minimum_size_policy(folder_widget.folder_label)
        folder_widget.folder_label.update()
        self.settings_window.update_settings_json(
            self.setting_key, new_folders_settings)

    def remove_from_folder_settings(self, folder_widget: QWidget):
        folder_widget = cast(
            FolderWidget, folder_widget)
        new_folders_settings = cast(list, settings[self.setting_key])
        new_folders_settings.pop(folder_widget.index)
        folder_widget.deleteLater()
        self.folder_widgets_layout.removeWidget(folder_widget)
        self.settings_window.update_settings_json(
            self.setting_key, new_folders_settings)
        self.update_widget_indices()

    def add_folder_to_settings(self):
        added_folder_path = QFileDialog.getExistingDirectory(
            self.main_window, "Choose folder")
        added_folder_path = fix_qt_path_for_windows(added_folder_path)
        if not self.is_valid_new_folder(added_folder_path):
            return
        self.folder_widgets_layout.addWidget(FolderWidget(
            self.main_window, self, self.font_size - 5, added_folder_path, self.folder_widgets_layout.count()), alignment=Qt.AlignmentFlag.AlignTop)
        self.settings_window.update_settings_json(
            self.setting_key, cast(list[str], settings[self.setting_key]) + [added_folder_path])


class DownloadFoldersSetting(FolderSetting):
    def __init__(self, settings_window: SettingsWindow, main_window: MainWindow):
        super().__init__(settings_window, main_window, "Download folders", KEY_DOWNLOAD_FOLDER_PATHS, "Senpwai will search these folders for anime episodes, in the order shown")
    
    def remove_from_folder_settings(self, download_folder_widget: QWidget):
        if len(cast(list[str], settings[KEY_DOWNLOAD_FOLDER_PATHS])) - 1 <= 0:
            return self.error("Yarou!!! You must have at least one download folder")
        return super().remove_from_folder_settings(download_folder_widget)
    
class AutoDownloadFoldersSetting(FolderSetting):
    def __init__(self, settings_window: SettingsWindow, main_window: MainWindow):
        super().__init__(settings_window, main_window, "Auto download folders", KEY_AUTO_DOWNLOAD_FOLDERS, "Senpwai will check for new episodes of these anime when you start the app")

class FolderWidget(QWidget):
    def __init__(self, main_window: MainWindow, folder_setting: FolderSetting, font_size: int, folder_path: str, index: int):
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
            self, font_size, "white", PAHE_NORMAL_COLOR, PAHE_HOVER_COLOR, PAHE_PRESSED_COLOR)
        self.change_button.clicked.connect(self.change_folder)
        self.change_button.setText("CHANGE")
        set_minimum_size_policy(self.change_button)
        remove_button = StyledButton(
            self, font_size, "white", RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR)
        remove_button.setText("REMOVE")
        remove_button.clicked.connect(
            lambda: self.folder_setting.remove_from_folder_settings(self))
        set_minimum_size_policy(remove_button)
        main_layout.addWidget(self.folder_label)
        main_layout.addWidget(self.change_button)
        main_layout.addWidget(remove_button)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(main_layout)

    def change_folder(self):
        new_folder_path = QFileDialog.getExistingDirectory(
            self.main_window, "Choose folder")
        new_folder_path = fix_qt_path_for_windows(new_folder_path)
        if self.folder_setting.is_valid_new_folder(new_folder_path):
            self.folder_setting.change_from_folder_settings(
                new_folder_path, self)


class YesOrNoButton(OptionButton):
    def __init__(self, yes_or_no: bool, font_size):
        super().__init__(None, yes_or_no, "YES" if yes_or_no else "NO",
                         font_size, PAHE_NORMAL_COLOR, PAHE_PRESSED_COLOR)


class SettingWidget(QWidget):
    def __init__(self, settings_window: SettingsWindow, setting_info: str, widgets_to_add: list):
        super().__init__()
        self.setting_label = StyledLabel(font_size=settings_window.font_size+5)
        self.setting_label.setText(setting_info)
        set_minimum_size_policy(self.setting_label)
        main_layout = QHBoxLayout()
        main_layout.addWidget(self.setting_label)
        for button in widgets_to_add:
            main_layout.addWidget(button)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(main_layout)


class YesOrNoSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow, setting_info: str, setting_key_in_json: str, tooltip: str = ''):
        yes_button = YesOrNoButton(True, settings_window.font_size)
        no_button = YesOrNoButton(False, settings_window.font_size)
        yes_button.clicked.connect(lambda: no_button.set_picked_status(False))
        no_button.clicked.connect(lambda: yes_button.set_picked_status(False))
        yes_button.clicked.connect(lambda: settings_window.update_settings_json(
            setting_key_in_json, True))
        no_button.clicked.connect(lambda: settings_window.update_settings_json(
            setting_key_in_json, False))
        yes_button.set_picked_status(
            True) if settings[setting_key_in_json] else no_button.set_picked_status(True)
        set_minimum_size_policy(yes_button)
        set_minimum_size_policy(no_button)
        super().__init__(settings_window,
                         setting_info, [yes_button, no_button])

        if tooltip != '':
            self.setting_label.setToolTip(tooltip)


class StartInFullscreenSetting(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Start app in fullscreen?", KEY_START_IN_FULLSCREEN)


class MakeDownloadCompleteNotificationSetting(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Notify you when download completes uWu?",
                         KEY_MAKE_DOWNLOAD_COMPLETE_NOTIFICATION)


class GogoDefaultBrowserSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        font_size = settings_window.font_size
        self.settings_window = settings_window
        button_chrome = GogoBrowserButton(
            settings_window, CHROME, font_size)
        button_edge = GogoBrowserButton(settings_window, EDGE, font_size)
        button_firefox = GogoBrowserButton(
            settings_window, FIREFOX, font_size)
        self.browser_buttons_list = [
            button_chrome, button_edge, button_firefox]
        for button in self.browser_buttons_list:
            set_minimum_size_policy(button)
            browser = button.browser
            button.clicked.connect(
                lambda garbage_bool, browser=browser: self.update_browser(browser))
            if button.browser == cast(str, settings[KEY_GOGO_DEFAULT_BROWSER]):
                button.set_picked_status(True)
        super().__init__(settings_window,
                         "Gogo default scraping browser", self.browser_buttons_list)
        self.setting_label.setToolTip(
            "The selected browser will be used for scraping if you download from Gogoanime in Normal mode.")

    def update_browser(self, browser: str):
        self.settings_window.update_settings_json(
            KEY_GOGO_DEFAULT_BROWSER, browser)
        for button in self.browser_buttons_list:
            if button.browser != browser:
                button.set_picked_status(False)


class GogoNormOrHlsSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        norm_button = GogoNormOrHlsButton(
            settings_window, GOGO_NORM_MODE, settings_window.font_size)
        set_minimum_size_policy(norm_button)
        hls_button = GogoNormOrHlsButton(
            settings_window, GOGO_HLS_MODE, settings_window.font_size)
        set_minimum_size_policy(hls_button)
        if cast(str, settings[KEY_GOGO_NORM_OR_HLS_MODE]) == GOGO_HLS_MODE:
            hls_button.set_picked_status(True)
        else:
            norm_button.set_picked_status(True)
        norm_button.clicked.connect(
            lambda: hls_button.set_picked_status(False))
        norm_button.setToolTip(
            "In Normal mode you may occasionally encounter Captcha block.\nAlso you must have either Chrome, Edge or Firefox installed.")
        hls_info_text = "HLS mode guarantees Gogoanime downloads will go through, zettaini, but in order for it to work\nyou must have FFmpeg installed. Also, you can't pause ongoing downloads while in HLS mode"
        hls_button.clicked.connect(
            lambda: norm_button.set_picked_status(False))
        hls_button.setToolTip(hls_info_text)
        norm_button.clicked.connect(
            lambda: settings_window.update_settings_json(KEY_GOGO_NORM_OR_HLS_MODE, GOGO_NORM_MODE))
        hls_button.clicked.connect(
            lambda: settings_window.update_settings_json(KEY_GOGO_NORM_OR_HLS_MODE, GOGO_HLS_MODE))
        super().__init__(settings_window,
                         "Gogo Normal or HLS mode?", [norm_button, hls_button])
        self.setting_label.setToolTip(hls_info_text)


class MaxSimultaneousDownloadsSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        self.settings_window = settings_window
        number_input = NumberInput(font_size=settings_window.font_size)
        number_input.setFixedWidth(60)
        number_input.setPlaceholderText(amogus_easter_egg)
        number_input.setText(
            str(cast(int, settings[KEY_MAX_SIMULTANEOUS_DOWNLOADS])))
        number_input.textChanged.connect(self.text_changed)
        zero_error = ErrorLabel(18, 4)
        zero_error.setText("Bruh, max simultaneous downloads can't be zero.")
        set_minimum_size_policy(zero_error)
        zero_error.hide()
        main_layout = QVBoxLayout()
        main_layout.addWidget(zero_error)
        self.zero_error = zero_error.show
        main_layout.addWidget(number_input)
        main_widget = QWidget()
        main_widget.setLayout(main_layout)
        super().__init__(settings_window,
                         "Max simultaneous downloads", [main_widget])
        self.setting_label.setToolTip(
            "The maximum number of downloads allowed to occur at the same time.")

    def text_changed(self, text: str):
        if not text.isdigit():
            return
        new_setting = int(text)
        if new_setting == 0:
            self.zero_error()
            return
        self.settings_window.update_settings_json(
            KEY_MAX_SIMULTANEOUS_DOWNLOADS, new_setting)


class QualitySetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        font_size = settings_window.font_size
        self.settings_window = settings_window
        button_1080 = QualityButton(settings_window, Q_1080, font_size)
        button_720 = QualityButton(settings_window, Q_720, font_size)
        button_480 = QualityButton(settings_window, Q_480, font_size)
        button_360 = QualityButton(settings_window, Q_360, font_size)
        self.quality_buttons_list = [button_1080,
                                     button_720, button_480, button_360]
        for button in self.quality_buttons_list:
            set_minimum_size_policy(button)
            quality = button.quality
            button.clicked.connect(
                lambda garbage_bool, quality=quality: self.update_quality(quality))
            if button.quality == cast(str, settings[KEY_QUALITY]):
                button.set_picked_status(True)
        super().__init__(settings_window, "Download quality", self.quality_buttons_list)

    def update_quality(self, quality: str):
        self.settings_window.update_settings_json(KEY_QUALITY, quality)
        for button in self.quality_buttons_list:
            if button.quality != quality:
                button.set_picked_status(False)


class SubDubSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        sub_button = SubDubButton(
            settings_window, SUB, settings_window.font_size)
        set_minimum_size_policy(sub_button)
        dub_button = SubDubButton(
            settings_window, DUB, settings_window.font_size)
        set_minimum_size_policy(dub_button)
        if cast(str, settings[KEY_SUB_OR_DUB]) == SUB:
            sub_button.click()
        else:
            dub_button.click()
        sub_button.clicked.connect(lambda: dub_button.set_picked_status(False))
        dub_button.clicked.connect(lambda: sub_button.set_picked_status(False))
        sub_button.clicked.connect(
            lambda: settings_window.update_settings_json(KEY_SUB_OR_DUB, SUB))
        dub_button.clicked.connect(
            lambda: settings_window.update_settings_json(KEY_SUB_OR_DUB, DUB))
        super().__init__(settings_window,
                         "Sub or Dub?", [sub_button, dub_button])
