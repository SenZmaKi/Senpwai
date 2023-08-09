from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QFileDialog
from PyQt6.QtCore import Qt
from shared.global_vars_and_funcs import AllowedSettingsTypes, validate_settings_json, settings_file_path, set_minimum_size_policy, amogus_easter_egg, requires_admin_access, settings_window_bckg_image_path, gogo_normal_color, gogo_hover_color
from shared.global_vars_and_funcs import settings, key_gogo_default_browser, key_make_download_complete_notification, key_quality, key_max_simulataneous_downloads, key_sub_or_dub, key_download_folder_paths, key_start_in_fullscreen
from shared.global_vars_and_funcs import pahe_normal_color, pahe_pressed_color, pahe_hover_color, red_normal_color, red_hover_color, red_pressed_color, sub, dub, CHROME, EDGE, FIREFOX, q_1080, q_720, q_480, q_360, gogo_pressed_color
from shared.shared_classes_and_widgets import ScrollableSection, StyledLabel, OptionButton, SubDubButton, NumberInput, GogoBrowserButton, QualityButton, StyledButton, ErrorLabel, HorizontalLine
from windows.main_actual_window import MainWindow, Window
import json
import os
from typing import cast


class SettingsWindow(Window):
    def __init__(self, main_window: MainWindow) -> None:
        super().__init__(main_window, settings_window_bckg_image_path)
        self.font_size = 25
        main_layout = QVBoxLayout()
        self.main_widget = ScrollableSection(main_layout)
        self.sub_dub_setting = SubDubSetting(self)
        self.quality_setting = QualitySetting(self)
        self.max_simultaneous_downloads_setting = MaxSimultaneousDownloadsSetting(
            self)
        self.gogo_default_browser_setting = GogoDefaultBrowserSetting(self)
        self.make_download_complete_notification_setting = MakeDownloadCompleteNotificationSetting(
            self)
        self.start_in_fullscreen = StartInFullscreenSetting(
            self
        )
        self.download_folder_setting = DownloadFoldersSetting(
            self, main_window)
        main_layout.addWidget(self.sub_dub_setting)
        main_layout.addWidget(self.quality_setting)
        main_layout.addWidget(self.max_simultaneous_downloads_setting)
        main_layout.addWidget(self.gogo_default_browser_setting)
        main_layout.addWidget(
            self.make_download_complete_notification_setting)
        main_layout.addWidget(self.start_in_fullscreen)
        main_layout.addWidget(self.download_folder_setting)
        main_widget = QWidget()
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)

    def update_settings_json(self, key: str, new_value: AllowedSettingsTypes):
        settings[key] = new_value
        validated = validate_settings_json(settings)
        with open(settings_file_path, "w") as f:
            json.dump(validated, f, indent=4)


class DownloadFoldersSetting(QWidget):
    def __init__(self, settings_window: SettingsWindow, main_window: MainWindow):
        super().__init__()
        self.settings_window = settings_window
        self.font_size = settings_window.font_size
        self.main_window = main_window
        self.main_layout = QVBoxLayout()
        settings_label = StyledLabel(font_size=self.font_size+5)
        settings_label.setText("Download folders")
        settings_label.setToolTip(
            "Senpwai will search these folders in the order shown looking for episodes of an anime that is about to be downloaded.")
        set_minimum_size_policy(settings_label)
        self.error_label = ErrorLabel(18, 6)
        self.error_label.hide()
        add_button = StyledButton(self, self.font_size, "White",
                                  gogo_normal_color, gogo_hover_color, gogo_pressed_color)
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
        horizontal_line = HorizontalLine()
        horizontal_line.setFixedHeight(8)
        self.main_layout.addWidget(horizontal_line)
        self.folder_widgets_layout = QVBoxLayout()
        for idx, folder in enumerate(settings[key_download_folder_paths]):
            self.folder_widgets_layout.addWidget(DownloadFolderWidget(
                main_window, self, self.font_size - 5, folder, idx))
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
        elif new_folder_path in settings[key_download_folder_paths]:
            self.error("Baka!!! that folder is already in the settings")
            return False
        else:
            return True

    def update_widget_indices(self):
        for idx in range(self.folder_widgets_layout.count()):

            cast(DownloadFolderWidget, self.folder_widgets_layout.itemAt(
                idx).widget()).index = idx

    def change_from_folder_settings(self, new_folder_path: str, download_folder_widget: QWidget):
        download_folder_widget = cast(
            DownloadFolderWidget, download_folder_widget)
        new_folders_settings = cast(list, settings[key_download_folder_paths])
        new_folders_settings[download_folder_widget.index] = new_folder_path
        download_folder_widget.folder_path = new_folder_path
        download_folder_widget.folder_label.setText(new_folder_path)
        set_minimum_size_policy(download_folder_widget.folder_label)
        download_folder_widget.folder_label.update()
        self.settings_window.update_settings_json(
            key_download_folder_paths, new_folders_settings)

    def remove_from_folder_settings(self, download_folder_widget: QWidget):
        download_folder_widget = cast(
            DownloadFolderWidget, download_folder_widget)
        new_folders_settings = cast(list, settings[key_download_folder_paths])
        if len(new_folders_settings) - 1 <= 0:
            return self.error("Yarou!!! You must have at least one download folder")
        new_folders_settings.pop(download_folder_widget.index)
        download_folder_widget.deleteLater()
        self.folder_widgets_layout.removeWidget(download_folder_widget)
        self.settings_window.update_settings_json(
            key_download_folder_paths, new_folders_settings)
        self.update_widget_indices()

    def add_folder_to_settings(self):
        added_folder_path = QFileDialog.getExistingDirectory(
            self.main_window, "Choose folder")
        if not self.is_valid_new_folder(added_folder_path):
            return
        self.folder_widgets_layout.addWidget(DownloadFolderWidget(
            self.main_window, self, self.font_size - 5, added_folder_path, self.folder_widgets_layout.count()))
        self.settings_window.update_settings_json(
            key_download_folder_paths, settings[key_download_folder_paths] + [added_folder_path])


