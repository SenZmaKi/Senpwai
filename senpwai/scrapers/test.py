import os
import shutil
import sys
import time
from typing import Any, Callable, cast

from senpwai.common.scraper import (
    IBYTES_TO_MBS_DIVISOR,
    AnimeMetadata,
    Download,
    strip_title,
)
from senpwai.common.static import ROOT_DIRECTORY

from senpwai.scrapers import gogo, pahe

PAHE = pahe.PAHE
GOGO = gogo.GOGO

DEFAULT_ANIME_TITLE = "Dr. Stone"
DEFAULT_QUALITY = "360p"
DEFAULT_START_EPISODE = "1"
DEFAULT_END_EPISODE = "2"
DEFAULT_SUB_OR_DUB = "sub"
DEFAULT_SITE = "pahe"
DEFAULT_DOWNLOAD_FOLDER_PATH = os.path.join(
    os.path.dirname(ROOT_DIRECTORY), ".test-downloads"
)
DEFAULT_VERBOSE = False
DEFAULT_SILENT = False
SILENT = DEFAULT_SILENT
COMMANDS = [
    "search",
    "dub_available",
    "metadata",
    "episode_page",
    "download_page",
    "download_size",
    "direct_links",
    "hls_links",
    "match_links",
    "segments_urls",
    "download",
    "all",
]


class FailedTest(Exception):
    def __init__(self, msg: str):
        super().__init__(msg)


def conditional_print(text: str):
    if not SILENT:
        print(text)


def test_start(name: str):
    conditional_print(f"Testing: {name}")


def fail_test(
    name: str,
    expected: Any,
    got: Any,
    execution_time: float,
    test_variables: str | None = None,
):
    msg = f"{name} Test\nExpected: {expected}\nGot: {got}\nExecution time: {round(execution_time, 2)}s"
    if test_variables:
        msg = f"{msg}\nTest Variables:\n{test_variables}"
    raise FailedTest(msg)


def pass_test(name: str, execution_time: float):
    conditional_print(f"Passed: {name} Test\nTook: {round(execution_time, 2)}s\n")


def test_search(anime_title: str, site: str) -> list[list[str]]:
    test_name = "Search"
    test_start(test_name)
    run_time_getter = get_run_time_later()
    if site == PAHE:
        results = pahe.search(anime_title)
    else:
        results = gogo.search(anime_title)
    rt = run_time_getter()
    if not results:
        fail_if_list_is_empty(results, test_name, "results", rt)
    pass_test(test_name, rt)
    test_name = "Parse search results"
    test_start(test_name)
    c = time.time()
    parsed_results: list[list[str]] = []
    if site == PAHE:
        parsed_results = [
            list(pahe.extract_anime_title_page_link_and_id(r))
            for r in cast(list[dict[str, str]], results)
        ]
    else:
        for title, page_link in cast(list[tuple[str, str]], results):
            parsed_results.append([title, page_link])
    run_timer = time.time() - c
    if not parsed_results:
        fail_test(test_name, "List of parsed results", "Empty list", run_timer)
    pass_test(test_name, run_timer)
    return parsed_results


def get_run_time_later() -> Callable[[], float]:
    c = time.time()
    return lambda: time.time() - c


def test_check_results_for_anime(
    anime_title: str,
    results: list[list[str]] | list[list[str]],
) -> list[str] | None:
    test_name = f"Matching results to {anime_title}"
    test_start(test_name)
    run_time = get_run_time_later()
    query = strip_title(anime_title, True).lower()
    for r in results:
        title = r[0]
        if query == strip_title(title, True).lower():
            pass_test(test_name, run_time())
            return r
    fail_test(
        test_name,
        "A perfect match",
        "No match found",
        run_time(),
        f"Anime title was: {anime_title}\nSearch results were: {results}",
    )


def test_get_metadata(
    site: str, target_result: list[str]
) -> tuple[AnimeMetadata, bytes]:
    test_name = "Get Metadata"
    test_start(test_name)
    run_time = get_run_time_later()
    page_content = b""
    if site == PAHE:
        target_result = cast(list[str], target_result)
        metadata = pahe.get_anime_metadata(target_result[2])
    else:
        page_content, target_result[1] = gogo.get_anime_page_content(target_result[1])
        metadata = gogo.extract_anime_metadata(page_content)
    pass_test(test_name, run_time())
    return metadata, page_content


