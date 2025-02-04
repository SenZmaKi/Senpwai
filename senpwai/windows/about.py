from typing import TYPE_CHECKING
from webbrowser import open_new_tab

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QHBoxLayout, QVBoxLayout, QWidget
from senpwai.common.static import (
    ABOUT_BCKG_IMAGE_PATH,
    DISCORD_ICON_PATH,
    DISCORD_INVITE_LINK,
    GIGACHAD_AUDIO_PATH,
    GITHUB_ICON_PATH,
    GITHUB_REPO_URL,
    GITHUB_SPONSORS_ICON_PATH,
    HENTAI_ADDICT_AUDIO_PATH,
    HENTAI_ADDICT_ICON_PATH,
    MORBIUS_AUDIO_PATH,
    MORBIUS_IS_PEAK_ICON_PATH,
    OS,
    PAHE_EXTRA_COLOR,
    PAHE_HOVER_COLOR,
    PAHE_PRESSED_COLOR,
    PATREON_ICON_PATH,
    REDDIT_ICON_PATH,
    SEN_ANILIST_ID,
    SEN_ICON_PATH,
    VERSION,
)
from senpwai.common.widgets import (
    AudioPlayer,
    Icon,
    IconButton,
    ScrollableSection,
    StyledButton,
    StyledLabel,
    StyledTextBrowser,
    Title,
    set_minimum_size_policy,
)

from senpwai.windows.abstracts import AbstractWindow

# To avoid circular imports cause we only need this for type checking
# https://stackoverflow.com/questions/39740632/python-type-hinting-without-cyclic-imports/3957388#39757388
if TYPE_CHECKING:
    from senpwai.windows.main import MainWindow


