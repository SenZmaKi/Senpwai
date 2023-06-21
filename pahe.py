import requests
import threading
from bs4 import BeautifulSoup, ResultSet, Tag
import json
import time
from tqdm import tqdm
import os
import re
from pathlib import Path

from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver import ChromeOptions
from selenium.webdriver import Chrome
from subprocess import CREATE_NO_WINDOW
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import StaleElementReferenceException
from selenium.common.exceptions import JavascriptException
import keyboard
from pygetwindow import getActiveWindowTitle

from ping3 import ping
from random import randint
from typing import Callable, cast

pahe_home_url = 'https://animepahe.ru'
api_url_extension = '/api?m='
parser = 'html.parser'
google_dot_com = 'google.com'

def search(keyword: str)->list[dict]:
    search_url = pahe_home_url+api_url_extension+'search&q='+keyword
    response = requests.get(search_url).content
    try:
        decoded = json.loads(response.decode('UTF-8'))
        return decoded['data']
    except (json.decoder.JSONDecodeError, KeyError):
        return []

def extract_anime_id_title_and_page_link(result: dict) -> tuple[str, str, str]:
    anime_id = result['session']
    title = result['title']
    page_link = f'{pahe_home_url}{api_url_extension}release&id={anime_id}&sort=episode_asc'
    return anime_id, title, page_link

def get_total_episode_page_count(anime_page_link: str)->int:
    page_url = f'{anime_page_link}&page={1}'
    response = requests.get(page_url).content
    decoded_anime_page = json.loads(response.decode('UTF-8'))
    total_episode_page_count: int = decoded_anime_page['last_page']
    return total_episode_page_count
# Issues GET requests together with the id of the anime to retrieve a list of the episode page links(not download links) 
def get_episode_page_links(start_episode: int, end_episode: int, anime_page_link: str, anime_id: str, progress_update_callback: Callable=lambda update: None, console_app=False) -> list[str]:
    page_url = anime_page_link
    episodes_data = []
    page_no = 1
    progress_bar = None if not console_app else tqdm(total=end_episode, desc=' Fetching episode page links', units='eps')
    while page_url != None:
        page_url = f'{anime_page_link}&page={page_no}'
        response = requests.get(page_url).content
        decoded_anime_page = json.loads(response.decode('UTF-8'))
        episodes_data+=decoded_anime_page['data']
        page_url = decoded_anime_page["next_page_url"]
        page_no+=1
        progress_update_callback(1)
        if progress_bar: progress_bar.update()
    episodes_data = list(filter(lambda episode: type(episode['episode']) != float, episodes_data)) # To avoid episodes like 7.5 and 5.5 cause they're usually just recaps
    episodes_data = episodes_data[start_episode-1: end_episode] # Take note cause indices work diff from episode numbers
    episode_sessions = [episode['session'] for episode in episodes_data]
    episode_links = [f'{pahe_home_url}/play/{anime_id}/{episode_session}' for episode_session in episode_sessions]
    return  episode_links

def get_download_page_links_and_info(episode_page_links: list[str], progress_update_callback: Callable = lambda x: None, console_app=False) -> tuple[list[list[str]], list[list[str]]]:
    progress_bar = None if not console_app else tqdm(total=len(episode_page_links), desc=' Fetching download page links', unit='eps')
    download_data: list[ResultSet[BeautifulSoup]] = []
    for idx, episode_page_link in enumerate(episode_page_links):
        episode_page = requests.get(episode_page_link).content
        soup = BeautifulSoup(episode_page, parser)
        download_data.append(soup.find_all('a', class_='dropdown-item', target='_blank'))
        progress_update_callback(1)
        if progress_bar: 
            progress_bar.update(idx+1 - progress_bar.n)
    if progress_bar:
        progress_bar.set_description(' Done')
        progress_bar.close()
    # Scrapes the download data of each episode and stores the links for the in a list which is contained in another list containing all episodes
    download_links: list[list[str]] = [[cast(str, download_link["href"]) for download_link in episode_data] for episode_data in download_data]
    # Scrapes the download data of each episode and stores the info for each quality and dub or sub in a list which is contained in another list containing all episodes
    download_info: list[list[str]] = [[episode_info.text.strip() for episode_info in episode_data] for episode_data in download_data] 
    return (download_links, download_info)   

