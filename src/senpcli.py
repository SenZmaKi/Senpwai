import subprocess
import sys
from argparse import ArgumentParser, Namespace
from random import choice as random_choice
from threading import Event, Lock, Thread
from typing import Callable, cast
from queue import Queue
from os import path

from utils.class_utils import SETTINGS, Anime, AnimeDetails, update_available
from scrapers import gogo, pahe
from utils.scraper_utils import (
    IBYTES_TO_MBS_DIVISOR,
    Download,
    ffmpeg_is_installed,
    fuzz_str,
    lacked_episode_numbers,
    lacked_episodes,
    try_installing_ffmpeg,
)
from utils.static_utils import (
    open_folder,
    DUB,
    APP_EXE_PATH as SENPWAI_EXE_PATH,
    GOGO,
    PAHE,
    Q_360,
    Q_480,
    Q_720,
    Q_1080,
    SUB,
    VERSION,
    GITHUB_API_LATEST_RELEASE_ENDPOINT,
    GITHUB_REPO_URL,
    SRC_DIRECTORY,
)
from tqdm import tqdm

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
    "Senpwai: Stand proud Senpcli, you are strong",
    "We are the exception",
    "As the strongest curse Jogoat fought the fraud.. .",
    "Goodbye friend",
)


def parse_args(args: list[str]) -> Namespace:
    parser = ArgumentParser(prog=APP_NAME_LOWER, description=DESCRIPTION)
    parser.add_argument("-v", "--version", action="version", version=VERSION)
    parser.add_argument(
        "-sd",
        "--sub_or_dub",
        help="Whether to download the subbed or dubbed version of the anime",
        choices=[SUB, DUB],
        default=SETTINGS.sub_or_dub,
    )
    parser.add_argument("title", help="Title of the anime to download")
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
        help="Open the folder containing the downloaded anime",
        action="store_true",
    )
    parser.add_argument(
        "-msd",
        "--max_simultaneous_downloads",
        type=int,
        help="Maximum number of simultaneous downloads",
        default=SETTINGS.max_simultaneous_downloads,
    )
    return parser.parse_args(args)


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
        print(f'No anime found with the title "{title}"')
        len_animes = len(animes)
        if len_animes > 0:
            results_str = "\n".join(
                [f"{idx + 1}: {a.title}" for idx, a in enumerate(animes)]
            )
            print(
                f"Here are the results:\n{results_str}\nPick one of the results by entering its number"
            )
            num = input("> ")
            if not num.isdigit():
                print("Invalid input")
                return None
            num = int(num)
            if num < 1 or num > len_animes:
                print("Invalid input")
                return None
            results = animes[num - 1]
    return results


def validate_start_and_end_episode(
    start_episode: int, end_episode: int, total_episode_count: int
) -> tuple[int, int]:
    if end_episode == -1:
        end_episode = total_episode_count
    if end_episode > total_episode_count:
        print(
            f"Setting end episode to {total_episode_count} since the anime only has {total_episode_count} episodes"
        )
        end_episode = total_episode_count
    if start_episode > total_episode_count:
        print(
            f"Setting start episode to {total_episode_count} since the anime only has {total_episode_count} episodes"
        )
        start_episode = end_episode
    return start_episode, end_episode


def pahe_get_episode_page_links(
    start_episode: int, end_episode: int, anime_id: str, anime_page_link: str
) -> list[str]:
    total_eps_pages = pahe.get_total_episode_page_count(anime_page_link)
    pbar = tqdm(
        total=total_eps_pages,
        desc="Getting episode page links",
        unit="eps",
        leave=False,
    )
    results = pahe.GetEpisodePageLinks().get_episode_page_links(
        start_episode, end_episode, anime_page_link, cast(str, anime_id), pbar.update
    )
    pbar.close()
    return results


