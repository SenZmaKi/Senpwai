import requests
import json
import re
from bs4 import BeautifulSoup


from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

#Dropped edge support
# from webdriver_manager.microsoft import EdgeChromiumDriverManager
# from selenium.webdriver.edge.service import Service as EdgeService
# from selenium.webdriver import EdgeOptions


from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver import ChromeOptions




#Working on firefox support
#from webdriver_manager.firefox import GeckoDriverManager
#from selenium.webdriver.firefox.service import Service as FirefoxService
#from selenium.webdriver import FirefoxOptions

from selenium import webdriver
from selenium.webdriver.common.by import By


import webbrowser
import time

import tkinter as tk
from tkinter import filedialog
import os

import pathlib

from tqdm import tqdm as tqdm

from subprocess import CREATE_NO_WINDOW

import sys

import psutil
from random import randint

import keyboard
import pyautogui

import ping3

os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = "hide"
from pygame import mixer
import time
from colorama import init, Fore, Back, Style
import threading

import string


#The name of my workspace in vs code basically
#Uncomment out the below app_name and set it to the window of where you run the code from in order for 
#the keyboard module to load your inputs, this is to prevent inputs from being detected even if the app isn't the active window
#then comment out app_name = "Senpwai" cause that is used to set the app_name when the script is built into an executable(app)

#app_name = "Senpwai.py - Senpwai (Workspace) - Visual Studio Code"
app_name = "Senpwai.py - Senpwai - Visual Studio Code"
#app_name = "Senpwai"
os.system("title " + app_name)

current_version = "1.5.1"

home_url = "https://animepahe.ru/"
google_com = "google.com"
anime_url = home_url+"anime/"
api_url_extension = "api?m="
search_url_extension = api_url_extension+"search&q="
quality = "720p"
sub_or_dub = "sub"
automate = False


yes_list = ["yes", "yeah", "1", 1, "y", "ok", "k", "cool"]
no_list = ["no", "nope", "0", 0, "n"]

default_download_folder_path = None
senpwai_stuff_path = os.environ["PROGRAMDATA"]+"\\Senpwai"



repo_url = "https://github.com/SenZmaKi/Senpwai"
github_home_url =  "https://github.com"
version_download_url = "https://github.com/SenZmaKi/Senpwai/releases/download/"

anime_references = ["It's called the Attack Titan", "Tatakae tatake", "Ohio Final Boss", "Tokio tomare", "Wonder of Ohio","Omoshire ore ga zangetsu da", "Getsuga Tenshou", "Rasenghan",
                     "Za Warudo", "Star Pratina", "Nigurendayooo", "Korega jyuu da", "Mendokusai", "Dattebayo", "Bankai", "Kono asuratonkachi", "I devoured Barou and he devoured me right back",
                      "United of States of Smaaaaash", "One for All Full Cowling", "Maid in Heaven Tokio Kasotsuru", "Nyaaa", "Pony Stark",
                     "Dysfunctional Degenerate", "Alpha Sigma", "But Hey that's just a theory", "Bro fist", "King Crimson", "Sticky Fingers", "Watch Daily Lives of HighSchool Boys",
                     "Watch Prison School", "Watch Grand Blue", "Watch Golden Boy, funniest shit I've ever seen", "Watch Isekai Ojii-san", "Read Kengan Asura", "Read A Thousand Splendid Suns"
                     , "Ryuujin no ken wo kurae!!!", "Ryuuga wakateki wo kurau", "Ookami o wagateki wo kurae", "Nerf this", "And dey say Chivalry is dead", "Who's next?", "Ryoiki Tenkai",
                     "Ban.. .Kai Tensa Zangetsu", "Bankai Senbonzakura Kageyoshi", "Bankai Hihio Zabimaru", "Huuuero Zabimaru"]
internet_responses = ["Kono baka!!! You don't have internet", "Yaaarou, no internet connection", "Bakayorou!!! Check your internet", "Fuzakerna teme!!! You don't have internet", "Oe oe oe mate. Network problem", "Mendokusai, no network", "How am I supposed to cook without internet? ", "Bro got no internet damn", "No internets?"]

chrome_downloads_page = 'chrome://downloads'
edge_downloads_page = 'edge://downloads/all'


mute_path = pathlib.Path(senpwai_stuff_path+"\\mute.txt")
#if a file named mute exists we mute else we don't mute
#lowkey my favourite line of code in the whole script, implementation of a mute system XD, it's so dumb
mute = mute_path.is_file()

#Set the audio path depending on whether we are running from from an executable(app) or script
if getattr(sys, 'frozen', False):
    audio_dir = os.path.join(sys._MEIPASS, 'audio')
else:
    audio_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'audio')

join = os.path.join
output_colour = Fore.LIGHTGREEN_EX
input_colour = Fore.LIGHTYELLOW_EX

audio_paths = { "typing": join(audio_dir, 'typing.wav'),
               "downloads complete": join(audio_dir, 'all downloads completed succesfully.wav'),
               'almost': join(audio_dir, "almost there.wav"),
               'sec': join(audio_dir, "give me a sec Senpai.wav"),
               'hol up': join(audio_dir, 'hol up let me cook.wav'),
               'moment': join(audio_dir, 'just give me a moment.wav'),
               'enter number': join(audio_dir, 'please enter the number belonging to the anime you want from the list below.wav'),
               'sub': join(audio_dir, 'sub or dub.wav'),
               'valid internet': join(audio_dir, 'testing for a valid internet connection.wav'),
               'quality': join(audio_dir, 'what quality do you want do download in.wav'),
               'working': join(audio_dir, 'working on it.wav'),
               'continue downloading': join(audio_dir, 'would you like to continue downloading.wav'),
               'update': join(audio_dir, 'would you like to update to the new version.wav'),
               'settings': join(audio_dir, 'would you like to you uWuse the following swaved settings.wav'),
               "name": join(audio_dir, "name.wav"),
               "systems": join(audio_dir, "systems online.wav")

               
               }
#just a loading animation
def loading_animation(condition):
    animation = "|/-\\"
    idx = 0
    while not condition[0]:
        print(f" {animation[idx % len(animation)]} ", end="\r")
        idx += 1      
        time.sleep(0.1)