def test_get_episode_page_links(
    anime_id: str, anime_page_link: str, start_episode: int, end_episode: int
) -> list[str]:
    test_name = "Get Episode page links"
    test_start(test_name)
    run_time = get_run_time_later()
    test_variables = f"Anime ID: {anime_id}"
    anime_id = cast(str, anime_id)
    episode_pages_info = pahe.get_episode_pages_info(
        anime_page_link, start_episode, end_episode
    )
    episode_page_links = pahe.GetEpisodePageLinks().get_episode_page_links(
        start_episode,
        end_episode,
        episode_pages_info,
        anime_page_link,
        anime_id,
    )
    rt = run_time()
    fail_if_list_is_empty(
        episode_page_links, test_name, "Episode page links", rt, test_variables
    )
    pass_test(test_name, run_time())
    return episode_page_links


def test_get_download_page_links(
    site: str,
    quality: str,
    sub_or_dub: str,
    eps_page_links: list[str],
    start_episode: int,
    end_episode: int,
    anime_id: int,
) -> tuple[list[str], list[str]]:
    test_name = "Get Download page links"
    test_start(test_name)
    run_time_getter = get_run_time_later()
    if site == PAHE:
        (
            pahewin_page,
            pahewin_info,
        ) = pahe.GetPahewinPageLinks().get_pahewin_page_links_and_info(eps_page_links)
        download_page_links, download_info = pahe.bind_sub_or_dub_to_link_info(
            sub_or_dub, pahewin_page, pahewin_info
        )
        fail_if_list_is_empty(
            download_page_links[0],
            test_name,
            f"Bound to {sub_or_dub} download page links",
            run_time_getter(),
            f"Episode page links were: {eps_page_links}\nPahewin page links were: {pahewin_page}",
        )
        download_page_links, download_info = pahe.bind_quality_to_link_info(
            quality, download_page_links, download_info
        )
        rt = run_time_getter()
        fail_if_list_is_empty(
            download_page_links,
            test_name,
            "Download page links",
            rt,
            f"Episode page links were: {eps_page_links}",
        )
    else:
        download_page_links = gogo.get_download_page_links(
            start_episode, end_episode, anime_id
        )
        download_info = []
        rt = run_time_getter()
        fail_if_list_is_empty(
            download_page_links,
            test_name,
            "Download page links",
            rt,
            f"Anime ID was: {anime_id}\nStart Episode was: {start_episode}\nEnd Episode was: {end_episode}",
        )
    pass_test(test_name, run_time_getter())
    return download_page_links, download_info


def fail_if_list_is_empty(
    array: list[Any],
    test_name: str,
    list_of: str,
    execution_time: float,
    test_variables: str | None = None,
):
    if not array:
        fail_test(
            test_name,
            f"List of {list_of}",
            "Empty list",
            execution_time,
            test_variables,
        )


def test_getting_direct_download_links(
    site: str, download_page_links: list[str], quality: str, verbose: bool
) -> list[str]:
    test_name = "Get Direct download links"
    test_start(test_name)
    run_time_getter = get_run_time_later()
    ddls: list[str] = []
    if site == PAHE:
        ddls = pahe.GetDirectDownloadLinks().get_direct_download_links(
            download_page_links
        )
    else:
        ddls, download_sizes = gogo.GetDirectDownloadLinks().get_direct_download_links(
            download_page_links, quality
        )
        total_download_size = sum(download_sizes) // IBYTES_TO_MBS_DIVISOR
        if verbose:
            print(f"Total download size is: {total_download_size} MB")
    rt = run_time_getter()
    fail_if_list_is_empty(
        ddls,
        test_name,
        "direct download links",
        rt,
        f"Download page links were: {download_page_links}",
    )
    pass_test(test_name, rt)
    return ddls