def pahe_get_download_page_links(
    episode_page_links: list[str], quality: str, sub_or_dub: str
) -> list[str]:
    pbar = tqdm(
        total=len(episode_page_links),
        desc="Fetching download page links",
        unit="eps",
        leave=False,
    )
    (
        down_page_links,
        down_info,
    ) = pahe.GetPahewinDownloadPageLinks().get_pahewin_download_page_links_and_info(
        episode_page_links, pbar.update
    )
    down_page_links, down_info = pahe.bind_sub_or_dub_to_link_info(
        sub_or_dub, down_page_links, down_info
    )
    down_page_links, down_info = pahe.bind_quality_to_link_info(
        quality, down_page_links, down_info
    )
    total_download_size = pahe.calculate_total_download_size(down_info)
    pbar.close()
    print(f"Total download size: {total_download_size} MB")
    return down_page_links


def gogo_get_download_page_links(
    start_episode: int, end_episode: int, anime_page_link: str
) -> list[str]:
    anime_id = gogo.extract_anime_id(gogo.get_anime_page_content(anime_page_link))
    return gogo.get_download_page_links(start_episode, end_episode, anime_id)


def gogo_calculate_total_download_size(direct_download_links: list[str]) -> None:
    pbar = tqdm(
        total=len(direct_download_links),
        desc="Calculating total download size",
        unit="eps",
        leave=False,
    )
    total = gogo.CalculateTotalDowloadSize().calculate_total_download_size(
        direct_download_links, pbar.update
    )
    pbar.close()
    print(f"Total download size: {total // IBYTES_TO_MBS_DIVISOR} MB")


def gogo_get_direct_download_links(
    download_page_links: list[str], quality: str
) -> list[str]:
    pbar = tqdm(
        total=len(download_page_links),
        desc="Retrieving direct download links",
        unit="eps",
        leave=False,
    )
    results = gogo.GetDirectDownloadLinks().get_direct_download_links(
        download_page_links, quality, pbar.update
    )
    pbar.close()
    return results


def pahe_get_direct_download_links(download_page_links: list[str]) -> list[str]:
    pbar = tqdm(
        total=len(download_page_links),
        desc="Retrieving direct download links",
        unit="eps",
        leave=False,
    )
    results = pahe.GetDirectDownloadLinks().get_direct_download_links(
        download_page_links, pbar.update
    )
    pbar.close()
    return results


def download_thread(
    episode_title: str,
    link_or_segs_urls: str | list[str],
    anime_details: AnimeDetails,
    is_hls_download: bool,
    progress_updater: Callable,
):
    if is_hls_download:
        episode_size = len(link_or_segs_urls)
    else:
        episode_size, link_or_segs_urls = Download.get_resource_length(
            cast(str, link_or_segs_urls)
        )
    if is_hls_download:
        pbar = tqdm(
            total=episode_size,
            unit="segs",
            desc=f"Downloading [HLS] {episode_title}",
            leave=False,
        )
    else:
        pbar = tqdm(
            total=episode_size,
            unit="iB",
            unit_scale=True,
            desc=f"Downloading {episode_title}",
            leave=False,
        )
    download = Download(
        link_or_segs_urls,
        episode_title,
        anime_details.anime_folder_path,
        pbar.update,
        is_hls_download=is_hls_download,
    )
    download.start_download()
    pbar.close()
    progress_updater(1)


def download_manager(
    ddls_or_segs_urls: list[str] | list[list[str]],
    anime_details: AnimeDetails,
    is_hls_download: bool,
    max_simultaneous_downloads: int,
):
    anime_details.validate_anime_folder_path()
    desc = (
        f"Downloading [HLS] {anime_details.sanitised_title}"
        if is_hls_download
        else f"Downloading {anime_details.sanitised_title}"
    )
    episodes_pbar = tqdm(
        total=len(ddls_or_segs_urls), desc=desc, unit="eps", leave=False
    )
    download_slot_available = Event()
    download_slot_available.set()
    downloads_complete = Event()
    curr_simultaneous_downloads = 0
    update_lock = Lock()

    def update_progress(added):
        update_lock.acquire()
        nonlocal curr_simultaneous_downloads
        curr_simultaneous_downloads -= 1
        if curr_simultaneous_downloads < max_simultaneous_downloads:
            download_slot_available.set()
        episodes_pbar.update(added)
        if episodes_pbar.n == episodes_pbar.total:
            downloads_complete.set()
        update_lock.release()

    for idx, link in enumerate(ddls_or_segs_urls):
        download_slot_available.wait()
        episode_title = anime_details.episode_title(idx)
        Thread(
            target=download_thread,
            args=(episode_title, link, anime_details, is_hls_download, update_progress),
        ).start()
        curr_simultaneous_downloads += 1
        if curr_simultaneous_downloads == max_simultaneous_downloads:
            download_slot_available.clear()

    downloads_complete.wait()
    episodes_pbar.close()

    print(
        f"Download complete uWu, Senpcli ga saikou no stando da!!!\n{random_choice(ANIME_REFERENCES)}"
    )


