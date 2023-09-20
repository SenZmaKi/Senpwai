from shared.app_and_scraper_shared import Download, sanitise_title, AnimeMetadata
import os
from scrapers import pahe, gogo
from typing import cast, Callable, Any
from time import time as current_time
import sys
from bs4 import BeautifulSoup
from selenium.common.exceptions import WebDriverException

if getattr(sys, 'frozen', False):
    base_directory = os.path.dirname(sys.executable)
else:
    base_directory = os.path.dirname(os.path.realpath('__file__'))

PAHE = pahe.PAHE
GOGO = gogo.GOGO

DEFAULT_ANIME_TITLE = 'Senyuu'
DEFAULT_QUALITY = '360p'
DEFAULT_START_EPISODE = '1'
DEFAULT_END_EPISODE = '2'
DEFAULT_SUB_OR_DUB = 'sub'
DEFAULT_SITE = 'pahe'
DEFAULT_DOWNLOAD_FOLDER_PATH = os.path.join(base_directory, 'test-downloads')
DEFAULT_BROWSER = gogo.CHROME
DEFAULT_VERBOSE = False
COMMANDS = ['search', 'dub_available', 'metadata', 'episode_page', 'download_page', 'download_size',
            'direct_links', 'hls_links', 'download', 'all']


def test_start(name: str):
    print(f'Running: {name} Test')


def fail_test(name: str, expected: Any, got: Any, execution_time: float, exit_code: int = 0, test_variables: str | None = None, exit_on_fail: bool = True):
    msg = f'Failed: {name} Test\nExpected: {expected}\nGot: {got}\nExecution time: {round(execution_time, 2)}s'
    if test_variables:
        msg = f'{msg}\nTest Variables:\n{test_variables}'
    print(msg)
    if exit_on_fail:
        sys.exit(exit_code)


def pass_test(name: str, execution_time: float):
    print(f'Passed: {name} Test\nTook: {round(execution_time, 2)}s\n')


def test_search(anime_title: str, site: str) -> list[tuple[str, str]] | list[tuple[str, str, str]]:
    test_name = 'Search'
    test_start(test_name)
    run_time_getter = get_run_time_later()
    if site == PAHE:
        results = pahe.search(anime_title)
    else:
        results = gogo.search(anime_title)
    rt = run_time_getter()
    if results == []:
        fail_if_list_is_empty(results, test_name, 'results', rt, 23)
    pass_test(test_name, rt)
    test_name = 'Parse search results'
    test_start(test_name)
    c = current_time()
    parsed_results: list[tuple[str, str]] | list[tuple[str, str, str]] = []
    if site == PAHE:
        parsed_results = [pahe.extract_anime_title_page_link_and_id(
            r) for r in cast(list[dict[str, str]], results)]
    else:
        parsed_results = cast(list[tuple[str, str]], parsed_results)
        for r in cast(list[BeautifulSoup], results):
            if r:
                t, p = gogo.extract_anime_title_and_page_link(r)
                if t and p:
                    parsed_results.append((t, p))
    run_timer = current_time() - c
    if parsed_results == []:
        fail_test(test_name, 'List of parsed results',
                  'Empty list', run_timer, 2)
    pass_test(test_name, run_timer)
    return parsed_results


def get_run_time_later() -> Callable[[], float]:
    c = current_time()
    return lambda: current_time() - c


def test_check_results_for_anime(anime_title: str, results: list[tuple[str, str]] | list[tuple[str, str, str]], site: str) -> tuple[str, str] | tuple[str, str, str] | None:
    test_name = f'Matching results to {anime_title}'
    test_start(test_name)
    run_time = get_run_time_later()
    query = sanitise_title(anime_title, True).lower()
    for r in results:
        title = r[0]
        if query == sanitise_title(title, True).lower():
            pass_test(test_name, run_time())
            return r
    fail_test(test_name, 'A perfect match', 'No match found', run_time(
    ), 3, f'Anime title was: {anime_title}\nSearch results were: {results}')


