#!/usr/bin/env python3
import subprocess
import sys
from argparse import ArgumentParser, Namespace
from os import path
from queue import Queue
from random import choice as random_choice
from threading import Event, Lock, Thread
from typing import Callable, cast

from tqdm import tqdm

from senpwai.common.classes import (
    SETTINGS,
    Anime,
    AnimeDetails,
    UpdateInfo,
    update_available,
)
from senpwai.common.scraper import (
    IBYTES_TO_MBS_DIVISOR,
    Download,
    ffmpeg_is_installed,
    fuzz_str,
    lacked_episode_numbers,
    lacked_episodes,
    try_installing_ffmpeg,
)
from senpwai.common.static import (
    APP_EXE_PATH as SENPWAI_EXE_PATH,
)
from senpwai.common.static import (
    DUB,
    GITHUB_API_LATEST_RELEASE_ENDPOINT,
    GITHUB_REPO_URL,
    GOGO,
    IS_PIP_INSTALL,
    OS,
    PAHE,
    Q_360,
    Q_480,
    Q_720,
    Q_1080,
    SUB,
    VERSION,
    open_folder,
    senpwai_tempdir,
)
from senpwai.scrapers import gogo, pahe
from enum import Enum

APP_NAME = "Senpcli"
SENPWAI_IS_INSTALLED = path.isfile(SENPWAI_EXE_PATH)
APP_NAME_LOWER = "senpcli"
DESCRIPTION = "The CLI alternative for Senpwai"
ASCII_APP_NAME = r"""
                                   .__  .__ 
  ______ ____   ____ ______   ____ |  | |__|
 /  ___// __ \ /    \\____ \_/ ___\|  | |  |
 \___ \\  ___/|   |  \  |_> >  \___|  |_|  |
/____  >\___  >___|  /   __/ \___  >____/__|
     \/     \/     \/|__|        \/         
"""


ANIME_REFERENCES = (
    "Hello friend",
    "It's called the Attack Titan",
    "Bertholdt, Reiner, Kono uragiri mono gaaaa!!!",
    "Tatakae tatake",
    "Ohio Final Boss",
    "Tokio tomare",
    "Wonder of Ohio",
    "Omoshire ore ga zangetsu da",
    "Getsuga Tenshou",
    "Rasenghan",
    "Za Warudo",
    "Star Pratina",
    "Nigurendayooo",
    "Korega jyuu da",
    "Mendokusai",
    "Dattebayo",
    "Bankaiiyeeeahhh, Ryuuumon Hooozokimaru!!!",
    "Kono asuratonkachi",
    "I devoured Barou and he devoured me right back",
    "United of States of Smaaaaash",
    "One for All Full Cowling",
    "Maid in Heaven Tokio Kasotsuru",
    "Nyaaa",
    "Pony Stark",
    "Dysfunctional Degenerate",
    "Alpha Sigma",
    "But Hey that's just a theory",
    "Bro fist",
    "King Crimson",
    "Sticky Fingers",
    "Watch Daily Lives of HighSchool Boys",
    "Watch Prison School",
    "Watch Grand Blue",
    "Watch Golden Boy, funniest shit I've ever seen",
    "Watch Isekai Ojii-san",
    "Read Kengan Asura, it's literally peak",
    "Read Dandadan",
    "Read A Thousand Splendid Suns",
    "Ryuujin no ken wo kurae!!!",
    "Ryuuga wakateki wo kurau",
    "Ookami o wagateki wo kurae",
    "Nerf this",
    "And dey say Chivalry is dead",
    "Who's next?",
    "Ryoiki Tenkai",
    "Ban.. .Kai Tensa Zangetsu",
    "Bankai Senbonzakura Kageyoshi",
    "Bankai Hihio Zabimaru",
    "Huuuero Zabimaru",
    "Nah I'd Code",
    "Nah I'd Exception",
    "Senpwai: Stand proud Senpcli, you can download",
    "We are the exception",
    "As the strongest curse Jogoat fought the fraud.. .",
    "Goodbye friend",
)


class Color(Enum):
    RED = "\033[91m"
    YELLOW = "\033[33m"
    GREEN = "\033[32m"
    CYAN = "\033[36m"
    LIGHT_BLUE = "\033[96m"
    BLUE = "\033[34m"
    MAGENTA = "\033[95m"
    RESET = "\033[0m"


