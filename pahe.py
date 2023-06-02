import requests
import threading
import bs4
from bs4 import BeautifulSoup
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
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.common.exceptions import StaleElementReferenceException
from selenium.common.exceptions import JavascriptException
import keyboard
import pyautogui

import ping3
from random import randint

pahe_home_url = 'https://animepahe.ru'
api_url_extension = '/api?m='
parser = 'html.parser'
google_dot_com = 'google.com'

def search(keyword: str)->list[dict]:
    search_url = pahe_home_url+api_url_extension+'search&q='+keyword
    response = requests.get(search_url).content
    results = json.loads(response.decode('UTF-8'))['data']
    return results

def extract_anime_id_title_and_page_link(result: dict) -> tuple[str]:
    anime_id = result['session']
    title = result['title']
    page_link = f'{pahe_home_url}{api_url_extension}release&id={anime_id}&sort=episode_asc'
    return anime_id, title, page_link

# Issues GET requests together with the id of the anime to retrieve a list of the episode page links(not download links) 
def get_episode_page_links(anime_page_link: str, anime_id: str) -> list[str]:
    page_url = anime_page_link
    episodes_data = []
    page_no = 1
    while page_url != None:
        page_url = f'{anime_page_link}&page={page_no}'
        response = requests.get(page_url).content
        decoded_anime_page = json.loads(response.decode('UTF-8'))
        episodes_data+=decoded_anime_page['data']
        page_url = decoded_anime_page["next_page_url"]
        page_no+=1

    episode_sessions = [episode['session'] for episode in episodes_data]
    episode_links = [f'{pahe_home_url}/play/{anime_id}/{episode_session}' for episode_session in episode_sessions]
    return  episode_links

def get_download_data(episode_page_links: list[str]) ->tuple[list[str], list[str]]:
    download_data = []
    with tqdm(total=len(episode_page_links), desc=' Fetching download page links', unit='eps') as progress_bar:
        for idx, episode_page_link in enumerate(episode_page_links):
            episode_page = requests.get(episode_page_link).content
            soup = BeautifulSoup(episode_page, parser)
            download_data.append(soup.find_all('a', class_='dropdown-item', target='_blank'))
            progress_bar.update(idx+1 - progress_bar.n)
        progress_bar.set_description(' Done')
        progress_bar.close()
    # Scrapes the download data of each episode and stores the links for the in a list which is contained in another list containing all episodes
    download_links = [[download_link["href"] for download_link in episode_data] for episode_data in download_data]
    # Scrapes the download data of each episode and stores the info for each quality and dub or sub in a list which is contained in another list containing all episodes
    download_info = [[episode_info.text.strip() for episode_info in episode_data] for episode_data in download_data] 
    return (download_links, download_info)   

def dub_available(download_info: list[list[str]]) -> bool :
    dub_pattern = r'eng$'
    picked = []
    picked.append(download_info[0])
    picked.append(download_info[-1])
    picked.append(download_info[randint(0, len(download_info)-1)])
    for episode in picked:
        found_dub = False
        for info in episode:
            if (match := re.search(dub_pattern, info)) and match:
                found_dub = True
        if not found_dub: return False
    return True


def bind_sub_or_dub_to_link_info(sub_or_dub: str, download_links: list[list[str]], download_info: list[list[str]]) -> tuple[list[str]] :
    bound_links = []
    bound_info = []
    dub_pattern = r'eng$'
    for idx_out, episode_info in enumerate(download_info):
        links = []
        infos = []
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


def bind_quality_to_link_info(quality: str, download_links: list[list[str]], download_info: list[list[str]]) -> tuple[list[str]] :
    if quality == '480': quality = '360'
    quality_pattern = rf'\b({quality})p\b'
    bound_links = []
    bound_info = []
    for idx_out, episode_info in enumerate(download_info): 
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
    download_sizes = []
    for episode in episode_info:
        match = re.search(pattern, episode)
        size = int(match.group(1))
        download_sizes.append(size)
        total_size+=size
    return (total_size, download_sizes)