#The goofy aah audio that plays when the app starts
def systems_online():
    player = mixer.music
    player.load(audio_paths['systems'])
    player.play()
    animation = "|/-\\"
    idx = 0
    while player.get_busy():
        print(f"  {animation[idx % len(animation)]}", end="\r")
        idx += 1      
        time.sleep(0.1)


#Detects whether the input the user entered is Y or N
def key_prompt():
        sys.stdout.write(input_colour+"> ")
        print(output_colour, end="")
        while True:
            try:
                #to handle cases when there is no active window e.g when user is on the desktop
                active_window = pyautogui.getActiveWindow()
                if active_window != None and active_window.title == app_name:
                    if keyboard.is_pressed("y") or keyboard.is_pressed("Y"):
                        sys.stdout.write("\n") 
                        sys.stdout.flush()
                        flush_input()
                        return 1
                    elif keyboard.is_pressed("n") or keyboard.is_pressed("N"):
                        sys.stdout.write("\n") 
                        sys.stdout.flush()
                        flush_input()
                        return 0
                    elif keyboard.is_pressed("esc"):
                        sys.stdout.write("\n") 
                        sys.stdout.flush()
                        flush_input()
                        exit_handler()
            except:
                pass

#Flushes users input from the inputstream after key_prompt() is called
def flush_input():
    #wait a little bit cause the buffers don't update immediately
    time.sleep(0.1)
    try:
        import msvcrt
        while msvcrt.kbhit():
            msvcrt.getch()
    except:
        pass

def play_audio(audio_paths):
    global mute
    def decorator(fun):
        def wrapper(*args, **kwargs):
                if not mute:
                    if len(args)>=2:
                            player = mixer.Sound(audio_paths[args[1]])
                            player.play()
                            fun(*args, *kwargs)
                    elif len(args)<2:
                        player = mixer.Sound(audio_paths["typing"])
                        player.play(loops=-1)
                        fun(*args, *kwargs)
                        player.stop()
                elif mute:
                    fun(*args, *kwargs)

        return wrapper
    return decorator

#Prints output with a delay to simulate typing and plays audio in conjunction
@play_audio(audio_paths)
def slow_print(text, audio=None, delay_time=0.01): 
    for character in text:      
        sys.stdout.write(character) 
        sys.stdout.flush()
        time.sleep(delay_time)
    sys.stdout.write("\n")

#Checks if the user's Senpwai version is outdated by scraping the github repository, updates if True proceeds as normal if False
def VersionUpdater(current_version, repo_url, github_home_url, version_download_url):
    #Scrapes the repository homepage to find the latest version
    repo_page = requests.get(repo_url).content
    soup = BeautifulSoup(repo_page, "html.parser")
    latest_version = soup.find_all("a", class_="Link--primary d-flex no-underline")

    pattern = "\d.*"
    tag_url = github_home_url+latest_version[0]["href"]
    latest_version = re.search(pattern, tag_url).group()

    latest_version_int = int(latest_version.replace("v", "").replace(".", ""))
    current_version_int = int(current_version.replace("v", "").replace(".", ""))

    #Checks if the current running version is the latest
    if latest_version_int > current_version_int:
        slow_print(" Seems like there's a new version of me, guess I'm turning into an old hag XD")
        slow_print(" Would you like to update to the new version? ", "update")
        while True:
            reply = key_prompt()

            if(len([y for y in yes_list if reply == y])>0):

                latest_version_download_url = version_download_url+"v"+latest_version+"/Senpwai.exe"        
                response = requests.get(latest_version_download_url, stream=True)
                total_size_in_bytes= int(response.headers.get('content-length', 0))
                block_size = 1024 #1 Kibibyte
                progress_bar = tqdm(total=total_size_in_bytes, unit='iB', unit_scale=True, desc=" Downloading younger me")
                updated_version_folder = os.path.dirname(os.path.abspath(sys.executable))+"\\Updated Senpwai"
                try:
                    os.mkdir(updated_version_folder)
                except:
                    pass

                with open(updated_version_folder+"\\Senpwai.exe", 'wb') as file:
                    for data in response.iter_content(block_size):
                        progress_bar.update(len(data))
                        file.write(data)
                
                if total_size_in_bytes != 0 and progress_bar.n != total_size_in_bytes:
                    progress_bar.desc = " Error something went wrong"
                    progress_bar.close()    
                    return 0
                else:
                    progress_bar.desc = " Complete"
                    progress_bar.close()
                    slow_print(" I will now open a folder containing the new me")
                    time.sleep(4)
                    os.startfile(updated_version_folder)
                    slow_print(" Now just place that version of me in your location of choice, I advise you put me in the desktop so that we see each other everyday :)")
                    slow_print(" Then delete this older me, it's been good Senpai, sayonara")
                    time.sleep(15)
                    sys.exit(" I don't wanna go :(")



            elif(len([n for n in no_list if reply == n])):
                slow_print(" Ok but you'll probably run into some nasty bugs with this version")
                return 0

            else:
                slow_print(" I dont understand what you mean, wakaranai")

def InternetTest():
    valid_connection = False
    mendokusai = 0
    while not valid_connection:
        slow_print(" Testing for a valid internet connection.. .", "valid internet")
        response = ping3.ping(google_com)
        if response:
            slow_print(" Success!!!\n")
            valid_connection = True
            return
        else:
            mendokusai +=1
            time.sleep(2)
            slow_print(f" {internet_responses[randint(0, len(internet_responses)-1)]}")
            if mendokusai >= 3:
                slow_print(f" {anime_references[randint(0, len(anime_references)-1)]}\n")
                mendokusai = 0
            elif mendokusai < 3:
                slow_print("\n")
            time.sleep(5)


#Kills all instances of drivers that may have been left running previously cause they result in errors and take up space
def ProcessTerminator():
    #parent_name_edge = "msedgedriver.exe"
    parent_name_chrome = "chromedriver.exe"
    parents_processes_to_kill = []
    for child_process in psutil.process_iter(['pid', 'name']):
        child_process = psutil.Process(child_process.info['pid'])
        try:
            parent_process = child_process.parent()
            if parent_name_chrome == parent_process.name():
                parents_processes_to_kill.append(parent_process)
                child_process.terminate()
        except:
            pass
    for parent_process in parents_processes_to_kill:
        parent_process.terminate()
        #time.sleep(5)
        return 1
    return 0