def dub_available(anime_page_link: str, anime_id: str) -> bool :
    page_url = f'{anime_page_link}&page={1}'
    response = requests.get(page_url).content
    decoded_anime_page = json.loads(response.decode('UTF-8'))
    episodes_data = decoded_anime_page['data']
    episode_sessions = [episode['session'] for episode in episodes_data]
    episode_links = [f'{pahe_home_url}/play/{anime_id}/{episode_session}' for episode_session in episode_sessions]
    episode_links = [episode_links[-1]]
    _, download_info = get_download_page_links_and_info(episode_links)

    dub_pattern = r'eng$'
    for episode in download_info:
        found_dub = False
        for info in episode:
            if (match := re.search(dub_pattern, info)) and match:
                found_dub = True
        if not found_dub: return False
    return True


def bind_sub_or_dub_to_link_info(sub_or_dub: str, download_links: list[list[str]], download_info: list[list[str]]) -> tuple[list[list[str]], list[list[str]]] :
    bound_links: list[list[str]]= []
    bound_info: list[list[str]] = []
    dub_pattern = r'eng$'
    for idx_out, episode_info in enumerate(download_info):
        links: list[str] = []
        infos: list[str] = []
        for idx_in, info in enumerate(episode_info):
            match = re.search(dub_pattern, info)
            if sub_or_dub == 'dub' and match:
                links.append(download_links[idx_out][idx_in])
                infos.append(info)
            elif sub_or_dub == 'sub' and not match :
                links.append(download_links[idx_out][idx_in])
                infos.append(info)
        bound_links.append(links)
        bound_info.append(infos)
        
    return (bound_links, bound_info)


def bind_quality_to_link_info(quality: str, download_links: list[list[str]], download_info: list[list[str]]) -> tuple[list[str], list[str]]  :
    if quality == '480': quality = '360'
    quality_pattern = rf'\b({quality})p\b'
    bound_links: list[str] = []
    bound_info: list[str] = []
    for idx_out, episode_info in enumerate(download_info): 
        match: re.Match[str] | None = None
        for idx_in, info in enumerate(episode_info):
            match = re.search(quality_pattern, info)
            if match:
                bound_links.append(download_links[idx_out][idx_in])
                bound_info.append(info)
                break
        if not match:
            if quality == '360':
                bound_links.append(download_links[idx_out][0])
                bound_info.append(episode_info[0])
            elif quality == '1080' or quality == '720':
                bound_links.append(download_links[idx_out][-1])
                bound_info.append(episode_info[-1])
    return (bound_links, bound_info)

def get_download_sizes(episode_info: list[str]) -> tuple[int, list[int]]:
    pattern = r'\((.*?)MB\)'
    total_size = 0
    download_sizes: list[int] = []
    for episode in episode_info:
        match = cast(re.Match, re.search(pattern, episode))
        size = int(match.group(1))
        download_sizes.append(size)
        total_size+=size
    return (total_size, download_sizes)

def get_direct_download_links(episode_links: list[str], console_app=False) -> list[str]:
    progress_bar = None if not console_app else tqdm(total=len(episode_links), desc=' Fetching direct download links', unit='eps')
    direct_download_links: list[str] = []
    for idx, link in enumerate(episode_links):
        pahewin_page = requests.get(link).content
        soup = BeautifulSoup(pahewin_page, parser)
        download_link = cast(str, cast(Tag, soup.find("a", class_="btn btn-primary btn-block redirect"))["href"])
        direct_download_links.append(download_link)
        if progress_bar: progress_bar.update(idx+1 - progress_bar.n)
    if progress_bar:
        progress_bar.set_description(' Done')
        progress_bar.close()
    return direct_download_links


def set_up_headless_browser(download_folder: str) -> Chrome:
     # Configures the settings for the headless browser
            chrome_options = ChromeOptions()
            # chrome_options.add_argument("--headless=new")
            chrome_options.add_argument('--disable-extensions')
            chrome_options.add_argument('--disable-infobars')
            chrome_options.add_argument('--no-sandbox')

            chrome_options.add_experimental_option("prefs", {
                "download.default_directory": download_folder,
                "download.prompt_for_download": False,
                "download.directory_upgrade": True,
                "safebrowsing_for_trusted_sources_enabled": False,
                "safebrowsing.enabled": False
            })

            service_chrome = ChromeService(executable_path=ChromeDriverManager().install())
            service_chrome.creation_flags = CREATE_NO_WINDOW
            chrome_driver = Chrome(service=service_chrome, options=chrome_options)
            return chrome_driver