def test_get_metadata(site: str, target_result: tuple[str, str] | tuple[str, str, str]) -> AnimeMetadata:
    test_name = 'Get Metadata'
    test_start(test_name)
    run_time = get_run_time_later()
    if site == PAHE:
        target_result = cast(tuple[str, str, str], target_result)
        metadata = pahe.get_anime_metadata(target_result[2])
    else:
        page_content = gogo.get_anime_page_content(target_result[1])
        metadata = gogo.extract_anime_metadata(page_content)
    pass_test(test_name, run_time())
    return metadata


def test_get_episode_page_links(site: str, anime_id: str | None, anime_page_link: str, start_episode: int, end_episode: int) -> list[str]:
    test_name = 'Get Episode page links'
    test_start(test_name)
    run_time = get_run_time_later()
    if site == PAHE:
        test_variables = f'Anime ID: {anime_id}'
        anime_id = cast(str, anime_id)
        episode_page_links = pahe.GetEpisodePageLinks().get_episode_page_links(
            start_episode, end_episode, anime_page_link, anime_id)
    else:
        gogo_anime_id = gogo.extract_anime_id(
            gogo.get_anime_page_content(anime_page_link))
        test_variables = f'Anime ID: {anime_id}\nAnime page link: {anime_page_link}'
        episode_page_links = gogo.get_episode_page_links(
            start_episode, end_episode, gogo_anime_id)
    rt = run_time()
    fail_if_list_is_empty(episode_page_links, test_name,
                          'Episode page links', rt, 4, test_variables)
    pass_test(test_name, run_time())
    return episode_page_links


def test_get_download_page_links(site: str, quality: str, sub_or_dub: str, eps_page_links: list[str]) -> tuple[list[str], list[str]]:
    test_name = 'Get Download page links'
    test_start(test_name)
    run_time_getter = get_run_time_later()
    if site == PAHE:
        pahewin_page, pahewin_info = pahe.GetPahewinDownloadPage(
        ).get_pahewin_download_page_links_and_info(eps_page_links)
        download_page_links, download_info = pahe.bind_sub_or_dub_to_link_info(
            sub_or_dub, pahewin_page, pahewin_info)
        fail_if_list_is_empty(download_page_links[0], test_name, f'Bound to {sub_or_dub} download page links', run_time_getter(
        ), 69, f'Episode page links were: {eps_page_links}\nPahewin page links were: {pahewin_page}')
        download_page_links, download_info = pahe.bind_quality_to_link_info(
            quality, download_page_links, download_info)
    else:
        download_page_links = gogo.GetDownloadPageLinks(
        ).get_download_page_links(eps_page_links)
        download_info = []
    rt = run_time_getter()
    fail_if_list_is_empty(download_page_links, test_name, 'Download page links',
                          rt, 7, f'Episode page links were: {eps_page_links}')
    pass_test(test_name, run_time_getter())
    return download_page_links, download_info


def fail_if_list_is_empty(array: list[Any], test_name: str, list_of: str, execution_time: float, exit_code: int, test_variables: str | None = None):
    if array == []:
        fail_test(test_name, f'List of {list_of}', 'Empty list',
                  execution_time, exit_code, test_variables)


def fail_status(msg: str):
    print(f'Fail status: {msg}')


def test_getting_direct_download_links(site: str, download_page_links: list[str], quality: str, browser: str) -> list[str]:
    test_name = 'Get Direct download links'
    test_start(test_name)
    run_time_getter = get_run_time_later()
    ddls: list[str] = []
    if site == PAHE:
        ddls = pahe.GetDirectDownloadLinks().get_direct_download_links(download_page_links)
    else:
        gogo.DRIVER_MANAGER = gogo.DriverManager()
        try:
            ddls = gogo.GetDirectDownloadLinks().get_direct_download_links(
                download_page_links, quality, gogo.DRIVER_MANAGER.setup_driver(browser, False))
            gogo.DRIVER_MANAGER.close_driver()
        except Exception as e:
            if isinstance(e, TimeoutError):
                fail_status('Captcha block detected')
            elif isinstance(e, WebDriverException):
                fail_status(f'{browser.capitalize} not found on the system')
            else:
                raise e
    rt = run_time_getter()
    fail_if_list_is_empty(ddls, test_name, 'direct download links',
                          rt, 8, f'Download page links were: {download_page_links}')
    pass_test(test_name, rt)
    return ddls


