from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QFileDialog
from PyQt6.QtCore import Qt, QFile
from shared.global_vars_and_funcs import SETTINGS_TYPES, validate_settings_json, settings_file_path, fix_qt_path_for_windows, set_minimum_size_policy, amogus_easter_egg, requires_admin_access, settings_window_bckg_image_path, GOGO_NORMAL_COLOR
from shared.global_vars_and_funcs import settings, KEY_GOGO_DEFAULT_BROWSER, KEY_ALLOW_NOTIFICATIONS, KEY_QUALITY, KEY_MAX_SIMULTANEOUS_DOWNLOADS, KEY_SUB_OR_DUB, KEY_DOWNLOAD_FOLDER_PATHS, KEY_START_IN_FULLSCREEN, KEY_GOGO_NORM_OR_HLS_MODE, KEY_TRACKED_ANIME, KEY_AUTO_DOWNLOAD_SITE, KEY_START_MINIMISED, KEY_RUN_ON_STARTUP, KEY_ON_CAPTCHA_SWITCH_TO
from shared.global_vars_and_funcs import PAHE_NORMAL_COLOR, PAHE_PRESSED_COLOR, PAHE_HOVER_COLOR, RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR, SUB, DUB, CHROME, EDGE, FIREFOX, Q_1080, Q_720, Q_480, Q_360, GOGO_NORM_MODE, GOGO_HLS_MODE, GOGO_PRESSED_COLOR, PAHE, GOGO, APP_NAME
from shared.shared_classes_and_widgets import ScrollableSection, StyledLabel, OptionButton, SubDubButton, NumberInput, GogoBrowserButton, GogoNormOrHlsButton, QualityButton, StyledButton, ErrorLabel, HorizontalLine
from windows.main_actual_window import MainWindow, Window
from sys import platform as sysplatform
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
        self.make_download_complete_notification_setting = AllowNotificationsSetting(
            self)
        self.start_in_fullscreen = StartInFullscreenSetting(self)
        self.download_folder_setting = DownloadFoldersSetting(
            self, main_window)
        self.gogo_norm_or_hls_mode_setting = GogoNormOrHlsSetting(self)
        self.tracked_anime = TrackedAnime(self,)
        self.auto_download_site = AutoDownloadSite(self)
        self.start_minimsed = StartMinimisedSetting(self)
        if sysplatform == "win32":
            self.run_on_startup = RunOnStartUp(self)
        self.oncaptcha_switch_to = OnCaptchaSwitchToSetting(self)
        left_layout.addWidget(self.sub_dub_setting)
        left_layout.addWidget(self.quality_setting)
        left_layout.addWidget(self.max_simultaneous_downloads_setting)
        left_layout.addWidget(self.gogo_default_browser_setting)
        left_layout.addWidget(self.gogo_norm_or_hls_mode_setting)
        left_layout.addWidget(self.oncaptcha_switch_to)
        left_layout.addWidget(
            self.make_download_complete_notification_setting)
        left_layout.addWidget(self.start_in_fullscreen)
        left_layout.addWidget(self.start_minimsed)
        if sysplatform == "win32":
            left_layout.addWidget(self.run_on_startup)
        right_layout.addWidget(self.download_folder_setting)
        right_layout.addWidget(self.auto_download_site)
        right_layout.addWidget(self.tracked_anime)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)

    def update_settings_json(self, key: str, new_value: SETTINGS_TYPES):
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
                                  "green", GOGO_NORMAL_COLOR, GOGO_PRESSED_COLOR)
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
        line = HorizontalLine()
        line.setFixedHeight(7)
        self.main_layout.addWidget(line)
        self.folder_widgets_layout = QVBoxLayout()
        for idx, folder in enumerate(cast(list[str], settings[self.setting_key])):
            self.folder_widgets_layout.addWidget(FolderWidget(
                main_window, self, 14, folder, idx), alignment=Qt.AlignmentFlag.AlignTop)
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
            self.main_window, self, 14, added_folder_path, self.folder_widgets_layout.count()), alignment=Qt.AlignmentFlag.AlignTop)
        self.settings_window.update_settings_json(
            self.setting_key, cast(list[str], settings[self.setting_key]) + [added_folder_path])