class Download():
    def __init__(self, link: str, episode_title: str, download_folder: str, download_size: int, net_issue_responses: list[str], 
                 download_manager_page: str, app_name: str, driver: Chrome, file_extension='.mp4', progress_update_callback: Callable=lambda x: None, console_app=False) -> None:
        self.link = link
        self.title = episode_title
        self.extension = file_extension
        self.path = download_folder
        self.total_download_size = download_size
        self.manager = download_manager_page
        self.app_name = app_name
        self.driver = driver
        self.tmp_suffixes = ['.crdownload', '.tmp']
        self.paused = False
        self.complete = False
        self.net_responses = net_issue_responses
        self.console_app = console_app
        self.progress_update_callback = progress_update_callback
        self.details_element_reference = lambda: driver.execute_script('return document.querySelector("downloads-manager").shadowRoot.querySelector("#mainContainer").querySelector("#downloadsList").querySelector("#frb0").shadowRoot.querySelector("#content").querySelector("#details")')
        self.pause_or_resume_element_reference = lambda: driver.execute_script('return arguments[0].querySelector("#safe").querySelector("span:nth-of-type(2)").querySelector("cr-button")', self.details_element_reference())
        self.click_pause_button = lambda: driver.execute_script("arguments[0].click();", self.pause_or_resume_element_reference())
        self.element_error_exceptions = (StaleElementReferenceException, JavascriptException)

    def start(self) -> None:
        self.tmp_deleter()
        driver = self.driver
        link = self.link
        manager = self.manager
        driver.get(self.link)
        server_download_link = link.replace('/f/', '/d/', 1)
        WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.CSS_SELECTOR, 'form[action="%s"]' %server_download_link)))
        driver.find_element(By.CSS_SELECTOR, 'form[action="%s"]' %server_download_link).submit()
        driver.get(manager)
        WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.TAG_NAME, 'downloads-manager')))

    def still_downloading(self) -> bool:
        files = Path(self.path).glob('*')
        for f in files:
            if f.suffix in self.tmp_suffixes:
                return True
        return False

    def tmp_deleter(self) -> None:
        files = Path(self.path).glob('*')
        for f in files:
            if f.suffix in self.tmp_suffixes:
                f.unlink()

    def pause_or_resume(self) -> None:
        try:
            self.click_pause_button()
            self.paused = not self.paused
        except self.element_error_exceptions: pass
    
    def download_error(self) -> bool:
        driver = self.driver
        try:
            details_element_reference = driver.execute_script('return document.querySelector("downloads-manager").shadowRoot.querySelector("#mainContainer").querySelector("#downloadsList").querySelector("#frb0").shadowRoot.querySelector("#content").querySelector("#details")')
            tag_element_reference = driver.execute_script('return arguments[0].querySelector("#title-area").querySelector("#tag")', details_element_reference)
        except self.element_error_exceptions:
            return False
        return True if len(tag_element_reference.get_attribute('innerHTML')) > 0 else False
    
    def fix_download_error(self, retry_attempts=5) -> bool:
        for try_count in range(retry_attempts):
            try:
                self.click_pause_button
                time.sleep(2)
                self.click_pause_button()
                time.sleep(try_count+2)
                if not self.download_error(): return True
            except self.element_error_exceptions: continue
        return False
    
    def get_downloading_file(self) -> Path:
        files_in_folder = list(Path(self.path).glob("*"))
        # Sort the list by the creation time of the files
        files_in_folder.sort(key=lambda x: os.path.getctime(x))
        downloading_file = files_in_folder[-1]
        return downloading_file
    
    def rename(self) -> None:
        downloaded_file = self.get_downloading_file()
        downloaded_file.rename(os.path.join(self.path, f'{self.title}{self.extension}'))
    
    def progress(self) -> bool:
            max_allowed_unchanged_count = 50
            current_unchanged_count = 0
            download_progress_has_changed = False
            downloading_file = self.get_downloading_file()
            response_idx = randint(0, len(self.net_responses)-1)
            progress_bar = None if not self.console_app else tqdm(total=round(self.total_download_size), unit='MB', unit_scale=True, desc=f' Downloading {self.title}')
            prev_file_size = 0
            current_file_size = 0
            while not self.complete:
                if self.paused:
                    self.progress_update_callback(-2) # Status download is paused
                    if progress_bar: progress_bar.set_description(' Paused')
                    continue
        
                if not download_progress_has_changed:
                    if current_unchanged_count > max_allowed_unchanged_count:
                        current_unchanged_count = 0
                        if ping(google_dot_com): 
                            if self.download_error() and self.still_downloading():                                         
                                self.progress_update_callback(-4) # Status error detected but attempting fix               
                                if progress_bar: progress_bar.set_description(' Attempting to fix error')                  
                                if not self.fix_download_error():                                                          
                                    self.progress_update_callback(-5) # Status failed error fix hence restarting           
                                    if progress_bar: progress_bar.set_description(' Attempt failed, restarting  :(')       
                                    return False                                                                           
                        else:
                            self.progress_update_callback(-3) # Status no network
                            if progress_bar: progress_bar.set_description(f' {self.net_responses[response_idx]}')
                            continue

                self.progress_update_callback(-1) # Status download proceeding
                if progress_bar: progress_bar.set_description(f' Downloading {self.title}')          
                try:                                                           # file size in MBs
                    current_file_size = round(os.path.getsize(downloading_file)/1000,000)
                except FileNotFoundError: self.complete = True
                if current_file_size >= self.total_download_size: self.complete = True
                if self.complete:
                    self.progress_update_callback(-6) # Status download complete
                    while self.still_downloading(): continue    
                    self.rename()   
                    if progress_bar:
                        progress_bar.set_description(' Complete')
                        progress_bar.close()
                    return True 
                self.progress_update_callback(current_file_size)
                if progress_bar: progress_bar.update(current_file_size)
                download_progress_has_changed = current_file_size > prev_file_size
                current_unchanged_count = 0 if download_progress_has_changed else current_unchanged_count + 1
                prev_file_size = current_file_size
            return False
            
            
            
    