def test_getting_hls_links(episode_page_links: list[str]) -> list[str]:
    test_name = "Get HLS links"
    test_start(test_name)
    runtime_getter = get_run_time_later()
    hls_links = gogo.GetHlsLinks().get_hls_links(episode_page_links)
    rt = runtime_getter()
    fail_if_list_is_empty(
        hls_links,
        test_name,
        "HLS links",
        rt,
        f"Episode page links were: {episode_page_links}",
    )
    pass_test(test_name, rt)
    return hls_links


def test_matching_quality_to_hls_links(hls_links: list[str], quality: str) -> list[str]:
    test_name = "Match Quality to HLS links"
    test_start(test_name)
    runtime_getter = get_run_time_later()
    hls_links = gogo.GetHlsMatchedQualityLinks().get_hls_matched_quality_links(
        hls_links, quality
    )
    rt = runtime_getter()
    fail_if_list_is_empty(
        hls_links,
        test_name,
        "Matched HLS links",
        rt,
        f"Original HLS links were: {hls_links}",
    )
    pass_test(test_name, rt)
    return hls_links


def test_getting_segments_urls(matched_hls_links: list[str]) -> list[list[str]]:
    test_name = "Get Segments URLs"
    test_start(test_name)
    runtime_getter = get_run_time_later()
    segs_urls = gogo.GetHlsSegmentsUrls().get_hls_segments_urls(matched_hls_links)
    rt = runtime_getter()
    fail_if_list_is_empty(
        segs_urls,
        test_name,
        "List containing List of Segment URLs",
        rt,
        f"Matched HLS links were: {matched_hls_links}",
    )
    fail_if_list_is_empty(
        segs_urls[0],
        test_name,
        "Segment URLs",
        rt,
        f"Matched HLS links were: {matched_hls_links}",
    )
    pass_test(test_name, runtime_getter())
    return segs_urls


def test_downloading(
    anime_title: str,
    ddls_or_segs_urls: list[str] | list[list[str]],
    is_hls_download: bool,
    start_eps: int,
    end_eps: int,
    download_folder: str,
):
    test_name = "Downloading"
    test_start(test_name)
    if not os.path.isdir(download_folder):
        os.makedirs(download_folder)
    runtime_getter = get_run_time_later()
    conditional_print(f"Folder: {download_folder}")
    for eps_no, ddl_or_seg_urls in zip(
        range(start_eps, end_eps + 1), ddls_or_segs_urls
    ):
        runtime_getter = get_run_time_later()
        eps_number = str(eps_no).zfill(2)
        eps_title = f"{anime_title} E{eps_number}"
        inner_test_name = f"Downloading {eps_title}"
        test_start(test_name)
        if is_hls_download:
            download_size = len(ddl_or_seg_urls)
        else:
            download_size, ddl_or_seg_urls = Download.get_total_download_size(
                cast(str, ddl_or_seg_urls)
            )
        Download(
            ddl_or_seg_urls,
            eps_title,
            download_folder,
            download_size,
            is_hls_download=is_hls_download,
        ).start_download()
        full_name = f"{eps_title}.mp4"
        rt = runtime_getter()
        downloaded_file = os.path.join(download_folder, full_name)
        if os.path.isfile(downloaded_file):
            pass_test(inner_test_name, rt)
            os.unlink(downloaded_file)
            continue
        test_variables = (
            f"HLS links were: {ddls_or_segs_urls}"
            if is_hls_download
            else f"DDLs were: {ddls_or_segs_urls}"
        )
        fail_test(
            inner_test_name,
            f"{full_name} file in {download_folder}",
            "Didn't find the file",
            rt,
            test_variables,
        )

    rt = runtime_getter()
    pass_test(test_name, rt)
    shutil.rmtree(download_folder)