class ProgressBar(tqdm):
    active: list["ProgressBar"] = []

    def __init__(
        self,
        total: int,
        desc: str,
        unit: str,
        unit_scale=False,
    ):
        super().__init__(
            total=total,
            desc=desc,
            unit=unit,
            unit_scale=unit_scale,
            leave=False,
        )
        ProgressBar.active.append(self)

    @staticmethod
    def cancel_all_active():
        for pbar in ProgressBar.active:
            pbar.close_(False)
        ProgressBar.active.clear()

    def update_(self, added: int):
        super().update(added)

    def close_(self, remove_from_active=True) -> None:
        if self not in ProgressBar.active:
            return
        if remove_from_active:
            ProgressBar.active.remove(self)
        super().close()


def parse_args(args: list[str]) -> tuple[Namespace, ArgumentParser]:
    parser = ArgumentParser(prog=APP_NAME_LOWER, description=DESCRIPTION)
    parser.add_argument("-v", "--version", action="version", version=VERSION)
    parser.add_argument(
        "title", help="Title of the anime to download", nargs="?", default=None
    )
    parser.add_argument(
        "-c",
        "--config",
        help="Show config file contents and location",
        action="store_true",
    )
    parser.add_argument("-u", "--update", help="Check for updates", action="store_true")
    parser.add_argument(
        "-s",
        "--site",
        help="Site to download from",
        choices=[PAHE, GOGO],
        default=SETTINGS.auto_download_site,
    )
    parser.add_argument(
        "-se",
        "--start_episode",
        type=int,
        help="Episode to start downloading at",
        default=-1,
    )
    parser.add_argument(
        "-ee",
        "--end_episode",
        type=int,
        help="Episode to stop downloading at",
        default=-1,
    )
    parser.add_argument(
        "-q",
        "--quality",
        help="Quality to download the anime in",
        choices=[Q_1080, Q_720, Q_480, Q_360],
        default=SETTINGS.quality,
    )
    parser.add_argument(
        "-sd",
        "--sub_or_dub",
        help="Whether to download the subbed or dubbed version of the anime",
        choices=[SUB, DUB],
        default=SETTINGS.sub_or_dub,
    )
    parser.add_argument(
        "-hls",
        "--hls",
        help="Use HLS mode to download the anime (Gogo only and requires FFmpeg to be installed)",
        action="store_true",
    )
    parser.add_argument(
        "-sc",
        "--skip_calculating",
        help="Skip calculating the total download size (Gogo only)",
        action="store_true",
        default=SETTINGS.gogo_skip_calculate,
    )
    parser.add_argument(
        "-of",
        "--open_folder",
        help="Open the folder containing the downloaded anime once the download finishes",
        action="store_true",
    )
    parser.add_argument(
        "-msd",
        "--max_simultaneous_downloads",
        type=int,
        help="Maximum number of simultaneous downloads",
        default=SETTINGS.max_simultaneous_downloads,
    )
    return parser.parse_args(args), parser


def search(title: str, site: str) -> Anime | None:
    animes = (
        [
            Anime(*pahe.extract_anime_title_page_link_and_id(r))
            for r in pahe.search(title)
        ]
        if site == PAHE
        else [Anime(*r, None) for r in gogo.search(title)]
    )
    results = None
    title_fuzzy = fuzz_str(title)
    for a in animes:
        if fuzz_str(a.title) == title_fuzzy:
            results = a
            break
    if results is None:
        print_error(f'No anime found with the title "{title}"')
        len_animes = len(animes)
        if len_animes > 0:
            results_str = "\n".join(
                [f"{idx + 1}: {a.title}" for idx, a in enumerate(animes)]
            )
            print_info(
                f"Here are the results:\n{results_str}\nPick one of the results by entering its number"
            )
            num = input("> ")
            if not num.isdigit():
                print_error("Invalid input")
                return None
            num = int(num)
            if num < 1 or num > len_animes:
                print_error("Invalid input")
                return None
            results = animes[num - 1]
    return results