def test_getting_hls_links(episode_page_links: list[str]) -> list[str]:
    test_name = 'Get HLS links'
    test_start(test_name)
    runtime_getter = get_run_time_later()
    hls_links = gogo.GetHlsLinks().get_hls_links(episode_page_links)
    rt = runtime_getter()
    fail_if_list_is_empty(hls_links, test_name, 'HLS links',
                          rt, 10, f'Episode page links were: {episode_page_links}')
    pass_test(test_name, rt)
    return hls_links


def test_downloading(anime_title: str, direct_download_links: list[str], is_hls_download: bool, quality: str, start_eps: int, end_eps: int, path: str):
    test_name = 'Downloading'
    test_start(test_name)
    if not os.path.isdir(path):
        os.makedirs(path)
    runtime_getter = get_run_time_later()
    print(f'Folder: {path}')
    for eps_no, link in zip(range(start_eps, end_eps+1), direct_download_links):
        runtime_getter = get_run_time_later()
        eps_number = str(eps_no).zfill(2)
        eps_title = f'{anime_title} E{eps_number}'
        test_name = f'Downloading {eps_title}'
        test_start(test_name)
        Download(link, eps_title,
                 path, is_hls_download=is_hls_download, hls_quality=quality).start_download()
        full_name = f'{eps_title}.mp4'
        rt = runtime_getter()
        if os.path.isfile(os.path.join(path, full_name)):
            pass_test(test_name, rt)
            continue
        test_variables = f'HLS links were: {direct_download_links}' if is_hls_download else f'DDLs were: {direct_download_links}'
        fail_test(test_name, f'{full_name} file in {path}',
                  'Didn\'t find the file', rt, 10, test_variables)

    rt = runtime_getter()
    pass_test(test_name, rt)