#Searches for the anime from the animepahe database
def Searcher():
    try:
        slow_print(" Enter the name of the anime you want to download", "name")
        keyword = input(input_colour+"> ")
        print(output_colour, end="")
        full_search_url = home_url+search_url_extension+keyword
        response = requests.get(full_search_url)
        results = json.loads(response.content.decode("UTF-8"))["data"]
        return results
    except:
    #If the anime isn't found keep prompting the user
        slow_print("\n I couldn't find that anime maybe check for a spelling error or try a different name? ")
        return Searcher()

def exit_message():
    slow_print(" ( ͡° ͜ʖ ͡°) Sayonara")
    slow_print(anime_references[randint(0, len(anime_references)-1)])
    slow_print("Exiting... .\n")



#Exit from program if user enters esc
exit_handler_last_call_time = 0
def exit_handler():
    def call_back():
        print(output_colour, end="")
        active_window = pyautogui.getActiveWindow()
        #to handle cases where there is no active window we check first if the object returned by getActiveWindow is not None
        #without this a bug where the program crashes if the user is on the desktop then tries pressing esc i.e NoneType object has no attribute title, you get?
        if active_window != None and app_name == active_window.title:
            exit_message()
            ProcessTerminator()
            os._exit(1)

        #prevent multiple key presses
    global exit_handler_last_call_time
    delay = 0.6
    current_time = time.time()
    time_since_last_call = current_time - exit_handler_last_call_time

    if time_since_last_call < delay:
        return 
    else:
        exit_handler_last_call_time = current_time
        return call_back()


keyboard.add_hotkey('esc', exit_handler)

#mute the app if user presses ctrl+m or ctrl+M
muter_last_call_time = 0
def muter():
    def call_back():
        active_window = pyautogui.getActiveWindow()
        if active_window != None and app_name == active_window.title:
            global mute
            if mute:
                mute = False
            elif not mute:
                mute = True
                    
            try:
                os.mkdir(senpwai_stuff_path)
            except:
                pass

            mute_path = pathlib.Path(senpwai_stuff_path+"\\mute.txt")
            if not mute_path.is_file() and mute:
                    with open(mute_path, "w"):
                        pass
            elif mute_path.is_file() and not mute:
                mute_path.unlink()
                

    #prevent multiple key presses
    global muter_last_call_time
    delay = 0.6
    current_time = time.time()
    time_since_last_call = current_time - muter_last_call_time

    if time_since_last_call < delay:
        return 
    else:
        muter_last_call_time = current_time
        return call_back()


keyboard.add_hotkey('alt+m', muter)


#Prompts the user to select the index of the anime they want from a list of the search results and returns the id of the chosen anime or 0, 0 if they choose an invalid number
def AnimeSelection(results):
    slow_print(" Please enter the number belonging to the anime you want from the list below", "enter number")
    for index, result in enumerate(results):
        slow_print(f"  {index+1} {result['title']}", delay_time=0.005)
    slow_print(" Or if the anime isn't in the list above enter s to search again")
    slow_print(" You can also enter the number of the anime followed by a and I will automatically used the saved settings and detect missing episodes")

    index_of_chosen_anime = input(input_colour+"> ")
    print(output_colour, end="")
    if index_of_chosen_anime == "s":
        return AnimeSelection(Searcher())
    
    pattern = r"(\d+)\s*a"  
    match = re.search(pattern, index_of_chosen_anime)
    if match:
        index_of_chosen_anime = match.group(1)
        global automate
        automate = True

    try:
        index_of_chosen_anime = int(index_of_chosen_anime)-1
        #If they pick a number outside the range of the fetched results
        if index_of_chosen_anime < 0 or index_of_chosen_anime >= len(results):
            slow_print("\n Invalid number Senpai")
            return AnimeSelection(results)
    except:
        slow_print("\n Invalid number Senpai")
        return AnimeSelection(results)

    for index, result in enumerate(results):
        if index == index_of_chosen_anime:
            anime_id = result["session"]
            anime_title = result["title"]
            return anime_id, anime_title
        
#Sets the folder to download the anime to by prompting the user for a folder
def SetDownloadFolderPath():
    
    root = tk.Tk()
    root.withdraw()
# Prompt the user to choose a folder directory
    download_folder = filedialog.askdirectory(title="Choose folder to put the downloaded anime")
    download_folder = download_folder.replace("/", "\\")
    try:
        os.mkdir(download_folder)
    except:
        pass
    return download_folder

#Returns the links to the episodes from animepahe
def EpisodeLinks(anime_id):
    #Issues a GET request to the server together with the id of the anime and returns a list of the episode page links(not donwload links) to all the episodes of that anime
    page_url = (home_url+api_url_extension+"release&id="+anime_id+"&sort=episode_asc")
    def episodes_pipeline(page_url):
        complete_episode_data = []
        next_page_url = page_url
        page_no = 1
        #Loop through all pages while scraping episode data in each page
        #Kinda like traversiong a linked list
        while next_page_url != None:
            page_url = page_url+f"&page={page_no}"
            response = requests.get(page_url)
            decoded_anime_page = json.loads(response.content.decode("UTF-8"))
            episode_data = decoded_anime_page["data"]
            complete_episode_data = complete_episode_data+episode_data
            next_page_url = decoded_anime_page["next_page_url"]
            page_no+=1
        return complete_episode_data

    episode_data = episodes_pipeline(page_url)
    episode_sessions = [episode["session"] for episode in episode_data]
    episode_links = [home_url+"play/"+anime_id+"/"+str(episode_session) for episode_session in episode_sessions]
    return  episode_links

#Splits the episode links into two datasets, the download_links, and the information about the downloads i.e quality 360p, 720p or 1080p and size in megabytes
def DownloadData(episode_links):
    download_data = []
    with tqdm(total=len(episode_links), desc=" Getting things ready", unit="eps") as progress_bar:
        for i, episode_link in enumerate(episode_links):
            episode_page = requests.get(episode_link).content
            soup = BeautifulSoup(episode_page, "html.parser")
            download_data.append(soup.find_all("a", class_="dropdown-item", target="_blank"))
            progress_bar.update(i+1 - progress_bar.n)
        progress_bar.set_description(" Done")
        progress_bar.close()
    #Scrapes the download data of each episode and stores the links for each quality and dub or sub in a list which is contained in another list containing all episodes
    download_links = [[download_link["href"] for download_link in episode_data] for episode_data in download_data]
    #Scrapes the download data of each episode and stores the info for each quality and dub or sub in a list which is contained in another list containing all episodes
    download_info = [[episode_info.text.strip() for episode_info in episode_data] for episode_data in download_data] 
    return (download_links, download_info)   