class DownloadFoldersSetting(FolderSetting):
    def __init__(self, settings_window: SettingsWindow, main_window: MainWindow):
        super().__init__(settings_window, main_window, "Download folders", KEY_DOWNLOAD_FOLDER_PATHS,
                         "Senpwai will search these folders for anime episodes, in the order shown")

    def remove_from_folder_settings(self, download_folder_widget: QWidget):
        if len(cast(list[str], settings[KEY_DOWNLOAD_FOLDER_PATHS])) - 1 <= 0:
            return self.error("Yarou!!! You must have at least one download folder")
        return super().remove_from_folder_settings(download_folder_widget)


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
    def __init__(self, settings_window: SettingsWindow, setting_info: str, widgets_to_add: list, horizintal_layout=True):
        super().__init__()
        self.setting_label = StyledLabel(font_size=settings_window.font_size+5)
        self.setting_label.setText(setting_info)
        set_minimum_size_policy(self.setting_label)
        if horizintal_layout:
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
            self, font_size, "white", RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR)
        self.remove_button.setText("REMOVE")
        self.remove_button.clicked.connect(self.deleteLater)
        set_minimum_size_policy(self.remove_button)
        main_layout.addWidget(label)
        main_layout.addWidget(self.remove_button)
        self.setLayout(main_layout)