def install_ffmpeg_prompt() -> bool:
    if not ffmpeg_is_installed():
        print(
            "HLS mode requires FFmpeg to be installed, would you like to install it? (y/n)"
        )
        if input("> ").lower() == "y":
            successfully_installed = try_installing_ffmpeg()
            if not successfully_installed:
                print("Failed to automatically install FFmpeg")
            return successfully_installed
        else:
            print("Aborting")
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
    if anime_details.lacked_episode_numbers == []:
        print("Bakayorou, you already have all episodes within the provided range!!!")
        return True
    lacked_eps_page_links = lacked_episodes(
        anime_details.lacked_episode_numbers, page_links
    )
    page_links.clear()
    page_links.extend(lacked_eps_page_links)
    return False


def gogo_get_hls_links(download_page_links: list[str]) -> list[str]:
    pbar = tqdm(
        total=len(download_page_links),
        desc="Getting HLS links",
        unit="eps",
        leave=False,
    )
    results = gogo.GetHlsLinks().get_hls_links(download_page_links, pbar.update)
    pbar.close()
    return results


def gogo_get_hls_matched_quality_links(hls_links: list[str], quality: str) -> list[str]:
    pbar = tqdm(
        total=len(hls_links), desc="Matching quality to links", unit="eps", leave=False
    )
    results = gogo.GetHlsMatchedQualityLinks().get_hls_matched_quality_links(
        hls_links, quality, pbar.update
    )
    pbar.close()
    return results


def gogo_get_hls_segments_urls(matched_quality_links: list[str]) -> list[list[str]]:
    pbar = tqdm(
        total=len(matched_quality_links),
        desc="Getting segment links",
        unit="segs",
        leave=False,
    )
    results = gogo.GetHlsSegmentsUrls().get_hls_segments_urls(
        matched_quality_links, pbar.update
    )
    pbar.close()
    return results


def handle_pahe(parsed: Namespace, anime: Anime, anime_details: AnimeDetails):
    episode_page_links = pahe_get_episode_page_links(
        parsed.start_episode, parsed.end_episode, cast(str, anime.id), anime.page_link
    )
    if already_has_all_episodes(
        anime_details, parsed.start_episode, parsed.end_episode, episode_page_links
    ):
        return
    if parsed.sub_or_dub == DUB and not pahe.dub_available(
        anime.page_link, cast(str, anime.id)
    ):
        print("Dub not available for this anime")
        return
    download_page_links = pahe_get_download_page_links(
        episode_page_links, parsed.quality, parsed.sub_or_dub
    )
    direct_download_links = pahe_get_direct_download_links(download_page_links)
    download_manager(
        direct_download_links, anime_details, False, parsed.max_simultaneous_downloads
    )