def validate_start_and_end_episode(
    start_episode: int, end_episode: int, total_episode_count: int
) -> tuple[int, int]:
    if end_episode == -1:
        end_episode = total_episode_count
    if start_episode == -1:
        start_episode = total_episode_count
    if end_episode > total_episode_count:
        print_warn(
            f"Setting end episode to {total_episode_count} since the anime only has {total_episode_count} episodes"
        )
        end_episode = total_episode_count
    if start_episode > total_episode_count:
        print_warn(
            f"Setting start episode to {total_episode_count} since the anime only has {total_episode_count} episodes"
        )
        start_episode = end_episode
    return start_episode, end_episode


def pahe_get_episode_page_links(
    start_episode: int, end_episode: int, anime_id: str, anime_page_link: str
) -> list[str]:
    (
        start_page_num,
        end_page_num,
        episode_page_count,
        first_page,
    ) = pahe.get_episode_pages_info(anime_page_link, start_episode, end_episode)
    pbar = ProgressBar(
        total=episode_page_count,
        desc="Getting episode page links",
        unit="eps",
    )
    results = pahe.GetEpisodePageLinks().get_episode_page_links(
        start_episode,
        end_episode,
        start_page_num,
        end_page_num,
        first_page,
        anime_page_link,
        anime_id,
        pbar.update_,
    )
    pbar.close_()
    return results


def pahe_get_download_page_links(
    episode_page_links: list[str], quality: str, sub_or_dub: str
) -> list[str]:
    pbar = ProgressBar(
        total=len(episode_page_links),
        desc="Fetching download page links",
        unit="eps",
    )
    (
        down_page_links,
        down_info,
    ) = pahe.GetPahewinPageLinks().get_pahewin_page_links_and_info(
        episode_page_links, pbar.update_
    )
    down_page_links, down_info = pahe.bind_sub_or_dub_to_link_info(
        sub_or_dub, down_page_links, down_info
    )
    down_page_links, down_info = pahe.bind_quality_to_link_info(
        quality, down_page_links, down_info
    )
    total_download_size = pahe.calculate_total_download_size(down_info)
    pbar.close_()
    size_text = add_color(
        f"{total_download_size} MB{', go shower' if total_download_size >= 1000 else ''}",
        Color.MAGENTA,
    )
    print_info(f"Total download size: {size_text}")
    return down_page_links


def gogo_get_download_page_links(
    start_episode: int, end_episode: int, anime_page_content: bytes
) -> list[str]:
    anime_id = gogo.extract_anime_id(anime_page_content)
    return gogo.get_download_page_links(start_episode, end_episode, anime_id)


def gogo_calculate_total_download_size(direct_download_links: list[str]) -> None:
    pbar = ProgressBar(
        total=len(direct_download_links),
        desc="Calculating total download size",
        unit="eps",
    )
    total = gogo.CalculateTotalDowloadSize().calculate_total_download_size(
        direct_download_links, pbar.update_
    )
    pbar.close_()
    size = total // IBYTES_TO_MBS_DIVISOR
    size_text = add_color(
        f"{size} MB { ', go shower' if size >= 1000 else ''}", Color.MAGENTA
    )
    print_info(f"Total download size: {size_text}")


def gogo_get_direct_download_links(
    download_page_links: list[str], quality: str
) -> list[str]:
    pbar = ProgressBar(
        total=len(download_page_links),
        desc="Retrieving direct download links",
        unit="eps",
    )
    results = gogo.GetDirectDownloadLinks().get_direct_download_links(
        download_page_links, quality, pbar.update_
    )
    pbar.close_()
    return results


def pahe_get_direct_download_links(download_page_links: list[str]) -> list[str]:
    pbar = ProgressBar(
        total=len(download_page_links),
        desc="Retrieving direct download links",
        unit="eps",
    )
    results = pahe.GetDirectDownloadLinks().get_direct_download_links(
        download_page_links, pbar.update_
    )
    pbar.close_()
    return results


def create_progress_bar(
    episode_title: str, link_or_segs_urls: str | list[str], is_hls_download: bool
) -> ProgressBar:
    if is_hls_download:
        episode_size = len(link_or_segs_urls)
        pbar = ProgressBar(
            total=episode_size,
            unit="segs",
            desc=f"Downloading [HLS] {episode_title}",
        )
    else:
        episode_size, _ = Download.get_resource_length(cast(str, link_or_segs_urls))
        pbar = ProgressBar(
            total=episode_size,
            unit="iB",
            unit_scale=True,
            desc=f"Downloading {episode_title}",
        )
    return pbar