class ArgParser:
    arg_site = ("--site", "-s")
    arg_verbose = ("--verbose", "-v")
    arg_title = ("--title", "-t")
    arg_quality = ("--quality", "-q")
    arg_sub_or_dub = ("--sub_or_dub", "-sd")
    arg_path = ("--path", "-p")
    arg_help = ("--help", "-h")
    arg_silent = ("--silent", "-s")

    def __init__(self, args: list[str]):
        self.passed_args = args[1:]
        global SILENT
        SILENT = self.arg_in_group_was_passed(self.arg_silent)
        if not self.arg_in_group_was_passed(COMMANDS):
            print("No valid Command specified")
            self.print_usage()
        if self.arg_in_group_was_passed(self.arg_help):
            self.print_usage()

        self.site = self.arg_value_finder(args, self.arg_site, DEFAULT_SITE)
        self.validate_arg_value(self.arg_site, (PAHE, GOGO), self.site)

        self.anime_title = self.arg_value_finder(
            args, self.arg_title, DEFAULT_ANIME_TITLE
        )
        self.anime_title = strip_title(self.anime_title)

        self.verbose = self.arg_in_group_was_passed(self.arg_verbose)
        self.start_eps, self.end_eps = self.parse_start_and_end_episode(args)

        self.quality = self.arg_value_finder(args, self.arg_quality, DEFAULT_QUALITY)
        self.validate_arg_value(
            self.arg_quality, ("360p", "480p", "720p", "1080p"), self.quality
        )

        self.sub_or_dub = self.arg_value_finder(
            args, self.arg_sub_or_dub, DEFAULT_SUB_OR_DUB
        )
        self.validate_arg_value(self.arg_sub_or_dub, ("sub", "dub"), self.sub_or_dub)

        self.path = self.arg_value_finder(
            args, self.arg_path, DEFAULT_DOWNLOAD_FOLDER_PATH
        )

    def print_usage(self):
        usage = """
        Usage: scrapers.test [COMMAND/TEST] [OPTIONS]

        Commands/Tests:
        search                  Test searching
        dub_available           Test dub availablity checking
        metadata                Test getting metadata
        episode_page            Test getting episode page links (pahe only)
        download_page           Test getting download page links
        download_size           Test extraction (pahe) of total download size from download info
        direct_links            Test getting direct download links
        hls_links               Test getting hls links
        match_links             Test matching hls links to user quality
        segments_urls           Test getting segments urls
        download                Test downloading (Implicitly performs all tests)
        all                     Perform all tests (alias to download). Only performs all tests for one site, defaults to pahe
        

        Options:
        --site, -s              Specify the site (i.e., pahe, gogo). Default: pahe
        --title, -t             Specify the anime title. Default: "Boku no Hero Academia"
        --quality, -q           Specify the video quality (i.e., 360p, 480p, 720p, 1080p). Default: 360p
        --sub_or_dub, -sd       Specify sub or dub. Default: sub
        --path, -p              Specify the download folder path. Default: ./src/test-downloads
        --start_episode, -se    Specify the starting episode number. Default: 1
        --end_episode, -ee      Specify the ending episode number. Default: 2
        --verbose, -v           Enable verbose mode for more detailed explanations of test results
        --silent, s             Only output critical information
        --help, -h              Display this help message


        Example:
        scrapers.test --site pahe --title "Naruto" --quality 720p --sub_or_dub sub

        Note: Tests are hierarchial, if for example episode_page is the command/test to run, both search and metadata test will be performed cause they are required, in order to get episode_page links
        Note: Tests are site specific, the all command does not perform tests for each site it implicitly defaults to pahe
        """
        print(usage)
        sys.exit(0)

    def arg_in_group_was_passed(self, arg_group: tuple | list[str]):
        return any(arg in self.passed_args for arg in arg_group)

    def parse_start_and_end_episode(self, args: list[str]) -> tuple[int, int]:
        s = ("--start_episode", "-se")
        start_str = self.arg_value_finder(args, s, DEFAULT_START_EPISODE)
        e = ("--end_episode", "-ee")
        end_str = self.arg_value_finder(args, e, DEFAULT_END_EPISODE)

        def check_if_digit(x, v):
            return (
                self.invalid_usage(f"{x} MUST be a number") if not v.isdigit() else None
            )

        def check_if_greater_than_zero(x, v):
            self.invalid_usage(f"{x} MUST be greater than zero") if v <= 0 else None

        check_if_digit(s, start_str)
        check_if_digit(e, end_str)
        start_eps = int(start_str)
        end_eps = int(end_str)
        check_if_greater_than_zero(s, start_eps)
        check_if_greater_than_zero(e, end_eps)
        if start_eps > end_eps:
            self.invalid_usage(f"{s} CAN'T be greater than {e}")
        return start_eps, end_eps

    def invalid_usage(self, usage: str):
        print(f"Invalid Usage:\n{usage}")
        sys.exit(0)

    def validate_arg_value(self, arg: tuple[str, str], can_bes: tuple, passed: str):
        if passed not in can_bes:
            can_be = " or ".join(can_bes)
            usage = f"{arg} MUST be either {can_be}. Got '{passed}' instead"
            self.invalid_usage(usage)

    def arg_value_finder(
        self, args: list[str], target_args: tuple[str, str], default: str | None = None
    ) -> str:  # type: ignore
        for arg in target_args:
            try:
                idx = args.index(arg)
                return args[idx + 1]
            except ValueError:
                pass
        if default:
            conditional_print(f"Using default {target_args}: {default}")
            return default
        self.invalid_usage(f"Expected: {target_args}")