class DownloadFolderWidget(QWidget):
    def __init__(self, main_window: MainWindow, download_folder_setting: DownloadFoldersSetting, font_size: int, folder_path: str, index: int):
        super().__init__()
        self.main_window = main_window
        self.folder_path = folder_path
        self.download_folder_setting = download_folder_setting
        self.index = index
        main_layout = QHBoxLayout()
        self.folder_label = StyledLabel(font_size=font_size)
        self.folder_label.setText(folder_path)
        set_minimum_size_policy(self.folder_label)
        self.change_button = StyledButton(
            self, font_size, "white", pahe_normal_color, pahe_hover_color, pahe_pressed_color)
        self.change_button.clicked.connect(self.change_folder)
        self.change_button.setText("CHANGE")
        set_minimum_size_policy(self.change_button)
        remove_button = StyledButton(
            self, font_size, "white", red_normal_color, red_hover_color, red_pressed_color)
        remove_button.setText("REMOVE")
        remove_button.clicked.connect(
            lambda: self.download_folder_setting.remove_from_folder_settings(self))
        set_minimum_size_policy(remove_button)
        main_layout.addWidget(self.folder_label)
        main_layout.addWidget(self.change_button)
        main_layout.addWidget(remove_button)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(main_layout)

    def change_folder(self):
        new_folder_path = QFileDialog.getExistingDirectory(
            self.main_window, "Choose folder")
        if self.download_folder_setting.is_valid_new_folder(new_folder_path):
            self.download_folder_setting.change_from_folder_settings(
                new_folder_path, self)


class YesOrNo(OptionButton):
    def __init__(self, on_or_off: bool, font_size):
        super().__init__(None, on_or_off, "YES" if on_or_off else "NO",
                         font_size, pahe_normal_color, pahe_pressed_color)


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


class StartInFullscreenSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        yes_button = YesOrNo(True, settings_window.font_size)
        no_button = YesOrNo(False, settings_window.font_size)
        yes_button.clicked.connect(lambda: no_button.picked_status(False))
        no_button.clicked.connect(lambda: yes_button.picked_status(False))
        yes_button.clicked.connect(lambda: settings_window.update_settings_json(
            key_start_in_fullscreen, True))
        no_button.clicked.connect(lambda: settings_window.update_settings_json(
            key_start_in_fullscreen, False))
        yes_button.picked_status(
            True) if settings[key_start_in_fullscreen] else no_button.picked_status(True)
        set_minimum_size_policy(yes_button)
        set_minimum_size_policy(no_button)
        super().__init__(settings_window,
                         "Start app in fullscreen?", [yes_button, no_button])


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
        yes_button.picked_status(
            True) if settings[key_make_download_complete_notification] else no_button.picked_status(True)
        set_minimum_size_policy(yes_button)
        set_minimum_size_policy(no_button)
        super().__init__(settings_window,
                         "Notify you when download completes uWu?", [yes_button, no_button])


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
            if button.browser == settings[key_gogo_default_browser]:
                button.picked_status(True)
        super().__init__(settings_window,
                         "Gogo default scraping browser", self.browser_buttons_list)
        self.setting_label.setToolTip(
            "The selected browser will be used for scraping if you download from Gogoanime.")

    def update_browser(self, browser: str):
        self.settings_window.update_settings_json(
            key_gogo_default_browser, browser)
        for button in self.browser_buttons_list:
            if button.browser != browser:
                button.picked_status(False)


class MaxSimultaneousDownloadsSetting(SettingWidget):
    def __init__(self, settings_window: SettingsWindow):
        self.settings_window = settings_window
        number_input = NumberInput(font_size=settings_window.font_size)
        number_input.setFixedWidth(60)
        number_input.setPlaceholderText(amogus_easter_egg)
        number_input.setText(str(settings[key_max_simulataneous_downloads]))
        number_input.textChanged.connect(self.text_changed)
        zero_error = ErrorLabel(18, 4)
        zero_error.setText("Bruh, max simultaneous downloads can't be zero.")
        set_minimum_size_policy(zero_error)
        self.zero_error = zero_error.show
        main_layout = QVBoxLayout()
        main_layout.addWidget(zero_error)
        zero_error.hide()
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
            key_max_simulataneous_downloads, new_setting)


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