class TrackedAnime(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        self.main_layout = QVBoxLayout()
        self.settings_window = settings_window
        main_widget = ScrollableSection(self.main_layout)
        self.anime_buttons: list[RemovableWidget] = []
        for anime in cast(list[str], settings[KEY_TRACKED_ANIME]):
            wid = RemovableWidget(anime, font_size=14)
            self.setup_anime_widget(wid)
        line = HorizontalLine()
        line.setFixedHeight(7)
        super().__init__(settings_window,
                         "Anime to track and auto download new episodes", [line, main_widget], False)
        self.setting_label.setToolTip("When you start the app, Senpwai will check for new episodes\nof these anime then download them automatically")

    def setup_anime_widget(self, wid: RemovableWidget):
        wid.remove_button.clicked.connect(lambda garbage_bool, txt=wid.text: cast(
            list[str], settings[KEY_TRACKED_ANIME]).remove(txt))
        wid.remove_button.clicked.connect(lambda: self.settings_window.update_settings_json(
            KEY_TRACKED_ANIME, settings[KEY_TRACKED_ANIME]))
        wid.remove_button.clicked.connect(
            lambda: self.anime_buttons.remove(wid))
        set_minimum_size_policy(wid)
        self.main_layout.addWidget(wid, alignment=Qt.AlignmentFlag.AlignTop)
        self.anime_buttons.append(wid)

    def remove_anime(self, title: str):
        for anime in self.anime_buttons:
            if anime.text == title:
                anime.remove_button.click()

    def add_anime(self, title: str):
        for anime in self.anime_buttons:
            if anime.text == title:
                return
        wid = RemovableWidget(title, 16)
        self.setup_anime_widget(wid)
        new_setting = cast(
            list[str], settings[KEY_TRACKED_ANIME]) + [title]
        self.settings_window.update_settings_json(
            KEY_TRACKED_ANIME, new_setting)


class AutoDownloadSite(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        self.font_size = settings_window.font_size
        pahe_button = OptionButton(
            None, PAHE, "PAHE", self.font_size, PAHE_NORMAL_COLOR, PAHE_PRESSED_COLOR)
        gogo_button = OptionButton(
            None, GOGO, "GOGO", self.font_size, GOGO_NORMAL_COLOR, GOGO_PRESSED_COLOR)
        pahe_button.clicked.connect(
            lambda: gogo_button.set_picked_status(False))
        pahe_button.clicked.connect(lambda: settings_window.update_settings_json(
            KEY_AUTO_DOWNLOAD_SITE, pahe_button.option))
        gogo_button.clicked.connect(
            lambda: pahe_button.set_picked_status(False))
        gogo_button.clicked.connect(lambda: settings_window.update_settings_json(
            KEY_AUTO_DOWNLOAD_SITE, gogo_button.option))
        if settings[KEY_AUTO_DOWNLOAD_SITE] == PAHE:
            pahe_button.set_picked_status(True)
        else:
            gogo_button.set_picked_status(True)

        super().__init__(settings_window,
                         "Auto download site", [pahe_button, gogo_button])
        self.setting_label.setToolTip("If Senpwai can't find the anime in the specified site it will try the other")

class YesOrNoSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow, setting_info: str, setting_key_in_json: str, tooltip: str | None = None):
        self.yes_button = YesOrNoButton(True, settings_window.font_size)
        self.no_button = YesOrNoButton(False, settings_window.font_size)
        self.yes_button.clicked.connect(lambda: self.no_button.set_picked_status(False))
        self.no_button.clicked.connect(lambda: self.yes_button.set_picked_status(False))
        self.yes_button.clicked.connect(lambda: settings_window.update_settings_json(
            setting_key_in_json, True))
        self.no_button.clicked.connect(lambda: settings_window.update_settings_json(
            setting_key_in_json, False))
        self.yes_button.set_picked_status(
            True) if settings[setting_key_in_json] else self.no_button.set_picked_status(True)
        set_minimum_size_policy(self.yes_button)
        set_minimum_size_policy(self.no_button)
        super().__init__(settings_window,
                         setting_info, [self.yes_button, self.no_button])

        if tooltip:
            self.setting_label.setToolTip(tooltip)


class StartInFullscreenSetting(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Start app in fullscreen?", KEY_START_IN_FULLSCREEN)

class StartMinimisedSetting(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Start app minimised to tray?", KEY_START_MINIMISED)
        if sysplatform == "win32":
            return self.setting_label.setToolTip("You can combo this setting with Run on start up such that every day you start your PC\nSenpwai will look for new episodes of your tracked anime in the background")
        self.setting_label.setToolTip("You can combine this setting with making Senpwai to run on start up such that every day\nyou start your PC Senpwai will look for new episodes of your tracked anime in the background")

class RunOnStartUp(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Run on start up?", KEY_RUN_ON_STARTUP)
        appdata_folder = cast(str, os.environ.get('APPDATA'))
        self.lnk_name = f"{APP_NAME}.lnk"
        self.lnk_path = os.path.join(appdata_folder, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup', self.lnk_name)
        self.yes_button.clicked.connect(self.make_startup_lnk)
        self.no_button.clicked.connect(self.remove_startup_lnk)

    def make_startup_lnk(self):
        if not os.path.isfile(self.lnk_path):
            QFile.link(f"{APP_NAME}.exe", self.lnk_name)
            QFile.copy(self.lnk_name, self.lnk_path)

    def remove_startup_lnk(self):
        if os.path.isfile(self.lnk_path):
            os.unlink(self.lnk_path)

class AllowNotificationsSetting(YesOrNoSetting):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__(settings_window, "Allow notifications uWu?",
                         KEY_ALLOW_NOTIFICATIONS)


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
            "The selected browser will be used for scraping if you download from Gogoanime in Normal mode")

    def update_browser(self, browser: str):
        self.settings_window.update_settings_json(
            KEY_GOGO_DEFAULT_BROWSER, browser)
        for button in self.browser_buttons_list:
            if button.browser != browser:
                button.set_picked_status(False)

class OnCaptchaSwitchToSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        pahe_button = OptionButton(None, PAHE, "PAHE", settings_window.font_size, PAHE_NORMAL_COLOR, PAHE_HOVER_COLOR)
        hls_button = OptionButton(None, GOGO_HLS_MODE, "HLS", settings_window.font_size, RED_NORMAL_COLOR, RED_HOVER_COLOR)
        pahe_button.clicked.connect(lambda: hls_button.set_picked_status(False))
        pahe_button.clicked.connect(lambda: settings_window.update_settings_json(KEY_ON_CAPTCHA_SWITCH_TO, pahe_button.option))
        hls_button.clicked.connect(lambda: pahe_button.set_picked_status(False))
        hls_button.clicked.connect(lambda: settings_window.update_settings_json(KEY_ON_CAPTCHA_SWITCH_TO, hls_button.option))
        if settings[KEY_ON_CAPTCHA_SWITCH_TO] == PAHE:
            pahe_button.set_picked_status(True)
        else:
            hls_button.set_picked_status(True)
        super().__init__(settings_window, "On Captcha block switch to", [pahe_button, hls_button])

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
        hls_button.clicked.connect(
            lambda: norm_button.set_picked_status(False))
        norm_button.clicked.connect(
            lambda: settings_window.update_settings_json(KEY_GOGO_NORM_OR_HLS_MODE, GOGO_NORM_MODE))
        hls_button.clicked.connect(
            lambda: settings_window.update_settings_json(KEY_GOGO_NORM_OR_HLS_MODE, GOGO_HLS_MODE))
        super().__init__(settings_window,
                         "Gogo Normal or HLS mode?", [norm_button, hls_button])
        self.setting_label.setToolTip(hls_button.toolTip())


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
        zero_error.setText("Bruh, max simultaneous downloads can't be zero")
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
            "The maximum number of downloads allowed to occur at the same time")

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