#Returns the sizes of the downloads of each episode per quality in a 2D array i.e the outer array contains each episode, the inner array contains the 3 sizes for each individual episode since there are 3 video qualities 360p, 720p and 1080p
#Example [[Episode 1[size in 360p, size in 720p, size in 1080p]], [Episode 2[size in 360p, size in 720p, size in 1080p]]]
def DownloadSizes(download_info):
    #You dont have to understand what happens here cause even I don't lol, ChatGpt for the win
    #The function uses a regular expression to find an expression that matches it's pattern starts with "(" and ends with "MB)"
    #This match is then striped of the MB part in order to convert it into an integer, but before that it is converted into a string cause re.findall returns a list
    #The string is then converted into an integer and appended into the list "download sizes" using the list comprehension and voila we have the sizes of our episodes
    download_sizes = [[int("".join(re.findall(r'\((.*?)MB\)'.strip("MB"), episode_info))) for episode_info in episode_data] for episode_data in download_info]
    return download_sizes

#Based off user input provided in SettingsPrompt() (check line 288 ), configure settings for the download, the quality and whether subbed or dubbed then returns single values that refer to each setting
def DownloadSettings(quality="69", sub_or_dub="69"):

    def quality_chooser(quality):
        if quality == "360p" or quality == "360" or quality == "3" or quality == "60":
            return "360"
        elif quality == "720p" or quality =="720" or quality == "7" or quality == "20":
            return "720"
        elif quality == "1080p" or quality =="1080" or quality == "1" or quality == "80":
            return "1080"
        else:
            return "error"
    
    def sub_or_dubber(sub_or_dub):
        if sub_or_dub == "sub" or sub_or_dub == "s":
            return "sub"
        elif sub_or_dub == "dub" or sub_or_dub == "d":
            return "dub"
        else:
            return "error"

    return (quality_chooser(quality), sub_or_dubber(sub_or_dub))
    
def SettingsPrompt():
    met_conditions = 0 
    quality = ""
    sub_or_dub = ""
    while met_conditions < 2:
        quality = DownloadSettings(quality=quality)[0]
        while quality == "error":
            slow_print("What quality do you want to download in uWu? 360p, 720p or 1080p?", "quality")
            quality = input(input_colour+"> ").lower()
            print(output_colour, end="")
            quality = DownloadSettings(quality=quality)[0]

        met_conditions+=1

        sub_or_dub = DownloadSettings(sub_or_dub=sub_or_dub)[1]
        while sub_or_dub == "error":
            slow_print("Sub or dub?", "sub")
            sub_or_dub = input(input_colour+"> ").lower()
            print(output_colour, end="")
            sub_or_dub = DownloadSettings(sub_or_dub=sub_or_dub)[1]
        met_conditions+=1
    return quality, sub_or_dub


#Saves the user's settings to a config file
def SaveSettings(senpwai_stuff_path):
    try:
        os.mkdir(senpwai_stuff_path)
    except:
        pass

    config_path = pathlib.Path(senpwai_stuff_path+"\\config.txt")
    quality = ""
    sub_or_dub = ""

#if there is a config file then prompt the user on whether they want to use the saved settings
    if config_path.is_file() and not automate:
        slow_print(" Would you like to uWuse the following swaved settings?", "settings")
        with open(config_path) as config_file:
            config_settings = json.load(config_file)
            slow_print(f" Quality: {config_settings['quality']}")
            slow_print(f" Default download folder: {config_settings['default_download_folder_path']}")
            slow_print(f" Sub or dub: {config_settings['sub_or_dub']}")

            reply = False
        while not reply:
            reply = key_prompt()
            if len([y for y in yes_list if y == reply]) > 0:
                quality, sub_or_dub = config_settings["quality"], config_settings["sub_or_dub"]
                default_download_folder_path = config_settings["default_download_folder_path"]
                quality, sub_or_dub = DownloadSettings(quality=quality)[0], DownloadSettings(sub_or_dub=sub_or_dub)[1]
                reply = True
                
            elif len([n for n in no_list if n == reply]) > 0:
                quality, sub_or_dub = SettingsPrompt()
                slow_print(" I will now ask for the download folder, avoid folders that require Administrator access otherwise the download will fail!!!")
                slow_print(" For example instead of using C:/Users/YourName/Downloads/Anime use C:/Users/PC/Downloads/Anime")
                time.sleep(2)
                default_download_folder_path = SetDownloadFolderPath()
                save_dict = {"quality": quality, "sub_or_dub": sub_or_dub, "default_download_folder_path": default_download_folder_path}
                with open(config_path, "w") as config_file   :
                    json.dump(save_dict, config_file)
                reply = True
            else:
                slow_print(" I don't understand what you mean. Yes or no?")
                reply = False
    elif config_path.is_file() and automate:
        with open(config_path) as config_file:
                config_settings = json.load(config_file)
        quality, sub_or_dub = config_settings["quality"], config_settings["sub_or_dub"]
        default_download_folder_path = config_settings["default_download_folder_path"]
        quality, sub_or_dub = DownloadSettings(quality=quality)[0], DownloadSettings(sub_or_dub=sub_or_dub)[1]


    elif not config_path.is_file():
        quality, sub_or_dub = SettingsPrompt()
        slow_print(" I will now ask for the download folder, avoid folders that require Administrator access otherwise the download will fail!!!")
        slow_print(" For example instead of using C:/Users/YourName/Downloads/Anime use C:/Users/PC/Downloads/Anime")
        default_download_folder_path = SetDownloadFolderPath()
        save_dict = {"quality": quality, "sub_or_dub": sub_or_dub, "default_download_folder_path": default_download_folder_path}
        with open(config_path, "w") as config_file   :
            json.dump(save_dict, config_file)
        
    return quality, sub_or_dub, default_download_folder_path

