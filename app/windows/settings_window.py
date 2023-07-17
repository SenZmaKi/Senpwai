from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QMainWindow
from PyQt6.QtCore import Qt
from shared.global_vars_and_funcs import AllowedSettingsTypes, validate_settings_json, settings_file_path, set_minimum_size_policy, amogus_easter_egg
from shared.global_vars_and_funcs import settings, key_gogo_default_browser, key_make_download_complete_notification, key_quality, key_max_simulataneous_downloads, key_sub_or_dub
from shared.global_vars_and_funcs import pahe_normal_color, pahe_pressed_color, sub, dub, chrome_name, edge_name, firefox_name, q_1080, q_720, q_480, q_360
from shared.shared_classes_and_widgets import ScrollableSection, StyledLabel, OptionButton, SubDubButton, NumberInput, GogoBrowserButton, QualityButton
from windows.main_actual_window import MainWindow
import json


class SettingsWindow(QWidget):
    def __init__(self, main_window: MainWindow) -> None:
        super().__init__(main_window)
        self.font_size = 25
        self.main_layout = QVBoxLayout()
        self.main_widget = ScrollableSection(self.main_layout)
        self.sub_dub_setting = SubDubSetting(self)
        self.quality_setting = QualitySetting(self)
        self.max_simultaneous_downloads_setting = MaxSimultaneousDownloadsSetting(
            self)
        self.gogo_default_browser_setting = GogoDefaultBrowserSetting(self)
        self.make_download_complete_notification_setting = MakeDownloadCompleteNotificationSetting(
            self)
        self.main_layout.addWidget(self.sub_dub_setting)
        self.main_layout.addWidget(self.quality_setting)
        self.main_layout.addWidget(self.max_simultaneous_downloads_setting)
        self.main_layout.addWidget(self.gogo_default_browser_setting)
        self.main_layout.addWidget(
            self.make_download_complete_notification_setting)
        self.setLayout(self.main_layout)

    def update_settings_json(self, key: str, new_value: AllowedSettingsTypes):
        settings[key] = new_value
        validated = validate_settings_json(settings)
        with open(settings_file_path, "w") as f:
            json.dump(validated, f, indent=4)


class DownloadFoldersSetting(QWidget):
    def __init__(self, settings_window: SettingsWindow):
        _ = settings_window.font_size
        _ = QHBoxLayout()


class YesOrNo(OptionButton):
    def __init__(self, on_or_off: bool, font_size):
        super().__init__(None, on_or_off, "YES" if on_or_off else "NO",
                         font_size, pahe_normal_color, pahe_pressed_color)


class SettingWidget(QWidget):
    def __init__(self, settings_window: SettingsWindow, setting_info: str, widgets_to_add: list):
        super().__init__()
        setting_label = StyledLabel(font_size=settings_window.font_size+5)
        setting_label.setText(setting_info)
        set_minimum_size_policy(setting_label)
        main_layout = QHBoxLayout()
        main_layout.addWidget(setting_label)
        for button in widgets_to_add:
            main_layout.addWidget(button)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(main_layout)


class MakeDownloadCompleteNotificationSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        yes_button = YesOrNo(True, settings_window.font_size)
        no_button = YesOrNo(False, settings_window.font_size)
        yes_button.clicked.connect(lambda: no_button.picked_status(False))
        no_button.clicked.connect(lambda: yes_button.picked_status(False))
        yes_button.clicked.connect(lambda: settings_window.update_settings_json(
            key_make_download_complete_notification, True))
        no_button.clicked.connect(lambda: settings_window.update_settings_json(
            key_make_download_complete_notification, False))
        settings[key_make_download_complete_notification] if yes_button.picked_status(
            True) else no_button.picked_status(False)
        set_minimum_size_policy(yes_button)
        set_minimum_size_policy(no_button)
        super().__init__(settings_window,
                         "Notify you when download completes?", [yes_button, no_button])


class GogoDefaultBrowserSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        font_size = settings_window.font_size
        self.settings_window = settings_window
        button_chrome = GogoBrowserButton(
            settings_window, chrome_name, font_size)
        button_edge = GogoBrowserButton(settings_window, edge_name, font_size)
        button_firefox = GogoBrowserButton(
            settings_window, firefox_name, font_size)
        self.browser_buttons_list = [
            button_chrome, button_edge, button_firefox]
        for button in self.browser_buttons_list:
            set_minimum_size_policy(button)
            browser = button.browser
            button.clicked.connect(
                lambda garbage_bool, browser=browser: self.update_browser(browser))
            if button.browser == settings[key_gogo_default_browser]:
                button.picked_status(True)
        super().__init__(settings_window,
                         "Gogo default scraping browser", self.browser_buttons_list)

    def update_browser(self, browser: str):
        self.settings_window.update_settings_json(
            key_gogo_default_browser, browser)
        for button in self.browser_buttons_list:
            if button.browser != browser:
                button.picked_status(False)


class MaxSimultaneousDownloadsSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        number_input = NumberInput(font_size=settings_window.font_size)
        number_input.setFixedWidth(60)
        number_input.setPlaceholderText(amogus_easter_egg)
        number_input.setText(str(settings[key_max_simulataneous_downloads]))
        number_input.textChanged.connect(lambda value: settings_window.update_settings_json(
            key_max_simulataneous_downloads, int(value)) if value.isdigit() else None)
        super().__init__(settings_window,
                         "Max simultaneous downloads", [number_input])


class QualitySetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        font_size = settings_window.font_size
        self.settings_window = settings_window
        button_1080 = QualityButton(settings_window, q_1080, font_size)
        button_720 = QualityButton(settings_window, q_720, font_size)
        button_480 = QualityButton(settings_window, q_480, font_size)
        button_360 = QualityButton(settings_window, q_360, font_size)
        self.quality_buttons_list = [button_1080,
                                     button_720, button_480, button_360]
        for button in self.quality_buttons_list:
            set_minimum_size_policy(button)
            quality = button.quality
            button.clicked.connect(
                lambda garbage_bool, quality=quality: self.update_quality(quality))
            if button.quality == settings[key_quality]:
                button.picked_status(True)
        super().__init__(settings_window, "Download quality", self.quality_buttons_list)

    def update_quality(self, quality: str):
        self.settings_window.update_settings_json(key_quality, quality)
        for button in self.quality_buttons_list:
            if button.quality != quality:
                button.picked_status(False)


class SubDubSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        sub_button = SubDubButton(
            settings_window, sub, settings_window.font_size)
        set_minimum_size_policy(sub_button)
        dub_button = SubDubButton(
            settings_window, dub, settings_window.font_size)
        set_minimum_size_policy(dub_button)
        if settings[key_sub_or_dub] == sub:
            sub_button.click()
        else:
            dub_button.click()
        sub_button.clicked.connect(lambda: dub_button.picked_status(False))
        dub_button.clicked.connect(lambda: sub_button.picked_status(False))
        sub_button.clicked.connect(
            lambda: settings_window.update_settings_json(key_sub_or_dub, sub))
        dub_button.clicked.connect(
            lambda: settings_window.update_settings_json(key_sub_or_dub, dub))
        super().__init__(settings_window,
                         "Sub or Dub?", [sub_button, dub_button])
