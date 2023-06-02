import requests
import threading
from bs4 import BeautifulSoup
import time
from tqdm import tqdm
import os
import keyboard
import pyautogui
import webbrowser

from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver import ChromeOptions
from selenium.webdriver import Chrome
from subprocess import CREATE_NO_WINDOW

gogo_home_url = 'https://gogoanime.cl' 
parser = 'html.parser'

def search(keyword: str) -> list[BeautifulSoup]:
    search_url = '/search.html?keyword='
    search = gogo_home_url + search_url + keyword
    response = requests.get(search).content
    soup = BeautifulSoup(response, parser)
    results_page = soup.find('ul', class_="items")
    results = results_page.find_all('li')
    return results

def extract_anime_title_and_page_link(result: BeautifulSoup) -> tuple[str]:
    title = result.find('a')['title']
    page_link = gogo_home_url + result.find('a')['href']
    return title, page_link


def generate_episode_page_links(start_episode: int, end_episode: int, anime_page_link: str) -> list[str]:
    episode_page_links = []
    for episode_num in range(start_episode, end_episode+1):
        episode_page_links.append(f'{gogo_home_url}{anime_page_link.split("/category")[1]}-episode-{episode_num}')
    return episode_page_links

def get_download_page(episode_page_link: str) -> str:
    response = requests.get(episode_page_link).content
    soup = BeautifulSoup(response, parser)
    soup = soup.find('li', class_='dowloads')
    download_link = soup.find('a', target = '_blank')['href']
    return download_link
    


def set_up_headless_browser() -> Chrome:
     # Configures the settings for the headless browser
            chrome_options = ChromeOptions()
           # chrome_options.add_argument("--headless=new")
            chrome_options.add_argument('--disable-extensions')
            chrome_options.add_argument('--disable-infobars')
            chrome_options.add_argument('--no-sandbox')
            chrome_options.add_argument(f"referer={gogo_home_url}")


            chrome_options.add_experimental_option("prefs", {
                "download.prompt_for_download": False,
                "download.directory_upgrade": True,
                "safebrowsing_for_trusted_sources_enabled": False,
                "safebrowsing.enabled": False
            })

            service_chrome = ChromeService(executable_path=ChromeDriverManager().install())
            service_chrome.creation_flags = CREATE_NO_WINDOW
            chrome_driver = Chrome(service=service_chrome, options=chrome_options)
            return chrome_driver

def get_download_link_as_per_quality(download_page_links: list[str], quality: str, driver: Chrome, max_load_wait_time=25) -> list[str]:
    download_links = []
    quality_dict = {'360': 0,
                    '480': 1,
                    '720': 2,
                    '1080': 3}
    chosen_quality = quality_dict[quality]
    def get_all_quality_links(page: str, load_wait_time=1) -> list[str]:
        driver.get(page)
        time.sleep(load_wait_time)
        soup = BeautifulSoup(driver.page_source, parser)
        all_page_links = soup.find_all('a')
        all_quality_links = [link['href'] for link in all_page_links if 'download' in link.attrs]    
        if(len(all_quality_links) == 0):  
            if load_wait_time >= max_load_wait_time:   
                 raise TimeoutError
            else:
                load_wait_time += 1
                return get_all_quality_links(page, load_wait_time)
        return all_quality_links
    with tqdm(total=len(download_page_links), desc=' Fetching download links', unit='eps') as progress_bar:
        for idx, page in enumerate(download_page_links):
            all_quality_links = get_all_quality_links(page)
            if len(all_quality_links) != 4:
                chosen_quality = 0 if quality == '360' or quality == '480' else -1
            download_links.append(all_quality_links[chosen_quality])
            progress_bar.update(idx+1 - progress_bar.n)
        progress_bar.set_description(' Complete')
        progress_bar.close()
    return download_links

def get_download_page_links(episode_page_links: list[str]) -> list[str]:
    download_page_links = []
    with tqdm(total=len(episode_page_links), desc=' Fetching download page links', unit='eps') as progress_bar:
        for idx, episode_page_link in enumerate(episode_page_links):
            response = requests.get(episode_page_link).content
            soup = BeautifulSoup(response, parser)
            soup = soup.find('li', class_='dowloads')
            link = soup.find('a', target = '_blank')['href']
            download_page_links.append(link)
            progress_bar.update(idx+1 - progress_bar.n)
        progress_bar.set_description(' Done')
        progress_bar.close()
    return download_page_links

def calculate_download_size(download_links: str) -> int:
    total_size = 0
    with tqdm(total=len(download_links), desc=' Calculating total download size', unit='eps') as progress_bar:
        for idx, link in enumerate(download_links):
            response = requests.get(link, stream=True)
            size = response.headers.get('content-length', 0)
            total_size += int(size)
            progress_bar.update(idx+1 - progress_bar.n)
        progress_bar.set_description(' Done')
        progress_bar.close()
    total_size = round(total_size/1048576)
    return total_size

def open_browser_with_links(download_links: str) -> None:
    for link in download_links:
        webbrowser.open_new_tab(link)

class Download():
    def __init__(self, link: str, episode_title: str, download_folder: str, net_issue_responses: list[str], app_name: str, file_extension='.mp4' ) -> None:
        self.link = link
        self.title = episode_title
        self.extension = file_extension
        self.path = download_folder
        self.app_name = app_name
        self.paused = False
        self.complete = False
        self.net_responses = net_issue_responses
        
    def pause_or_resume(self, event: keyboard.KeyboardEvent):
        active_window = pyautogui.getActiveWindow()
        if active_window != None and active_window.title == self.app_name:
            self.paused = not self.paused

    def download(self):
        response = requests.get(self.link, stream=True)
        total = int(response.headers.get('content-length', 0))
        file_title = f'{self.title}{self.extension}'
        file_path = os.path.join(self.path, file_title)
        with open(file_path, 'wb') as file, tqdm(
            desc= f'Downloading {self.title}: ',
            total=total,
            unit='iB',
            unit_scale=True,
            unit_divisor=1024,
        ) as progress_bar:
            keyboard.on_press_key('space', self.pause_or_resume)
            for data in response.iter_content(chunk_size=1024):
                if self.paused:
                    progress_bar.set_description(' Paused')
                while self.paused: pass
                progress_bar.set_description(f'Downloading {self.title}: ')
                size = file.write(data)
                progress_bar.update(size)

            progress_bar.set_description(f'Completed {self.title}')

start_episode = 1
end_episode = 2
quality = '360'

results = search('Senyuu')
result = results[0]
anime_title, anime_page_link = extract_anime_title_and_page_link(result)
anime_title = anime_title.strip()
chrome_driver = set_up_headless_browser()

root_path = './'
episode_page_links = generate_episode_page_links(start_episode, end_episode, anime_page_link)
download_page_links = get_download_page_links(episode_page_links)
download_links = get_download_link_as_per_quality(download_page_links, quality, chrome_driver, max_load_wait_time=50)
total_download_size = calculate_download_size(download_links)

default_download_folder = r'C:\Users\PC\Downloads\Anime\Tests'
anime_folder = os.path.join(default_download_folder, anime_title)
net_responses = ['Bad net foo', 'Bruv get net foo']
app_name = 'gogo.py - Senpwai - Visual Studio Code'

try:
    os.mkdir(anime_folder)
except: pass


# open_browser_with_links(download_page_links)

for idx, link in enumerate(download_links):
    episode_title = f'{anime_title} Episode {idx+1}'
    download = Download(link, episode_title, anime_folder, net_responses, app_name)
    download.download()
  