#Generates new download links and download sizes for the episodes based off the user's configured settings
def ConfigureDownloadData(download_links, download_sizes, quality, sub_or_dub):
    def quality_initialiser(quality):
        if quality == "360":
            return 0
        elif quality == "720":
            return 1
        elif quality == "1080":
            return 2
    quality = quality_initialiser(quality)
    if len(download_links) == 0:
        return [], []
    num_of_links = len(download_links[0])
    #Explicit is better than implicit lol
    if sub_or_dub == "d" or sub_or_dub == "dub" and (num_of_links == 5 or num_of_links == 3 or num_of_links == 2 or num_of_links == 1):
            slow_print(" There seems to be no dub for this anime, switching to sub")
            sub_or_dub = "s"
    if num_of_links == 6:
        if sub_or_dub == "sub" or sub_or_dub == "s":
            configured_download_links = [episode_links[:3] for episode_links in download_links]
            configured_download_sizes = [episode_links[:3] for episode_links in download_sizes]
        elif sub_or_dub == "dub" or sub_or_dub == "d":
            configured_download_links = [episode_links[:3] for episode_links in download_links]
            configured_download_sizes = [episode_links[:3] for episode_links in download_sizes]

        configured_download_links = [episode_links[quality] for episode_links in configured_download_links]
        configured_download_sizes = [episode_links[quality] for episode_links in configured_download_sizes]

    elif num_of_links == 4:
        if quality == 0:
            slow_print(" There seems to be no 360p for this anime, switching to 720p")
            quality = 1
        #To handle only 720p and 1080p
        quality-=1
        if sub_or_dub == "sub" or sub_or_dub == "s":
            configured_download_links = [episode_links[:2] for episode_links in download_links]
            configured_download_sizes = [episode_links[:2] for episode_links in download_sizes]
        elif sub_or_dub == "dub" or sub_or_dub == "d":
            configured_download_links = [episode_links[:2] for episode_links in download_links]
            configured_download_sizes = [episode_links[:2] for episode_links in download_sizes]

        configured_download_links = [episode_links[quality] for episode_links in configured_download_links]
        configured_download_sizes = [episode_links[quality] for episode_links in configured_download_sizes]
        
    elif num_of_links == 3:
        configured_download_links = [episode_links[quality] for episode_links in download_links]
        configured_download_sizes = [episode_links[quality] for episode_links in download_sizes]
    
    elif num_of_links == 2:
        if quality == 0:
            slow_print(" Theres seems to be no 360p for this anime, switching to 720p")
            quality = 1
        quality-=1
        configured_download_links = [episode_links[quality] for episode_links in download_links]
        configured_download_sizes = [episode_links[quality] for episode_links in download_sizes]
    elif num_of_links == 1:
        slow_print(" There seems to be only one quality for this anime, switching to that")
        configured_download_links = [episode_links[0] for episode_links in download_links]
        configured_download_sizes = [episode_links[0] for episode_links in download_sizes]


    
    return configured_download_links, configured_download_sizes


#Deletes every file that ends with .crdownload or .tmp which are temporary files generated as the browser downloads, we delete them since they will cause errors later on
def tmpDeleter(download_folder_path): 
    files = pathlib.Path(download_folder_path).glob("*")
    #Checks for temporary files
    for f in files:
        if f.suffix == ".crdownload" or f.suffix == ".tmp":
            #deletes the temporary file
            f.unlink()

#Automates the whole download process
#This is some pretty sensitive code especially the file manipulation part, most of it is Supaghetti code and I don't understand how half of it works
#Alter at your own risk, you have been warned
    