def download_thread(
    pbar: ProgressBar,
    episode_title: str,
    link_or_segs_urls: str | list[str],
    anime_details: AnimeDetails,
    is_hls_download: bool,
    finished_callback: Callable[[], None],
):
    download = Download(
        link_or_segs_urls,
        episode_title,
        anime_details.anime_folder_path,
        pbar.update_,
        is_hls_download=is_hls_download,
    )
    download.start_download()
    pbar.close_()
    finished_callback()


def download_manager(
    ddls_or_segs_urls: list[str] | list[list[str]],
    anime_details: AnimeDetails,
    is_hls_download: bool,
    max_simultaneous_downloads: int,
):
    anime_details.validate_anime_folder_path()
    desc = (
        f"Downloading [HLS] {anime_details.shortened_title}"
        if is_hls_download
        else f"Downloading {anime_details.shortened_title}"
    )
    episodes_pbar = ProgressBar(total=len(ddls_or_segs_urls), desc=desc, unit="eps")
    download_slot_available = Event()
    download_slot_available.set()
    downloads_complete = Event()
    curr_simultaneous_downloads = 0
    update_lock = Lock()

    def update_progress():
        with update_lock:
            nonlocal curr_simultaneous_downloads
            curr_simultaneous_downloads -= 1
            if curr_simultaneous_downloads < max_simultaneous_downloads:
                download_slot_available.set()
            episodes_pbar.update_(1)
            if episodes_pbar.n == episodes_pbar.total:
                downloads_complete.set()

    def wait(event: Event):
        # HACK: https://stackoverflow.com/a/14421297/17193072
        while not event.wait(0.1):
            pass

    for idx, link in enumerate(ddls_or_segs_urls):
        wait(download_slot_available)
        episode_title = anime_details.episode_title(idx)
        pbar = create_progress_bar(episode_title, link, is_hls_download)
        Thread(
            target=download_thread,
            args=(
                pbar,
                episode_title,
                link,
                anime_details,
                is_hls_download,
                update_progress,
            ),
            daemon=True,
        ).start()
        curr_simultaneous_downloads += 1
        if curr_simultaneous_downloads == max_simultaneous_downloads:
            download_slot_available.clear()

    wait(downloads_complete)
    episodes_pbar.close_()

    print_rainbow(
        f"Download complete uWu, Senpcli ga saikou no stando da!!!\n{random_choice(ANIME_REFERENCES)}"
    )


def install_ffmpeg_prompt() -> bool:
    if not ffmpeg_is_installed():
        print_error(
            "HLS mode requires FFmpeg to be installed, would you like to install it? (y/n)"
        )
        if input("> ").lower() == "y":
            successfully_installed = try_installing_ffmpeg()
            if not successfully_installed:
                print_error("Failed to automatically install FFmpeg")
            return successfully_installed
        else:
            return False
    return True


def already_has_all_episodes(
    anime_details: AnimeDetails,
    start_episode: int,
    end_episode: int,
    page_links: list[str],
) -> bool:
    anime_details.lacked_episode_numbers = lacked_episode_numbers(
        start_episode, end_episode, anime_details.haved_episodes
    )
    if not anime_details.lacked_episode_numbers:
        print_error(
            "Bakayorou, you already have all episodes within the provided range!!!"
        )
        return True
    lacked_eps_page_links = lacked_episodes(
        anime_details.lacked_episode_numbers, page_links
    )
    page_links.clear()
    page_links.extend(lacked_eps_page_links)
    return False


def gogo_get_hls_links(download_page_links: list[str]) -> list[str]:
    pbar = ProgressBar(
        total=len(download_page_links),
        desc="Getting HLS links",
        unit="eps",
    )
    results = gogo.GetHlsLinks().get_hls_links(download_page_links, pbar.update_)
    pbar.close_()
    return results


def gogo_get_hls_matched_quality_links(hls_links: list[str], quality: str) -> list[str]:
    pbar = ProgressBar(
        total=len(hls_links),
        desc="Matching quality to links",
        unit="eps",
    )
    results = gogo.GetHlsMatchedQualityLinks().get_hls_matched_quality_links(
        hls_links, quality, pbar.update_
    )
    pbar.close_()
    return results