class ArgParser():
    arg_site = ('--site', '-s')
    arg_verbose = ('--verbose', '-v')
    arg_title = ('--title', '-t')
    arg_quality = ('--quality', '-q')
    arg_sub_or_dub = ('--sub_or_dub', '-sd')
    arg_path = ('--path', '-p')
    arg_browser = ('--browser', '-b')
    arg_help = ('--help', '-h')

    def __init__(self, args: list[str]):
        self.passed_args = args[1:]
        if not self.arg_in_group_was_passed(COMMANDS):
            print('No valid Command specified')
            self.print_usage()
        if self.arg_in_group_was_passed(self.arg_help):
            self.print_usage()

        self.site = self.arg_value_finder(args, self.arg_site, DEFAULT_SITE)
        self.validate_arg_value(self.arg_site, (PAHE, GOGO), self.site)

        self.anime_title = self.arg_value_finder(
            args, self.arg_title, DEFAULT_ANIME_TITLE)
        self.anime_title = sanitise_title(self.anime_title)

        if self.arg_in_group_was_passed(self.arg_verbose):
            self.verbose = True
        else:
            self.verbose = False

        self.start_eps, self.end_eps = self.parse_start_and_end_episode(args)

        self.quality = self.arg_value_finder(
            args, self.arg_quality, DEFAULT_QUALITY)
        self.validate_arg_value(
            self.arg_quality, ('360p', '480p', '720p', '1080p'), self.quality)

        self.sub_or_dub = self.arg_value_finder(
            args, self.arg_sub_or_dub, DEFAULT_SUB_OR_DUB)
        self.validate_arg_value(
            self.arg_sub_or_dub, ('sub', 'dub'), self.sub_or_dub)

        self.path = self.arg_value_finder(
            args, self.arg_path, DEFAULT_DOWNLOAD_FOLDER_PATH)

        self.browser = self.arg_value_finder(
            args, self.arg_browser, DEFAULT_BROWSER)
        self.validate_arg_value(
            self.arg_browser, (gogo.CHROME, gogo.EDGE, gogo.FIREFOX), self.browser)

    def print_usage(self):
        usage = """
        Usage: scrapers.test [COMMAND/TEST] [OPTIONS]

        Commands/Tests:
        search                  Test searching
        dub_available           Test dub availablity checking
        metadata                Test getting metadata
        episode_page            Test getting episode page links
        download_page           Test getting download page links
        download_size           Test extraction (pahe)/ getting (gogo) of total download size
        direct_links            Test getting direct download links
        hls_links               Test getting hls links
        download                Test downloading (Implicitly performs all tests)
        all                     Perform all test (alias to download). Only performs all tests for one site, defaults to pahe
        

        Options:
        --site, -s              Specify the site (i.e., pahe, gogo). Default: pahe
        --title, -t             Specify the anime title. Default: Senyuu
        --quality, -q           Specify the video quality (i.e., 360p, 480p, 720p, 1080p). Default: 360p
        --sub_or_dub, -sd       Specify sub or dub. Default: sub
        --path, -p              Specify the download folder path. Default: ./src/test-downloads
        --browser, -b           Specify the ddl scraping browser (i.e., chrome, edge, firefox). Default: chrome
        --start_episode, -se    Specify the starting episode number. Default: 1
        --end_episode, -ee      Specify the ending episode number. Default: 2
        --verbose, -v           Enable verbose mode for more detailed explanations of test results
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
        s = ('--start_episode', '-se')
        start_str = self.arg_value_finder(args, s, DEFAULT_START_EPISODE)
        e = ('--end_episode', '-ee')
        end_str = self.arg_value_finder(args, e, DEFAULT_END_EPISODE)

        def check_if_digit(x, v): return self.invalid_usage(
            f'{x} MUST be a number') if not v.isdigit() else None

        def check_if_greater_than_zero(x, v): self.invalid_usage(
            f'{x} MUST be greater than zero') if v <= 0 else None
        check_if_digit(s, start_str)
        check_if_digit(e, end_str)
        start_eps = int(start_str)
        end_eps = int(end_str)
        check_if_greater_than_zero(s, start_eps)
        check_if_greater_than_zero(e, end_eps)
        if start_eps > end_eps:
            self.invalid_usage(f'{s} CAN\'T be greater than {e}')
        return start_eps, end_eps

    def invalid_usage(self, usage: str):
        print(f'Invalid Usage:\n{usage}')
        sys.exit(0)

    def validate_arg_value(self, arg: tuple[str, str], can_bes: tuple, passed: str):
        if passed not in can_bes:
            can_be = ' or '.join(can_bes)
            usage = f'{arg} MUST be either {can_be}. Got \'{passed}\' instead'
            self.invalid_usage(usage)

    def arg_value_finder(self, args: list[str], target_args: tuple[str, str], default: str | None = None) -> str: # type: ignore
        for arg in target_args:
            try:
                idx = args.index(arg)
                return args[idx + 1]
            except ValueError:
                pass
        if default:
            print(f'Using default {target_args}: {default}')
            return default
        self.invalid_usage(f'Expected: {target_args}')

def test_dub_available(site: str, target_result: tuple[str, str] | tuple[str, str, str]) -> bool: # type: ignore
    test_name = 'Dub availability checking'
    test_start(test_name)
    runtime_getter = get_run_time_later()
    if site == PAHE:
        target_result = cast(tuple[str, str, str], target_result)
        dub_available = pahe.dub_available(target_result[1], target_result[2])
    else:
        dub_available = gogo.dub_available(target_result[0])
    rt = runtime_getter()
    if not isinstance(dub_available, bool):
        fail_test(test_name, 'Boolean value', type(dub_available), rt, 90, f'The returned value was: {dub_available}' )
    pass_test(test_name, rt)
    return dub_available

def run_tests(arg: ArgParser):
    if arg.arg_in_group_was_passed(COMMANDS):
        results = test_search(arg.anime_title, arg.site)
        if arg.verbose:
            print(f'Search Results: {results}\n')
        target_result = cast(tuple[str, str] | tuple[str, str, str], test_check_results_for_anime(
            arg.anime_title, results, arg.site))
        if arg.verbose:
            print(f'Target Result: {target_result}\n')
        COMMANDS.remove('search')
        if arg.arg_in_group_was_passed(COMMANDS):
            dub_available = test_dub_available(arg.site, target_result)
            if arg.verbose:
                print('Dub available') if dub_available else print('No Dub available')
            COMMANDS.remove('dub_available')
            if arg.arg_in_group_was_passed(COMMANDS):
                metadata = test_get_metadata(arg.site, target_result)
                if arg.verbose:
                    print(
                        f'Metadata:\nPoster Url: {metadata.poster_url}\nSummary: {metadata.summary[:100]}.. .\nEpisode Count: {metadata.episode_count}\nIs Ongoing: {metadata.is_ongoing}\nGenres: {metadata.genres}\nRelease Year: {metadata.release_year}\n')
                COMMANDS.remove('metadata')
                if arg.arg_in_group_was_passed(COMMANDS):
                    if (arg.end_eps > metadata.episode_count):
                        print(
                            f'The chosen target anime has {metadata.episode_count} episodes yet you specified the (\'--end_episode\', \'-ee\') as {arg.end_eps}')
                        sys.exit()
                    if args.sub_or_dub == 'dub' and not dub_available:
                        return print('Couldn\'t find Dub for the anime on the specified site')
                    if arg.site == PAHE:
                        target_result = cast(tuple[str, str, str], target_result)
                        episode_page_links = test_get_episode_page_links(
                            arg.site, target_result[2], target_result[1], arg.start_eps, arg.end_eps)
                    else:
                        target_result = cast(tuple[str, str], target_result)
                        episode_page_links = test_get_episode_page_links(
                            arg.site, '', target_result[1], arg.start_eps, arg.end_eps)
                    if arg.verbose:
                        print(f'Episode page links: {episode_page_links}\n')
                    COMMANDS.remove('episode_page')
                    if arg.arg_in_group_was_passed(COMMANDS):
                        download_page_links, download_info = test_get_download_page_links(
                            arg.site, arg.quality, arg.sub_or_dub, episode_page_links)
                        if arg.verbose:
                            print(f'Download page links: {download_page_links}\n')
                        COMMANDS.remove('download_page')
                        if arg.site == PAHE and arg.arg_in_group_was_passed(['download_size']):
                            test_name = 'Total Download size'
                            test_start(test_name)
                            runtime_getter = get_run_time_later()
                            total_download_size = pahe.calculate_total_download_size(download_info)
                            rt = runtime_getter()
                            if not isinstance(total_download_size, int):
                                fail_test(test_name, 'An integer', type(total_download_size), rt, 12, f'Bound download infos were: {download_info}')
                            pass_test(test_name, rt)
                            if args.verbose:
                                print(f'Total download size is: {total_download_size}')
                            COMMANDS.remove('download_size')
                        if arg.site == GOGO and arg.arg_in_group_was_passed(['hls_links', 'all']):
                            hls_links = test_getting_hls_links(episode_page_links)
                            if arg.verbose:
                                print(f'HLS links: {hls_links}\n')
                            COMMANDS.remove('hls_links')
                            if arg.arg_in_group_was_passed(COMMANDS):
                                test_downloading(arg.anime_title, hls_links,
                                                True, arg.quality, arg.start_eps, arg.end_eps, arg.path)
                        if arg.arg_in_group_was_passed(COMMANDS):
                            direct_download_links = test_getting_direct_download_links(
                                arg.site, download_page_links, arg.quality, arg.browser)
                            if arg.verbose:
                                print(f'DDLs: {direct_download_links}\n')
                            COMMANDS.remove('direct_links')
                            if arg.site == GOGO:
                                test_name = 'Download size'
                                test_start(test_name)
                                runtime_getter = get_run_time_later()
                                total_download_size = gogo.CalculateTotalDowloadSize().calculate_total_download_size(direct_download_links, in_megabytes=True)
                                rt = runtime_getter()
                                if not isinstance(total_download_size, int):
                                    fail_test(test_name, 'An integer', type(total_download_size),  rt, 9, f'DDLs were: {direct_download_links}')
                                pass_test(test_name, rt)
                                if args.verbose:
                                    print(f'Total download size is: {total_download_size}')

                            if arg.arg_in_group_was_passed(COMMANDS):
                                test_downloading(
                                    arg.anime_title, direct_download_links, False, arg.quality, arg.start_eps, arg.end_eps, arg.path)


if __name__ == '__main__':
    args = ArgParser(sys.argv)
    run_tests(args)