def DownloadEpisodes(predicted_episodes_indices, predicted_episodes_links, predicted_episodes_sizes, download_folder_path, anime_title):
        
        #with the way windows handles stuff without this line the anime wont be able to be downloaded to the C:\\ drive or D:\\ annoying ass bug
        fixed_download_folder_path = download_folder_path.replace("\\\\", "\\")


        #Installs browser driver manager and checks whether user is using supported browser then creates a webdriver object of the respective browser as a headless browser and returns it
        def SupportedBrowserCheck():

        #configures the settings for the headless browser
            chrome_options = ChromeOptions()
            #edge_options = EdgeOptions()
            #firefox_options = FirefoxOptions()

            chrome_options.add_argument("--headless=new")
            #edge_options.add_argument("--headless=new")
            #firefox_options.add_argument("--headless=new")


            chrome_options.add_argument('--disable-extensions')
            #edge_options.add_argument('--disable-extensions')
            #firefox_options.add_argument('--disable-extensions')
            
            
            chrome_options.add_argument('--disable-infobars')
            #edge_options.add_argument('--disable-infobars')
            #firefox_options.add_argument('--disable-infobars')
            
            
            chrome_options.add_argument('--no-sandbox')
            #edge_options.add_argument('--no-sandbox')
            #firefox_options.add_argument('--no-sandbox')

            chrome_options.add_experimental_option("prefs", {
                "download.default_directory": fixed_download_folder_path,
                "download.prompt_for_download": False,
                "download.directory_upgrade": True,
                "safebrowsing_for_trusted_sources_enabled": False,
                "safebrowsing.enabled": False
            })

            # edge_options.add_experimental_option("prefs", {
            #     "download.default_directory": fixed_download_folder_path,
            #     "download.prompt_for_download": False,
            #     "download.directory_upgrade": True,
            #     "safebrowsing_for_trusted_sources_enabled": False,
            #     "safebrowsing.enabled": False
            # })


        
    #Installs Browser Driver Managers for the respective browsers, this is to be used by Selenium

            try:
                service_chrome = ChromeService(executable_path=ChromeDriverManager().install())
                service_chrome.creation_flags = CREATE_NO_WINDOW
                driver_chrome = webdriver.Chrome(service=service_chrome, options=chrome_options)
                chrome_downloads_page
                return driver_chrome, chrome_downloads_page
            except:
                slow_print(" Sowwy the onwy currently supported browser is Google Chrome, please install it and try again")
                webbrowser.open_new("https://www.google.com/chrome/")
                exit_handler()
                return 0
                # try:
                #     service_edge = EdgeService(executable_path=EdgeChromiumDriverManager().install())
                #     service_edge.creation_flags = CREATE_NO_WINDOW
                #     driver_edge = webdriver.Edge(service=service_edge, options=edge_options)
                #     return driver_edge, edge_downloads_page





        driver, downloads_manager_page = SupportedBrowserCheck()


        #Warning!!! sensitive supaghetti code, alter at your own risk

            

        #Check whether downloads are complete and returns True or False
        def CompletionCheck(download_folder_path, total_downloads, file_count):

            files = pathlib.Path(download_folder_path).glob("*")
        #search for .tmp or .crdownload file which means downloads are still in progress
            for f in files:
                if f.suffix == ".crdownload" or f.suffix == ".tmp":
                    time.sleep(2)
                    return 0
        #check if the the number of files is less than the total number of files to be downloaded, assuming files already in the folder are downloaded files
        #note this MUST execute after we have checked for temporary files otherwise a file being downloaded will be counted as a complete file
            if file_count < total_downloads:
                return 0
            
            #Downloads are complete
            return 1

        def StillDownloading(download_folder_path):
            files = pathlib.Path(download_folder_path).glob("*")
            for f in files:
                if f.suffix == ".crdownload" or f.suffix == ".tmp":
                    return 1
            return 0
    

        def download_error():

            try:
                details_element_reference = driver.execute_script('return document.querySelector("downloads-manager").shadowRoot.querySelector("#mainContainer").querySelector("#downloadsList").querySelector("#frb0").shadowRoot.querySelector("#content").querySelector("#details")')
                tag_element_reference = driver.execute_script('return arguments[0].querySelector("#title-area").querySelector("#tag")', details_element_reference)
                return True if len(tag_element_reference.get_attribute('innerHTML'))>0 else False
            except:
                return False

        def DownloadErrorHandler():
            try:
                details_element_reference = driver.execute_script('return document.querySelector("downloads-manager").shadowRoot.querySelector("#mainContainer").querySelector("#downloadsList").querySelector("#frb0").shadowRoot.querySelector("#content").querySelector("#details")')
                resume_element_reference = driver.execute_script('return arguments[0].querySelector("#safe").querySelector("span:nth-of-type(2)").querySelector("cr-button")', details_element_reference)
                #test for internet connection and test if the download can resume normally
                def error_fix_attempt():
                    if resume_element_reference.get_attribute('innerHTML').strip() == 'Pause':
                        #Click pause then resume hence two clicks
                        driver.execute_script("arguments[0].click();", resume_element_reference)
                        time.sleep(1)
                        driver.execute_script("arguments[0].click();", resume_element_reference)
                        time.sleep(1)
                        if download_error() == False:
                            return 1
                        else:
                            return 0
                    else:
                        return 0
                
                total_retries = 5
                succesful_resume = False
                for retry in range(total_retries):
                    succesful_resume = error_fix_attempt()
                    if succesful_resume:
                        return 1
                return 0
            except:
                return 0


           
                    
        
        #detect if user presses space
        #absolute dogshit progress bar, fails half the time XD
        def ProgressBar(episode_size, download_folder_path, anime_title, index):
            
            last_network_check_time = 0
            last_call_time = 0
        #Checks if user has a network connection, if they do wait 5 seconds before trying again, if not try again immediately
            def network_test(initial_network_status):
                test_delay = 5
                nonlocal last_network_check_time
                current_time = time.time()
                elapsed_time = current_time - last_network_check_time
                if not initial_network_status:
                    return ping3.ping(google_com)
                elif initial_network_status:
                    if elapsed_time >= test_delay:
                        last_network_check_time = current_time
                        return ping3.ping(google_com)
                return initial_network_status
        
            #Scuffed pause button
            paused = False
            def pause_or_resume(event):
                def call_back():
                    try:
                        nonlocal paused
                        active_window = pyautogui.getActiveWindow()
                        if event.name == 'space' and active_window != None and active_window.title == app_name:
                            details_element_reference = driver.execute_script('return document.querySelector("downloads-manager").shadowRoot.querySelector("#mainContainer").querySelector("#downloadsList").querySelector("#frb0").shadowRoot.querySelector("#content").querySelector("#details")')
                            pause_or_resume_element_reference = driver.execute_script('return arguments[0].querySelector("#safe").querySelector("span:nth-of-type(2)").querySelector("cr-button")', details_element_reference)
                            driver.execute_script("arguments[0].click();", pause_or_resume_element_reference)
                            if not paused:
                                paused = True
                            elif paused:
                                paused = False
                            return 1
                    except:
                       return 0 

                #Prevent multiple successive keyboard inputs from being loaded
                nonlocal last_call_time
                delay = 0.6
                current_time = time.time()
                time_since_last_call = current_time - last_call_time

                if time_since_last_call < delay:
                    return 
                else:
                    last_call_time = current_time
                    return call_back()
            
          
            download_complete = False
            error = False
            #otherwise the message will constantly switch
            ran_index = randint(0, len(internet_responses)-1)

            with tqdm(total=round(episode_size), unit='MB', unit_scale=True, desc=f' Downloading {anime_title} Episode {index+1}') as progress_bar:
                keyboard.hook(pause_or_resume)

            # Loop until the download is complete
                initial_status = True
                while not download_complete and not error:

                    network_status = network_test(initial_status)
                    initial_status = network_status
                    
                    if network_status:
                        if download_error():
                            progress_bar.set_description(f" Attempting to fix error.. .")
                            error_fix_status = DownloadErrorHandler()
                            if error_fix_status == 1:
                                progress_bar.set_description(f" Success!!!")
                                pass
                            elif error_fix_status == 0:
                                progress_bar.set_description(f" Attempt failed :( Restarting")
                                keyboard.unhook(pause_or_resume)         
                                return 0
                    elif not network_status and not paused:
                        progress_bar.set_description(f" {internet_responses[ran_index]}")

 
                    if paused:
                        progress_bar.set_description(f" Paused")
                    elif not paused and network_status:
                        progress_bar.set_description(f" Downloading {anime_title} Episode {index+1}")

                    try:
                        file_paths = list(pathlib.Path(download_folder_path).glob("*"))
                        # Sort the list by the creation time of the files
                        file_paths.sort(key=lambda x: os.path.getctime(x))
                        downloading_file = file_paths[-1]
                        # Calculate the progress of the download
                        current_size = round(os.path.getsize(downloading_file)/1000000)
                        # Update the progress bar
                        progress_bar.update(current_size - progress_bar.n)
                        # Check if the download is complete
                        if current_size >= episode_size:
                            download_complete = True

                    except:
                          error = True
                          progress_bar.set_description(f" Error tracking download of Episode {index+1}")
                          progress_bar.close()
                          slow_print("But the download should continue normally, I think.. .")
                          keyboard.unhook(pause_or_resume)         
                          pass
                if not error:
                    time.sleep(1)
                    progress_bar.update(episode_size-progress_bar.n)
                    progress_bar.set_description(f" Completed {anime_title} Episode {index+1}")
                    progress_bar.close()
                    if paused:                        
                        class event:
                            def __init__(self) -> None:
                                self.name = 'space'

                        pause_or_resume(event())
                    keyboard.unhook(pause_or_resume)         
                print("\n")
                return 1



        tmpDeleter(download_folder_path)
        
        #keeps track of the number of currently downloaded files
        file_count = 0
        #total number of files to be downloaded
        total_downloads = len(predicted_episodes_links)

        slow_print(" Give me a sec Senpai", "sec")

        while True:
                

                if not CompletionCheck(download_folder_path, total_downloads, file_count):

                    for index in range(total_downloads):
                        page_found = [False]
                        while not page_found[0]:
                            try:

                                #Selenium is used cause of the dynamically generated content
                                #get the pahewin predownload page
                                #browser_page.get(predicted_episodes_links[index])
                                pahewin_page = requests.get(predicted_episodes_links[index]).content

                                #wait for the link to be dynamically generated
                                slow_print(" ( ⚆ _ ⚆) Working on it.. .", "working")
                                animationThread = threading.Thread(target=loading_animation, args=(page_found, ))
                                animationThread.start()
                                #parse the new page with the link to the download page then search for the ddownload link
                                soup = BeautifulSoup(pahewin_page, "html.parser")
                                server_download_link = soup.find_all("a", class_="btn btn-primary btn-block redirect")[0]["href"]
                                #get the final download page
                                driver.get(server_download_link)      
                                #The difference btw the download page and the file page is that the latter has an d in the url where the other has a f
                                # who woulda though lol                 
                                server_download_link = server_download_link.replace("/f/", "/d/", 1)
                                #wait for a max of 10 seconds until the link is loaded in
                                WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.CSS_SELECTOR, 'form[action="%s"]' %server_download_link)))
                                #click the download link by submitting a dynamically generated form
                                driver.find_element(By.CSS_SELECTOR, 'form[action="%s"]' %server_download_link).submit()
                                #go to the download page to manage the download
                                driver.get(downloads_manager_page)
                                # Wait for the downloads-manager element to appear
                                WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, 'downloads-manager')))
                                page_found[0] = True
                            except:
                                #if the above lines fail then try again
                                #To kill the loading animation thread
                                page_found[0] = True
                                if not ping3.ping(google_com):
                                    slow_print(f" {internet_responses[randint(0, len(internet_responses)-1)]}")
                                    time.sleep(3)
                                page_found[0] = False
                        #wait for the file being downloaded to reflect in the download folder
                        slow_print(" ( ⚆ _ ⚆) Almost there.. .", "almost")
                        time.sleep(1)
                        file_count+=1

                        episode_index = predicted_episodes_indices[index]
                        download_exit_status = ProgressBar(predicted_episodes_sizes[index], download_folder_path, anime_title, episode_index)
                        exit_time = time.time()
                        if download_exit_status == 1:
                            while(StillDownloading(download_folder_path)):

                                if time.time() - exit_time > 60:
                                    driver.quit()
                                    #if one download takes more than 1 min to finish then try again
                                    return DownloadEpisodes(predicted_episodes_indices[index:], predicted_episodes_links[index:], predicted_episodes_sizes[index:], download_folder_path, anime_title)
                                time.sleep(2)
                            file_paths = list(pathlib.Path(download_folder_path).glob("*"))
                            # Sort the list by the creation time of the files
                            file_paths.sort(key=lambda x: os.path.getctime(x))
                            try:
                                downloaded_file = file_paths[-1]
                            except IndexError:
                                slow_print(" Baka you probably set the download folder to a folder that requires admin access, like I said instead of C:/Users/YourName/Downloads/Anime use C:/Users/PC/Downloads/Anime")
                                slow_print(" Next time when I ask if you want to use the saved settings say No then change the download folder, yapari baka ka")
                                return 0
                            episode_number = str(episode_index+1)
                            new_episode_name = anime_title+" Episode "+episode_number+".mp4"

                            new_folder_path = os.path.dirname(downloaded_file)
                            new_file_path = os.path.join(new_folder_path, new_episode_name)
                            os.rename(downloaded_file, new_file_path)
                            
                            if file_count-1 == 0:
                            #if the first download has completed then open the folder
                                os.startfile(new_folder_path)
                        if download_exit_status == 0:
                            driver.quit()
                            return DownloadEpisodes(predicted_episodes_indices[index:], predicted_episodes_links[index:], predicted_episodes_sizes[index:], download_folder_path, anime_title)
                                         

                else:
                    driver.quit()
                    #If the last download is complete then open the folder again
                    if file_count-1 != 0:
                        os.startfile(new_folder_path)
                    return 1