def gogo_get_hls_segments_urls(matched_quality_links: list[str]) -> list[list[str]]:
    pbar = ProgressBar(
        total=len(matched_quality_links),
        desc="Getting segment links",
        unit="segs",
    )
    results = gogo.GetHlsSegmentsUrls().get_hls_segments_urls(
        matched_quality_links, pbar.update_
    )
    pbar.close_()
    return results


def handle_pahe(parsed: Namespace, anime_details: AnimeDetails):
    episode_page_links = pahe_get_episode_page_links(
        parsed.start_episode,
        parsed.end_episode,
        cast(str, anime_details.anime.id),
        anime_details.anime.page_link,
    )
    if already_has_all_episodes(
        anime_details, parsed.start_episode, parsed.end_episode, episode_page_links
    ):
        return
    download_page_links = pahe_get_download_page_links(
        episode_page_links, parsed.quality, parsed.sub_or_dub
    )
    direct_download_links = pahe_get_direct_download_links(download_page_links)
    download_manager(
        direct_download_links, anime_details, False, parsed.max_simultaneous_downloads
    )


def handle_gogo(parsed: Namespace, anime_details: AnimeDetails):
    if parsed.hls:
        if install_ffmpeg_prompt():
            download_page_links = gogo_get_download_page_links(
                parsed.start_episode,
                parsed.end_episode,
                anime_details.anime_page_content,
            )
            if already_has_all_episodes(
                anime_details,
                parsed.start_episode,
                parsed.end_episode,
                download_page_links,
            ):
                return
            hls_links = gogo_get_hls_links(download_page_links)
            matched_quality_links = gogo_get_hls_matched_quality_links(
                hls_links, parsed.quality
            )
            hls_segments_urls = gogo_get_hls_segments_urls(matched_quality_links)
            download_manager(
                hls_segments_urls,
                anime_details,
                True,
                parsed.max_simultaneous_downloads,
            )
    else:
        download_page_links = gogo_get_download_page_links(
            parsed.start_episode, parsed.end_episode, anime_details.anime_page_content
        )
        if already_has_all_episodes(
            anime_details, parsed.start_episode, parsed.end_episode, download_page_links
        ):
            return
        direct_download_links = gogo_get_direct_download_links(
            download_page_links, parsed.quality
        )
        if not parsed.skip_calculating:
            gogo_calculate_total_download_size(direct_download_links)
        download_manager(
            direct_download_links,
            anime_details,
            False,
            parsed.max_simultaneous_downloads,
        )


def check_for_update_thread(queue: Queue[UpdateInfo]) -> None:
    update_info = update_available(
        GITHUB_API_LATEST_RELEASE_ENDPOINT, APP_NAME, VERSION
    )
    queue.put((update_info))


def download_and_install_update(
    download_url: str,
    file_name: str,
) -> None:
    download_size, download_url = Download.get_resource_length(download_url)
    pbar = ProgressBar(
        total=download_size,
        desc="Downloading update",
        unit="iB",
        unit_scale=True,
    )
    file_name_no_ext, file_ext = path.splitext(file_name)
    tempdir = senpwai_tempdir()
    download = Download(download_url, file_name_no_ext, tempdir, pbar.update_, file_ext)
    download.start_download()
    pbar.close_()
    subprocess.Popen([path.join(tempdir, file_name), "/silent", "/update"])


def handle_update_check_result(update_info: UpdateInfo) -> None:
    if not update_info.is_update_available:
        return
    print_rainbow("\nUpdate available!!!\n")
    print_info(f"{update_info.release_notes}\n")
    if OS.is_android:
        print_info(
            'To update run:\n"pkg update -y && curl https://raw.githubusercontent.com/SenZmaKi/Senpwai/master/termux/install.sh | bash"'
        )
    elif IS_PIP_INSTALL:
        print_info('Install it by running "pip install senpwai --upgrade"')
        return
    elif SENPWAI_IS_INSTALLED:
        print_info("Install it by updating my big sister, Senpwai")
    elif OS.is_windows:
        print_info("Would you like to download and install it? (y/n)")
        if input("> ").lower() == "y":
            download_and_install_update(update_info.download_url, update_info.file_name)
    else:
        print_info(
            f"A new version is available, but to install it you'll have to build from source\nThere is a guide at: {GITHUB_REPO_URL}"
        )