class AboutWindow(AbstractWindow):
    def __init__(self, main_window: "MainWindow"):
        super().__init__(main_window, ABOUT_BCKG_IMAGE_PATH)
        main_layout = QVBoxLayout()
        main_widget = ScrollableSection(main_layout)
        tips_title = Title("Tips")
        set_minimum_size_policy(tips_title)
        tips = StyledTextBrowser(self)
        startup_text = ""
        if OS.is_linux:
            startup_text = "- To start minimised to tray on startup, follow [this guide](https://stackoverflow.com/a/29247942/17193072) then pass `--minimised_to_tray` to Senpwai e.g., `senpwai --minimised_to_tray`"
        elif OS.is_mac:
            startup_text = "- To start minimised to tray on startup, follow [this guide](https://stackoverflow.com/a/6445525/17193072) then pass `--minimised_to_tray` to Senpwai e.g., `senpwai --minimised_to_tray`"
        tips.setMarkdown(
            f"""
{startup_text}
- When searching🔎 use the anime's Romaji title instead of the English title
- If you don't specify end episode, Senpwai will assume you mean the last episode
- Senpwai can detect missing episodes e.g., if you have One Piece🏴‍☠️  episodes 1 to 100 but are missing episode 50, specify 1 to 100, and it will only download episode 50
- If Senpwai can't find the quality you want it will pick the closest lower one e.g., if you choose 720p but only 1080p and 360p is available it'll pick 360p
- So long as the app is open Senpwai will try to resume⏯️  ongoing downloads even if you lose an internet connection
- [Hover✨](https://anilist.co/user/{SEN_ANILIST_ID}) over something that you don't understand there's probably a tool tip for it
- If the app screen📺 is white after you minimized it to tray and reopened it (usually on Windows🗑️), click the tray icon to fix it
- Open the settings folder by clicking the button with its location in the top left corner of the settings window
- Downloading from Pahe skips⏩ recap episodes, but this kind of messes up the episode numbering
- To completely remove Senpwai (don't know why you would though), post-uninstallation delete the settings folder, 🫵🏿®️🅰️🤡
- Click the tray icon to minimize to tray or set the close minimize to tray setting
- To use a custom font family, edit the `font_family` value in the settings file, if left empty, it will default to your OS setting
- Hate the background images📸? Check out the [discord]({DISCORD_INVITE_LINK}) for [senptheme](https://discord.com/channels/1131981618777702540/1211137093955362837/1211175899895038033)
        """
        )
        tips.setMinimumHeight(200)
        reviews_title = Title("Reviews")
        set_minimum_size_policy(reviews_title)
        reviews_widget = QWidget()
        reviews_layout = QHBoxLayout()
        size = 60
        sen_review = Review(
            Icon(size, size, SEN_ICON_PATH),
            GIGACHAD_AUDIO_PATH,
            "SenZmaKi",
            "69/10 Truly one of the apps of all time.",
        )
        hentai_addict_review = Review(
            Icon(size, size, HENTAI_ADDICT_ICON_PATH),
            HENTAI_ADDICT_AUDIO_PATH,
            "HentaiAddict01",
            "0/10 Can't even batch download hentai.. .",
        )
        morbius_is_peak_review = Review(
            Icon(size, size, MORBIUS_IS_PEAK_ICON_PATH),
            MORBIUS_AUDIO_PATH,
            "MorbiusIsPeak",
            "4/10 Morbius better + ratio + morbiusless",
        )
        reviews_layout.addWidget(sen_review)
        reviews_layout.addWidget(hentai_addict_review)
        reviews_layout.addWidget(morbius_is_peak_review)
        reviews_widget.setLayout(reviews_layout)
        set_minimum_size_policy(reviews_widget)
        support_title = Title("Support")
        set_minimum_size_policy(support_title)
        donations_label = StyledLabel()
        donations_label.setText(
            "Konnichiwa 👋🏿 it's Sen, the creator of Senpwai, I'm a goofy ahh ahh college student from Kenya.\nWifi is kinda expensive in my country, so donations help me pay for internet to keep developing new features and fixing bugs"
        )
        set_minimum_size_policy(donations_label)
        github_sponsors_button = IconButton(
            Icon(120, 120, GITHUB_SPONSORS_ICON_PATH), 1.1
        )
        github_sponsors_button.clicked.connect(
            lambda: open_new_tab("https://github.com/sponsors/SenZmaKi")
        )
        github_sponsors_button.setToolTip("https://github.com/sponsors/SenZmaKi")
        patreon_button = IconButton(Icon(80, 80, PATREON_ICON_PATH), 1.1)
        patreon_button.clicked.connect(
            lambda: open_new_tab("https://patreon.com/Senpwai")
        )
        patreon_button.setToolTip("https://patreon.com/Senpwai")
        donation_buttons_widget = QWidget()
        donation_buttons_layout = QHBoxLayout()
        donation_buttons_layout.addWidget(github_sponsors_button)
        donation_buttons_layout.addSpacing(10)
        donation_buttons_layout.addWidget(patreon_button)
        donation_buttons_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        donation_buttons_widget.setLayout(donation_buttons_layout)
        leave_a_star_label = StyledLabel()
        leave_a_star_label.setText(
            "You can also support Senpwai by starring the github repo, stars are free and help other weebs like us know about Senpwai"
        )
        set_minimum_size_policy(leave_a_star_label)
        social_links_title = Title("Social Links")
        set_minimum_size_policy(social_links_title)
        bug_reports_label = StyledLabel()
        bug_reports_label.setText(
            "Found a bug or wanna suggest a feature? Report/Suggest it in the discord server, github issues or subreddit"
        )
        set_minimum_size_policy(bug_reports_label)
        github_button = IconButton(Icon(200, 80, GITHUB_ICON_PATH), 1.1)
        github_button.clicked.connect(lambda: open_new_tab(GITHUB_REPO_URL))
        github_button.setToolTip(GITHUB_REPO_URL)
        reddit_button = IconButton(Icon(80, 80, REDDIT_ICON_PATH), 1.1)
        reddit_button.clicked.connect(
            lambda: open_new_tab("https://reddit.com/r/Senpwai")
        )
        reddit_button.setToolTip("https://reddit.com/r/Senpwai")
        discord_button = IconButton(Icon(80, 80, DISCORD_ICON_PATH), 1.1)
        discord_button.clicked.connect(lambda: open_new_tab(DISCORD_INVITE_LINK))
        discord_button.setToolTip(DISCORD_INVITE_LINK)
        social_links_buttons_widget = QWidget()
        social_links_buttons_layout = QHBoxLayout()
        social_links_buttons_layout.addWidget(discord_button)
        social_links_buttons_layout.addSpacing(30)
        social_links_buttons_layout.addWidget(github_button)
        social_links_buttons_layout.addSpacing(30)
        social_links_buttons_layout.addWidget(reddit_button)
        social_links_buttons_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        social_links_buttons_widget.setLayout(social_links_buttons_layout)
        version_button = StyledButton(
            self, 33, "black", PAHE_EXTRA_COLOR, PAHE_HOVER_COLOR, PAHE_PRESSED_COLOR
        )
        version_button.setText(f"Version {VERSION}")
        version_button.setToolTip("Click to check for updates")
        version_button.clicked.connect(main_window.check_for_updates)
        set_minimum_size_policy(version_button)

        main_layout.addSpacing(40)
        main_layout.addWidget(tips_title)
        main_layout.addWidget(tips)
        main_layout.addSpacing(40)
        main_layout.addWidget(reviews_title, Qt.AlignmentFlag.AlignCenter)
        main_layout.addWidget(reviews_widget, Qt.AlignmentFlag.AlignCenter)
        main_layout.addWidget(support_title)
        main_layout.addWidget(donations_label)
        main_layout.addWidget(donation_buttons_widget)
        main_layout.addWidget(leave_a_star_label)
        main_layout.addSpacing(40)
        main_layout.addWidget(social_links_title)
        main_layout.addWidget(bug_reports_label)
        main_layout.addWidget(social_links_buttons_widget)
        main_layout.addWidget(version_button)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignTop)
        self.setLayout(self.full_layout)


class Review(QWidget):
    def __init__(self, icon: Icon, audio_path: str, author: str, text: str):
        super().__init__()
        main_layout = QVBoxLayout()

        profile_pic = IconButton(icon, 1.1)
        profile_pic.clicked.connect(AudioPlayer(self, audio_path, volume=60).play)
        author_name = StyledLabel(None, 15, PAHE_EXTRA_COLOR, font_color="black")
        author_name.setText(author)
        set_minimum_size_policy(author_name)
        review_text = StyledLabel(None, 15, font_color="white", bckg_color="black")
        review_text.setText(text)
        set_minimum_size_policy(review_text)

        main_layout.addWidget(profile_pic, alignment=Qt.AlignmentFlag.AlignHCenter)
        main_layout.addWidget(author_name, alignment=Qt.AlignmentFlag.AlignHCenter)
        main_layout.addWidget(review_text)
        self.setLayout(main_layout)
        set_minimum_size_policy(self)