def test_dub_available(site: str, target_result: list[str]) -> tuple[bool, str]:
    test_name = "Dub availability checking"
    test_start(test_name)
    runtime_getter = get_run_time_later()
    dub_link = ""
    if site == PAHE:
        dub_available = pahe.dub_available(target_result[1], target_result[2])
    else:
        dub_available, dub_link = gogo.dub_availability_and_link(target_result[0])
    rt = runtime_getter()
    if not isinstance(dub_available, bool):
        fail_test(
            test_name,
            "Boolean value",
            type(dub_available),
            rt,
            f"The returned value was: {dub_available}",
        )
    pass_test(test_name, rt)
    return dub_available, dub_link


def run_tests(args: ArgParser):
    was_hls = False
    if args.arg_in_group_was_passed(COMMANDS):
        results = test_search(args.anime_title, args.site)
        if args.verbose:
            conditional_print(f"Search Results: {results}\n")
        target_result = cast(
            list[str],
            test_check_results_for_anime(args.anime_title, results),
        )
        if args.verbose:
            conditional_print(f"Target Result: {target_result}\n")
        COMMANDS.remove("search")
        if args.arg_in_group_was_passed(COMMANDS):
            dub_available, dub_link = test_dub_available(args.site, target_result)

            if args.verbose:
                conditional_print("Dub available") if dub_available else print(
                    "No Dub available"
                )
            COMMANDS.remove("dub_available")

            def print_metadata(metadata: AnimeMetadata):
                conditional_print(
                    f"Metadata:\nPoster Url: {metadata.poster_url}\nSummary: {metadata.summary[:100]}.. .\nEpisode Count: {metadata.episode_count}\nAiring Status: {metadata.airing_status}\nGenres: {metadata.genres}\nRelease Year: {metadata.release_year}\n"
                )

            if args.arg_in_group_was_passed(COMMANDS):
                metadata, page_content = test_get_metadata(args.site, target_result)
                if args.verbose:
                    if args.site == GOGO:
                        conditional_print("Sub metadata")

                    print_metadata(metadata)
                COMMANDS.remove("metadata")
                if args.sub_or_dub == "dub" and not dub_available:
                    print("Couldn't find Dub for the anime on the specified site")
                    return
                if args.arg_in_group_was_passed(COMMANDS):
                    if args.end_eps > metadata.episode_count:
                        return print(
                            f"The chosen target anime has {metadata.episode_count} episodes yet you specified the ('--end_episode', '-ee') as {args.end_eps}"
                        )
                    elif args.site == GOGO and dub_available:
                        dub_metadata, dub_page_content = test_get_metadata(
                            args.site,
                            ["", dub_link],
                        )
                        if args.sub_or_dub == "dub":
                            metadata, page_content = dub_metadata, dub_page_content
                        if args.verbose:
                            conditional_print("Dub metadata")
                            print_metadata(dub_metadata)
                    if args.site == PAHE:
                        episode_page_links = test_get_episode_page_links(
                            target_result[2],
                            target_result[1],
                            args.start_eps,
                            args.end_eps,
                        )
                        if args.verbose:
                            conditional_print(
                                f"Episode page links: {episode_page_links}\n"
                            )
                    else:
                        episode_page_links = []
                    COMMANDS.remove("episode_page")
                    if args.arg_in_group_was_passed(COMMANDS):
                        anime_id = (
                            gogo.extract_anime_id(page_content)
                            if args.site == GOGO
                            else 0
                        )
                        (
                            download_page_links,
                            download_info,
                        ) = test_get_download_page_links(
                            args.site,
                            args.quality,
                            args.sub_or_dub,
                            episode_page_links,
                            args.start_eps,
                            args.end_eps,
                            anime_id,
                        )
                        if args.verbose:
                            conditional_print(
                                f"Download page links: {download_page_links}\n"
                            )
                        COMMANDS.remove("download_page")
                        if args.site == PAHE and args.arg_in_group_was_passed(
                            ["download_size"]
                        ):
                            test_name = "Total Download size"
                            test_start(test_name)
                            runtime_getter = get_run_time_later()
                            total_download_size = pahe.calculate_total_download_size(
                                download_info
                            )
                            rt = runtime_getter()
                            if not isinstance(total_download_size, int):
                                fail_test(
                                    test_name,
                                    "An integer",
                                    type(total_download_size),
                                    rt,
                                    f"Bound download infos were: {download_info}",
                                )
                            pass_test(test_name, rt)
                            if args.verbose:
                                conditional_print(
                                    f"Total download size is: {total_download_size} MB"
                                )
                            COMMANDS.remove("download_size")
                        # HLS testing pipeine
                        if args.site == GOGO and args.arg_in_group_was_passed(
                            ["hls_links", "match_links", "segments_urls", "all"]
                        ):
                            hls_links = test_getting_hls_links(download_page_links)
                            if args.verbose:
                                conditional_print(f"HLS links: {hls_links}\n")
                            COMMANDS.remove("hls_links")
                            was_hls = True
                            if args.arg_in_group_was_passed(
                                ["segments_urls", "match_links", "all"]
                            ):
                                matched_links = test_matching_quality_to_hls_links(
                                    hls_links, args.quality
                                )
                                if args.verbose:
                                    conditional_print(
                                        f"Matched Quality links: {matched_links}\n"
                                    )
                                COMMANDS.remove("match_links")
                                if args.arg_in_group_was_passed(
                                    ["segments_urls", "all"]
                                ):
                                    segs_urls = test_getting_segments_urls(
                                        matched_links
                                    )
                                    if args.verbose:
                                        conditional_print(
                                            f"Segments URLs: {segs_urls}\n"
                                        )
                                    COMMANDS.remove("segments_urls")

                                    if args.arg_in_group_was_passed(
                                        ["download", "all"]
                                    ):
                                        test_downloading(
                                            args.anime_title,
                                            segs_urls,
                                            True,
                                            args.start_eps,
                                            args.end_eps,
                                            args.path,
                                        )
                                        COMMANDS.remove("download")
                        if args.arg_in_group_was_passed(["direct_links", "all"]):
                            direct_download_links = test_getting_direct_download_links(
                                args.site,
                                download_page_links,
                                args.quality,
                                args.verbose,
                            )
                            if args.verbose:
                                conditional_print(f"DDLs: {direct_download_links}\n")
                            COMMANDS.remove("direct_links")
                            if args.arg_in_group_was_passed(["download", "all"]):
                                test_downloading(
                                    args.anime_title,
                                    direct_download_links,
                                    False,
                                    args.start_eps,
                                    args.end_eps,
                                    args.path,
                                )
                                COMMANDS.remove("download")
    if args.site == PAHE:
        return print(f"Specified {PAHE} tests passed")
    if was_hls:
        return print(f"Specified {GOGO} HLS tests passed")
    return print(f"Specified {GOGO} NORM tests passed")


if __name__ == "__main__":
    args = ArgParser(sys.argv)
    run_tests(args)