def extract_poster_summary_and_episode_count(anime_id: str) -> tuple[str, str, int]:
    page_link = f'{pahe_home_url}/anime/{anime_id}'
    response = requests.get(page_link).content
    soup = BeautifulSoup(response, parser)
    poster = soup.find(class_='youtube-preview')
    if not isinstance(poster, Tag): poster = cast(Tag, soup.find(class_='poster-image'))
    poster_link = cast(str, poster['href'])
    summary = cast(Tag, soup.find(class_='anime-synopsis')).get_text()

    page_link = f'{pahe_home_url}{api_url_extension}release&id={anime_id}&sort=episode_desc'
    response = requests.get(page_link).content
    episode_count = json.loads(response)['data'][0]['episode']
    return (poster_link, summary, int(episode_count))

def test_getting_direct_download_links(query_anime_title: str, start_episode: int, end_episode: int, quality: str, sub_or_dub='sub') -> list[str]:
    result = search(query_anime_title)[0]
    anime_id, anime_title, anime_page_link = extract_anime_id_title_and_page_link(result)
    _, _, episode_count = extract_poster_summary_and_episode_count(anime_id)
    episode_page_links = get_episode_page_links(start_episode, end_episode, anime_page_link, anime_id)
    download_page_links, download_info = get_download_page_links_and_info(episode_page_links, console_app=True)
    direct_download_links = get_direct_download_links(bind_quality_to_link_info(quality, *bind_sub_or_dub_to_link_info(sub_or_dub, download_page_links, download_info))[0], console_app=True)
    return direct_download_links
            
def main():
    # Download settings        
    query = 'Blue Lock'
    quality = '1080'
    sub_or_dub = 'sub'
    start_episode = 1
    end_episode = 24
    
    direct_download_links = test_getting_direct_download_links(query, start_episode, end_episode, quality, sub_or_dub )
    list(map(print, direct_download_links))

    # print(episode_count)
    # print(dub_available(page_link, anime_id))


    # default_download_folder = r'C:\Users\PC\Downloads\Anime\Tests'
    # download_links, download_info = get_download_data(episode_page_links[:5])

    # print(dub_available(download_info))vims
    # download_links, download_info = bind_sub_or_dub_to_link_info(sub_or_dub, download_links, download_info)
    # episode_links, episode_info = bind_quality_to_link_info(quality, download_links, download_info)
    # direct_download_links = get_direct_download_links(episode_links)
    # anime_folder = os.path.join(default_download_folder, anime_title)
    # _, download_sizes = get_download_sizes(episode_info)
    # net_responses = ['Bad net foo', 'Bruv get net foo']
    # chrome_download_page = 'chrome://downloads'
    # app_name = 'pahe.py - Senpwai - Visual Studio Code'
    # driver = set_up_headless_browser(anime_folder)
    # try:
    #     os.mkdir(anime_folder) 
    # except:
    #     pass

    # print(episode_info)
    # # for idx, link in enumerate(direct_download_links): 
    # #     episode_title = f'{anime_title} Episode {idx+1}'
    # #     download = Download(link, episode_title, anime_folder, download_sizes[idx], net_responses, chrome_download_page, app_name, driver)
    # #     download.start()
    # #     download.progress() 

    # driver.close()

if __name__ == "__main__":
    main()