#Simply checks the status of downloads from DownloadEpisodes after automation is complete, print the messages depending on what DownloadEpisodes returns
#Takes DownloadEpisodes as the arguerment
def DownloadStatus(download_status):
    global mute
    if download_status:
        if mute:
            mute = False
            #To ensure the user is notified when all downloads are completed
            slow_print(" All downloads completed succesfully [(^O^)] , Senpwai ga saikyou no stando Da MUDA", "downloads complete")
            time.sleep(2)
            mute =  True
        else:
            slow_print(" All downloads completed succesfully [(^O^)] , Senpwai ga saikyou no stando Da MUDA", "downloads complete")
            time.sleep(2)
    elif not download_status:
        slow_print(" Download error :(. Please try again uWu\n")

#Once downloading is done prompts if the user wants to download more
def ContinueLooper():
    slow_print(" Would you like to continue downloading anime?", "continue downloading")
    reply = key_prompt()
    if len([n for n in no_list if n == reply]) > 0:
        exit_handler()
        return False
    elif len([y for y in yes_list if y == reply]) > 0:
        return True

#Predicts which episodes to download by detecting the ones that have already been downloaded then excluding them
def DynamicEpisodePredictor(download_folder_path, episode_links, anime_title, start_index, end_index):
    
    #pattern to find the episode files in the current defeault download folder
    #common ChatGpt W
    pattern = re.compile(r'\b{}\s+Episode\s+(\d+)\D.*'.format(anime_title))
    files = list(pathlib.Path(download_folder_path).glob("*"))

    already_available_episodes_indices = []
    for file_path in files:
        match = pattern.search(str(file_path))
        if match:
            episode_number = int(match.group(1))
            #Computer the indices of the already available episodes
            already_available_episodes_indices.append(episode_number-1)
        
    #Compute the indices of the episodes to be downloaded
    #Only add an episode if it's not in the already available episodes AND it's not an untracked episode i.e when the user specifies where to start
    predicted_episodes_indices = [episode_index for episode_index in range(len(episode_links)) if episode_index not in already_available_episodes_indices and episode_index >= start_index and episode_index <= end_index]
    predicted_episodes_links = [episode_links[predicted_episode_link] for predicted_episode_link in predicted_episodes_indices]
    return predicted_episodes_indices, predicted_episodes_links