def handle_gogo(parsed: Namespace, anime: Anime, anime_details: AnimeDetails):
    if parsed.hls:
        if install_ffmpeg_prompt():
            download_page_links = gogo_get_download_page_links(
                parsed.start_episode, parsed.end_episode, anime.page_link
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
            parsed.start_episode, parsed.end_episode, anime.page_link
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


def check_for_update_thread(queue: Queue) -> None:
    is_available, download_url, file_name, _ = update_available(
        GITHUB_API_LATEST_RELEASE_ENDPOINT, APP_NAME, VERSION
    )
    queue.put((is_available, download_url, file_name))


def download_and_install_update(download_url: str, file_name: str) -> None:
    download_size, download_url = Download.get_resource_length(download_url)
    pbar = tqdm(
        total=download_size,
        desc="Downloading update",
        unit="iB",
        unit_scale=True,
        leave=False,
    )
    file_name_no_ext, file_ext = path.splitext(file_name)
    download = Download(
        download_url, file_name_no_ext, SRC_DIRECTORY, pbar.update, file_ext
    )
    download.start_download()
    pbar.close()
    subprocess.Popen([path.join(SRC_DIRECTORY, file_name), "/silent", "/update"])


def handle_update_check_result(
    is_available: bool, download_url, file_name: str
) -> None:
    if SENPWAI_IS_INSTALLED:
        return print("Update available, install it by updating Senpwai")
    if is_available:
        if sys.platform == "win32":
            print("Update available, would you like to download and install it? (y/n)")
            if input("> ").lower() == "y":
                download_and_install_update(download_url, file_name)
        else:
            print(
                f"A new version is available, but to install it you'll have to build from source\nThere is a guide at: {GITHUB_REPO_URL}"
            )


def start_update_check_thread() -> tuple[Thread, Queue]:
    update_check_result_queue = Queue()
    update_check_thread = Thread(
        target=check_for_update_thread, args=(update_check_result_queue,)
    )
    update_check_thread.start()
    return update_check_thread, update_check_result_queue


def get_anime_and_anime_details(parsed) -> tuple[Anime, AnimeDetails] | None:
    anime = search(parsed.title, parsed.site)
    if anime is None:
        return None
    if parsed.sub_or_dub == DUB and parsed.site == GOGO:
        dub_available, anime.page_link = gogo.dub_availability_and_link(anime.title)
        if not dub_available:
            print("Dub not available for this anime")
            return None
    anime_details = AnimeDetails(anime, parsed.site)
    if parsed.start_episode == -1:
        if (
            anime_details.haved_end is not None
            and anime_details.haved_end < anime_details.metadata.episode_count
        ):
            parsed.start_episode = anime_details.haved_end + 1
        else:
            parsed.start_episode = 1
    parsed.start_episode, parsed.end_episode = validate_start_and_end_episode(
        parsed.start_episode, parsed.end_episode, anime_details.metadata.episode_count
    )
    return anime, anime_details


def initiate_download_pipeline(
    parsed: Namespace, anime: Anime, anime_details: AnimeDetails
):
    print(f"Downloading to: {anime_details.anime_folder_path}")
    if parsed.site == PAHE:
        handle_pahe(parsed, anime, anime_details)
    else:
        handle_gogo(parsed, anime, anime_details)
    if parsed.open_folder:
        open_folder(anime_details.anime_folder_path)


def validate_args(parsed: Namespace) -> bool:
    if parsed.end_episode < parsed.start_episode:
        print("End episode cannot be less than start episode, hontoni baka ga")
        return False
    elif parsed.start_episode < 1 and parsed.start_episode != -1:
        print("Start episode cannot be less than 1, is that your IQ?")
        return False
    elif parsed.end_episode < 1 and parsed.end_episode != -1:
        print("End episode cannot be less than 1, is that your brain cell count?")
        return False
    elif parsed.site != GOGO and parsed.hls:
        print("Setting site to Gogo since HLS mode is only available for Gogo")
        parsed.site = GOGO

    return True


def main():
    try:
        args = sys.argv[1:]
        print(ASCII_APP_NAME)
        parsed = parse_args(args)
        if not validate_args(parsed):
            return
        update_check_thread, update_check_result_queue = start_update_check_thread()
        anime_and_anime_details = get_anime_and_anime_details(parsed)
        if anime_and_anime_details is None:
            return
        initiate_download_pipeline(parsed, *anime_and_anime_details)
        update_check_thread.join()
        handle_update_check_result(*update_check_result_queue.get())

    except KeyboardInterrupt:
        print("\n\nAborted")


if __name__ == "__main__":
    main()