def start_update_check_thread() -> tuple[Thread, Queue[UpdateInfo]]:
    update_check_result_queue: Queue[UpdateInfo] = Queue()
    update_check_thread = Thread(
        target=check_for_update_thread, args=(update_check_result_queue,), daemon=True
    )
    update_check_thread.start()
    return update_check_thread, update_check_result_queue


def get_anime_details(parsed) -> AnimeDetails | None:
    anime = search(parsed.title, parsed.site)
    if anime is None:
        return None
    if parsed.sub_or_dub == DUB and parsed.site == GOGO:
        dub_available, anime.page_link = gogo.dub_availability_and_link(anime.title)
        if not dub_available:
            return None
    anime_details = AnimeDetails(anime, parsed.site)
    if parsed.sub_or_dub == DUB:
        if not anime_details.dub_available:
            print_error("Dub not available for this anime")
            return None

    if parsed.start_episode == -1:
        if (
            anime_details.haved_end is not None
            and anime_details.haved_end < anime_details.metadata.episode_count
        ):
            new_start = anime_details.haved_end + 1
            if parsed.end_episode != -1 and new_start > parsed.end_episode:
                parsed.start_episode = parsed.end_episode
            else:
                parsed.start_episode = new_start
        else:
            parsed.start_episode = 1
    parsed.start_episode, parsed.end_episode = validate_start_and_end_episode(
        parsed.start_episode, parsed.end_episode, anime_details.metadata.episode_count
    )
    return anime_details


def initiate_download_pipeline(parsed: Namespace, anime_details: AnimeDetails):
    print_info(f"Downloading to: {anime_details.anime_folder_path}")
    if parsed.site == PAHE:
        handle_pahe(parsed, anime_details)
    else:
        handle_gogo(parsed, anime_details)
    if parsed.open_folder:
        open_folder(anime_details.anime_folder_path)


def validate_args(parsed: Namespace) -> bool:
    if parsed.end_episode < parsed.start_episode and parsed.end_episode != -1:
        print_error("End episode cannot be less than start episode, hontoni baka ga")
        return False
    if parsed.start_episode < 1 and parsed.start_episode != -1:
        print_error("Start episode cannot be less than 1, is that your IQ?")
        return False
    if parsed.end_episode < 1 and parsed.end_episode != -1:
        print_error("End episode cannot be less than 1, is that your brain cell count?")
        return False
    if parsed.site != GOGO and parsed.hls:
        print_warn("Setting site to Gogo since HLS mode is only available for Gogo")
        parsed.site = GOGO

    return True


def add_color(text: str, color: Color):
    return f"{color.value}{text}{Color.RESET.value}"


def print_rainbow(text: str):
    rainbowed_text = ""
    color_index = 0

    for line in text.split("\n"):
        for char in line:
            color = Color(list(Color)[color_index % len(Color)])
            rainbowed_text += add_color(char, color)
            color_index += 1
        rainbowed_text += "\n"

    print(rainbowed_text)


def print_error(text: str):
    print(add_color(text, Color.RED))


def print_info(text: str):
    print(add_color(text, Color.LIGHT_BLUE))


def print_warn(text: str):
    print(add_color(text, Color.YELLOW))


def main():
    try:
        args = sys.argv[1:]
        print_rainbow(ASCII_APP_NAME)
        parsed, parser = parse_args(args)

        if parsed.config:
            with open(SETTINGS.settings_json_path) as f:
                contents = f.read()
                print(f"{contents}\n\n{SETTINGS.settings_json_path}")
            return
        elif parsed.update:
            update_check_thread, update_check_result_queue = start_update_check_thread()
            update_check_thread.join()
            update_info = update_check_result_queue.get()
            if not update_info.is_update_available:
                print("No update available, already at latest version")
            handle_update_check_result(update_info)
            return
        elif parsed.title is None:
            print(
                f"{parser.format_usage()}senpcli: error: the following arguments are required: title"
            )
            return
        if not validate_args(parsed):
            return
        update_check_thread, update_check_result_queue = start_update_check_thread()
        anime_details = get_anime_details(parsed)
        if anime_details is None:
            return
        initiate_download_pipeline(parsed, anime_details)
        update_check_thread.join()
        update_info = update_check_result_queue.get()
        handle_update_check_result(update_info)

    except KeyboardInterrupt:
        ProgressBar.cancel_all_active()


if __name__ == "__main__":
    main()