#Calculates the total download size of the predicted episodes that are to be queued 
def DownloadSizeCalculator(predicted_episodes_sizes, download_folder_path):
    tmpDeleter(download_folder_path)
    return sum(predicted_episodes_sizes)

#Determeines from which episode to start downloading based of user input
def StartEpisodePrompt(episode_links):
    while True:
        slow_print(" Enter d for me to detect then download episodes you don't have OR\n Enter the episode number for me to start downloading from a specific episode OR\n Enter the episode number to start from followed by space or hyphen then the episode number to stop downloading to download in a specific range")
        reply = input(input_colour+"> ")
        print(output_colour, end="")

        if reply == "d":
            return 0, len(episode_links)-1
        else:
            try:
                start_index = int(reply)-1
                episode_links[start_index]
                return start_index, len(episode_links)-1
            except:
                try:
                    pattern = r"(\d+)[\s-]+(\d+)"
                    matches = re.findall(pattern, reply)
                    start_index, end_index = matches[0]
                    start_index = int(start_index)-1
                    end_index = int(end_index)-1

                    episode_links[start_index]
                    episode_links[end_index]
                    return start_index, end_index
                except:
                    slow_print(f" Invalid episode Bakayarou\n This anime has {len(episode_links)} episodes\n Maybe that episode isn't out yet\n")
                    pass

            

#Shows the calculated total download size to the user and prompts them if they want to continue
def SizePrompt(calculated_download_size):
    slow_print(f"The total download size is {calculated_download_size} MB. Continue? ")
    prompt_reply = key_prompt()
    
    if len([y for y in yes_list if y == prompt_reply]) > 0:
        slow_print(" If you experience any glitches, crashes, errors or failed downloads just restart the app :O\n If they persist post your issue on https://github.com/SenZmaKi/Senpwai/issues for my creator to hopefully address it\n")
        slow_print(" Tap spacebar to pause or resume downloads\n")
        slow_print(" Hol up let me cook", "hol up")
        return 1
        
    elif len([n for n in no_list if n == prompt_reply]) > 0:
        return 0
    
#Santises folder name to only allow names that windows can create a folder with
def sanitise_name(name):
    valid_chars = set(string.printable) - set('\\/:*?"<>|')
    sanitized = ''.join(filter(lambda c: c in valid_chars, name))
    return sanitized[:255].rstrip()

#Main program loop
def main():


    init(convert=True)
    mixer.init()
    print(output_colour, end="")
    slow_print(" Hewwo\n")
    if not mute:
        systems_online()
    
    slow_print(" Avoid clicking X to exit, Press Esc instead")
    slow_print(" Tap Alt+M to mute or unmute. This will be saved in settings\n")
    ProcessTerminator()
    InternetTest()
    VersionUpdater(current_version, repo_url, github_home_url, version_download_url)

    run = True
    while run:
        global automate
        automate = False

        anime_id, anime_title = AnimeSelection(Searcher())
        anime_title = sanitise_name(anime_title)

        #If the anime isn't found keep prompting the user
        while anime_id == 0 and anime_title == 0:
            anime_id, anime_title = AnimeSelection(Searcher())
        quality, sub_or_dub, default_download_folder_path = SaveSettings(senpwai_stuff_path)
        slow_print(" Just give me a moment, choto choto :P", "moment")

        #Links to the episodes
        episode_links = EpisodeLinks(anime_id)

        if not automate:
            start_index, end_index = StartEpisodePrompt(episode_links)
        elif automate:
            start_index = 0
            end_index = len(episode_links)-1

        download_folder_path = default_download_folder_path+"\\"+anime_title
        predicted_episodes_indices, predicted_episodes_links = DynamicEpisodePredictor(download_folder_path, episode_links, anime_title, start_index, end_index)
        #Split the generated links into download_links and info about the downloads i.e quality and size
        download_links, download_info = DownloadData(predicted_episodes_links)
        #From the download_info extract the sizes of each episode per quality
        download_sizes = DownloadSizes(download_info)
        #Based off the user's setting configure the links and sizes
        configured_download_links, configured_download_sizes = ConfigureDownloadData(download_links, download_sizes, quality, sub_or_dub)
        calculated_download_size = DownloadSizeCalculator(configured_download_sizes, download_folder_path)
        if not automate:
            size_prompt_reply = SizePrompt(calculated_download_size)
        elif automate:
            slow_print(f" Total download size is {calculated_download_size} MB")
            size_prompt_reply = 1

        if size_prompt_reply:

            if calculated_download_size > 0:                
                DownloadStatus(DownloadEpisodes(predicted_episodes_indices, configured_download_links, configured_download_sizes, download_folder_path, anime_title))
                run = ContinueLooper()
            
            elif  calculated_download_size <= 0:
                slow_print(" Oe, baka, there's nothing to download (-_-) ")
                slow_print(" You probably already have all the episodes of this anime ")
                run = ContinueLooper()
            
        elif not size_prompt_reply:
            slow_print(" Sadge :(")
            run = ContinueLooper()

    

if __name__ == "__main__":
   # stuff only to run when not called via 'import' here
   main()    