def get_direct_download_links(episode_links: list[str]) -> list[str]:
    download_links = []
    with tqdm(total=len(episode_links), desc=' Fetching direct download links', unit='eps') as progress_bar:
        for idx, link in enumerate(episode_links):
            pahewin_page = requests.get(link).content
            soup = BeautifulSoup(pahewin_page, parser)
            download_link = soup.find("a", class_="btn btn-primary btn-block redirect")["href"]
            download_links.append(download_link)
            progress_bar.update(idx+1 - progress_bar.n)
        progress_bar.set_description(' Done')
        progress_bar.close()
    return download_links


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
    def __init__(self, link: str, episode_title: str, download_folder: str, download_size: int, net_issue_responses: list[str], download_manager_page: str, app_name: str, driver: Chrome, file_extension='.mp4') -> None:
        self.link = link
        self.title = episode_title
        self.extension = file_extension
        self.path = download_folder
        self.size = download_size
        self.manager = download_manager_page
        self.app_name = app_name
        self.driver = driver
        self.tmp_suffixes = ['.crdownload', '.tmp']
        self.paused = False
        self.complete = False
        self.net_responses = net_issue_responses
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
                return 1
        return 0

    def tmp_deleter(self) -> None:
        files = Path(self.path).glob('*')
        for f in files:
            if f.suffix in self.tmp_suffixes:
                f.unlink()

    def pause_or_resume(self, event: keyboard.KeyboardEvent) -> None:
        active_window = pyautogui.getActiveWindow()
        if active_window != None and active_window.title == self.app_name:
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
        last_net_test_time = 0
        net_test_intervals = 5
        downloading_file = self.get_downloading_file()
        response_idx = randint(0, len(self.net_responses)-1)
        with tqdm(total=round(self.size), unit='MB', unit_scale=True, desc=f' Downloading {self.title}') as progress_bar:
            pause_hook = keyboard.on_press_key('space', self.pause_or_resume)  
            while not self.complete:
                elapsed_time = time.time() - last_net_test_time
                if elapsed_time >= net_test_intervals:
                    net_status = ping3.ping(google_dot_com)
                    last_net_test_time = time.time()
                if self.paused:
                    progress_bar.set_description(' Paused')

                elif not net_status:
                    progress_bar.set_description(f' {self.net_responses[response_idx]}')
                    last_net_test_time = 0
                    time.sleep(0)

                elif net_status and not self.paused: 
                    if self.download_error() and self.still_downloading():
                        progress_bar.set_description(' Attempting to fix error')
                        if not self.fix_download_error():
                            progress_bar.set_description(' Attempt failed, restarting  :(')
                            return False
                    progress_bar.set_description(f' Downloading {self.title}')
                try:
                    current_size = round(os.path.getsize(downloading_file)/1000000)
                except FileNotFoundError:
                    self.complete = True
                    break
                progress_bar.update(current_size - progress_bar.n)
                if current_size >= self.size:
                    self.complete = True
                    progress_bar.set_description(' Complete')
                    progress_bar.close()
            while self.still_downloading(): continue
            keyboard.unhook(pause_hook)
            self.rename()
        return True


            

        
results = search('fmab')
quality = '1080'
sub_or_dub = 'sub'
id, anime_title, page_link = extract_anime_id_title_and_page_link(results[0])
episode_page_links = get_episode_page_links(page_link, id)
download_links, download_info = get_download_data(episode_page_links[:5])

print(dub_available(download_info))
download_links, download_info = bind_sub_or_dub_to_link_info(sub_or_dub, download_links, download_info)
episode_links, episode_info = bind_quality_to_link_info(quality, download_links, download_info)
direct_download_links = get_direct_download_links(episode_links)
default_download_folder = r'C:\Users\PC\Downloads\Anime\Tests'
anime_folder = os.path.join(default_download_folder, anime_title)
_, download_sizes = get_download_sizes(episode_info)
net_responses = ['Bad net foo', 'Bruv get net foo']
chrome_download_page = 'chrome://downloads'
app_name = 'pahe.py - Senpwai - Visual Studio Code'
driver = set_up_headless_browser(anime_folder)
try:
    os.mkdir(anime_folder) 
except:
    pass

print(episode_info)
# for idx, link in enumerate(direct_download_links): 
#     episode_title = f'{anime_title} Episode {idx+1}'
#     download = Download(link, episode_title, anime_folder, download_sizes[idx], net_responses, chrome_download_page, app_name, driver)
#     download.start()
#     download.progress() 

driver.close()