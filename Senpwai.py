#Ignore the Run Cell etc, I was working with jupyter notebooks before I converted into python file
import requests
import json
import re
from bs4 import BeautifulSoup



from webdriver_manager.microsoft import EdgeChromiumDriverManager
from selenium.webdriver.edge.service import Service as EdgeService
from selenium.webdriver import EdgeOptions


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

import atexit
import sys

import psutil


current_version = "1.1.1"

home_url = "https://animepahe.ru/"
google_url = "https://google.com"
anime_url = home_url+"anime/"
api_url_extension = "api?m="
search_url_extension = api_url_extension+"search&q="
quality = "720p"
sub_or_dub = "sub"

yes_list = ["yes", "yeah", "1", "y", "ok", "k", "cool"]
no_list = ["no", "nope", "0", "n"]

default_download_folder_path = None
senpwai_stuff_path = "C:\\Senpwai_stuff"



repo_url = "https://github.com/SenZmaKi/Senpwai"
github_home_url =  "https://github.com"
version_download_url = "https://github.com/SenZmaKi/Senpwai/releases/download/"



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
        print(" Seems like there's a new version of me, guess I'm turning into an old hag XD")
        print(" Would you like to update to the new version? ")
        while True:
            reply = input("> ")

            if(len([y for y in yes_list if reply == y])>0):

                latest_version_download_url = version_download_url+"v"+latest_version+"/Senpwai.exe"        
                response = requests.get(latest_version_download_url, stream=True)
                total_size_in_bytes= int(response.headers.get('content-length', 0))
                block_size = 1024 #1 Kibibyte
                progress_bar = tqdm(total=total_size_in_bytes, unit='iB', unit_scale=True, desc=" Downloading younger me")
                updated_version_folder = ".\\Updated Senpwai"
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
                    print(" I will now open a folder containing the new me")
                    time.sleep(4)
                    os.startfile(updated_version_folder)
                    print(" Now just place that version of me in your location of choice, I advise you put me in the desktop so that we see each other everyday :)")
                    print(" Then delete this older me, it's been good Senpai, sayonara")
                    time.sleep(15)
                    sys.exit(" I don't wanna go :(")



            elif(len([n for n in no_list if reply == n])):
                print(" Ok but you'll probably run into some nasty bugs with this version")
                return 0

            else:
                print(" I dont understand what you mean, wakaranai")

def InternetTest():
    valid_connection = False
    mendokusai = 0
    while not valid_connection:
        print(" Testing for a valid internet connection.. .")
        try:
            internet_test = requests.get(google_url)
            print(" Success!!!\n")
            valid_connection = True

        except:
            mendokusai +=1
            time.sleep(2)
            print(" Baka you don't have an internet connection")
            if mendokusai >= 5:
                print(" What a drag\n")
                mendokusai = 0
            elif mendokusai < 5:
                print("\n")
            time.sleep(5)

#Kills all instances of drivers that may have been left running previously cause they result in errors and take up space
def ProcessTerminator():
    parent_name_edge = "msedgedriver.exe"
    parent_name_chrome = "chromedriver.exe"
    parents_processes_to_kill = []
    for child_process in psutil.process_iter(['pid', 'name']):
        child_process = psutil.Process(child_process.info['pid'])
        try:
            parent_process = child_process.parent()
            if parent_name_edge == parent_process.name() or parent_name_chrome == parent_process.name():
                parents_processes_to_kill.append(parent_process)
                child_process.terminate()
        except:
            pass
    for parent_process in parents_processes_to_kill:
        parent_process.terminate()
        time.sleep(5)
        return 1
    return 0
#Searches for the anime from the animepahe database
def Searcher():
    try:
        keyword = input(" Enter the name of the anime you want to download> ")
        full_search_url = home_url+search_url_extension+keyword
        response = requests.get(full_search_url)
        results = json.loads(response.content.decode("UTF-8"))["data"]
        return results
    except:
    #If the anime isn't found keep prompting the user
        print("\n I couldn't find that anime maybe check for a spelling error or try a different name? ")
        return Searcher()
    
#Prompts the user to select the index of the anime they want from a list of the search results and returns the id of the chosen anime
def AnimeSelection(results):
    while "anime_id" not in locals():    
        print(" Please enter the number belonging to the anime you want from the list below")
        for index, result in enumerate(results):
            print(f"  {index+1} {result['title']}")
        print(" Or if the anime isn't in the list above enter s to search again")
        try:
            index_of_chosen_anime = int(input("> "))-1
        except:
            return 0, 0

        if not index_of_chosen_anime < 0 and not len(results) <= index_of_chosen_anime:
            for index, result in enumerate(results):
                if index == index_of_chosen_anime:
                    anime_id = result["session"]
                    anime_title = result["title"]
                    return anime_id, anime_title
        else:
            print("\n Invalid number Senpai")
            return 0, 0
        
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
    #Issues a GET request to the server together with the id of the anime and returns a list of the links(not donwload links) to all the episodes of that anime
    response = requests.get(home_url+api_url_extension+"release&id="+anime_id+"&sort=episode_asc")
    episode_data = json.loads(response.content.decode("UTF-8"))["data"]
    episode_sessions = [episode["session"] for episode in episode_data]
    episode_links = [home_url+"play/"+anime_id+"/"+str(episode_session) for episode_session in episode_sessions]
    return  episode_links

#Splits the episode links into two datasets, the download_links, and the infomation about the downloads i.e quality 360p, 720p or 1080p and size in megabytes
def DownloadData(episode_links):
    download_data = []
    for episode_link in episode_links:
        episode_page = requests.get(episode_link).content
        soup = BeautifulSoup(episode_page, "html.parser")
        download_data.append(soup.find_all("a", class_="dropdown-item", target="_blank"))
    #Scrapes the download data of each episode and stores the links for each quality and dub or sub in a list which is contained in another list containing all episodes
    download_links = [[download_link["href"] for download_link in episode_data] for episode_data in download_data]
    #Scrapes the download data of each episode and stores the info for each quality and dub or sub in a list which is contained in another list containing all episodes
    download_info = [[episode_info.text.strip() for episode_info in episode_data] for episode_data in download_data] 
    return (download_links, download_info)   

#Returns the sizes of the downloads of each episode per quality in a 2D array i.e the outer array contains each episode, the inner array contains the 3 sizes for each individual episode since there are 3 video qualities 360p, 720p and 1080p
#Example [[Episode 1[size in 360p, size in 720p, size in 1080p]], [Episode 2[size in 360p, size in 720p, size in 1080p]]]
def DownloadSizes(download_info):
    #You dont have to understand what happens here cause even I don't lol, ChatGpt for the win
    #The function uses a regular expression to find an expression that matches it's "syntax" starts with ( and ends with MB)
    #This match is then striped of the MB part in order to convert it into an integer, but before that it is converted into a string cause re.findall returns a string
    #The string is then converted into an integer and voila we have the sizes of our episodes
    download_sizes = [[int("".join(re.findall(r'\((.*?)MB\)'.strip("MB"), episode_info))) for episode_info in episode_data] for episode_data in download_info]
    return download_sizes

#Based off user input provided in SettingsPrompt() (check line 288 for), configures setting for the downloads the quality and whether subbed or dubbed then returns values that refer to each setting

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
            quality = input("What quality do you want to download in uWu? 360p, 720p or 1080p> ").lower()
            quality = DownloadSettings(quality=quality)[0]

        met_conditions+=1

        sub_or_dub = DownloadSettings(sub_or_dub=sub_or_dub)[1]
        while sub_or_dub == "error":
            sub_or_dub = input("Sub or dub> ").lower()
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
    if config_path.is_file():
        print(" Would you like to uWuse the following swaved settings?")
        with open(config_path) as config_file:
            config_settings = json.load(config_file)
            print(f" Quality: {config_settings['quality']}")
            print(f" Default download folder: {config_settings['default_download_folder_path']}")
            print(f" Sub or dub: {config_settings['sub_or_dub']}")

            reply = False
        while not reply:
            reply = input("> ")
            if len([y for y in yes_list if y == reply]) > 0:
                quality, sub_or_dub = config_settings["quality"], config_settings["sub_or_dub"]
                default_download_folder_path = config_settings["default_download_folder_path"]
                quality, sub_or_dub = DownloadSettings(quality=quality)[0], DownloadSettings(sub_or_dub=sub_or_dub)[1]
                reply = True
                
            elif len([n for n in no_list if n == reply]) > 0:
                quality, sub_or_dub = SettingsPrompt()
                default_download_folder_path = SetDownloadFolderPath()
                save_dict = {"quality": quality, "sub_or_dub": sub_or_dub, "default_download_folder_path": default_download_folder_path}
                with open(config_path, "w") as config_file   :
                    json.dump(save_dict, config_file)
                reply = True
            else:
                print(" I don't understand what you mean. Yes or no?")
                reply = False

    elif not config_path.is_file():
        quality, sub_or_dub = SettingsPrompt()
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
    if sub_or_dub == "sub" or sub_or_dub == "s":
        configured_download_links = [episode_links[:3] for episode_links in download_links]
        configured_download_sizes = [episode_links[:3] for episode_links in download_sizes]
    elif sub_or_dub == "dub" or sub_or_dub == "d":
        if len(download_links[0]) == 3:
            print(" There seems to be no dub for this anime, switching to sub")
            configured_download_links = [episode_links[:3] for episode_links in download_links]
            configured_download_sizes = [episode_links[:3] for episode_links in download_sizes]
        elif len(download_links[0]) == 6:
            configured_download_links = [episode_links[3:] for episode_links in download_links]
            configured_download_sizes = [episode_links[3:] for episode_links in download_sizes]

    configured_download_links = [episode_links[quality] for episode_links in configured_download_links]
    configured_download_sizes = [episode_links[quality] for episode_links in configured_download_sizes]
    
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
#Alter at your risk, you have been warned
    
def DownloadEpisodes(predicted_episodes_indices, predicted_episodes_links, predicted_episodes_sizes, download_folder_path, anime_title):
        #with the way windows handles stuff without this line the anime wont be able to be downloaded to the C:\\ drive or D:\\ annoying ass bug
        fixed_download_folder_path = download_folder_path.replace("\\\\", "\\")


        #Installs browser driver manager and checks whether user is using supported browser then creates a webdriver object of the respective browser as a headless browser and returns it
        def SupportedBrowserCheck():

        #configures the settings for the headless browser
            edge_options = EdgeOptions()
            chrome_options = ChromeOptions()
            #firefox_options = FirefoxOptions()

            edge_options.add_argument("--headless=new")
            chrome_options.add_argument("--headless=new")
            #firefox_options.add_argument("--headless=new")


            edge_options.add_argument('--disable-extensions')
            chrome_options.add_argument('--disable-extensions')
            #firefox_options.add_argument('--disable-extensions')
            
            
            edge_options.add_argument('--disable-infobars')
            chrome_options.add_argument('--disable-infobars')
            #firefox_options.add_argument('--disable-infobars')
            
            
            edge_options.add_argument('--no-sandbox')
            chrome_options.add_argument('--no-sandbox')
            #firefox_options.add_argument('--no-sandbox')

            edge_options.add_experimental_option("prefs", {
                "download.default_directory": fixed_download_folder_path,
                "download.prompt_for_download": False,
                "download.directory_upgrade": True,
                "safebrowsing_for_trusted_sources_enabled": False,
                "safebrowsing.enabled": False
            })

            chrome_options.add_experimental_option("prefs", {
                "download.default_directory": fixed_download_folder_path,
                "download.prompt_for_download": False,
                "download.directory_upgrade": True,
                "safebrowsing_for_trusted_sources_enabled": False,
                "safebrowsing.enabled": False
            })

        
    #Installs Browser Driver Managers for the respective browsers, this is to be used by Selenium
            try:
                service_edge = EdgeService(executable_path=EdgeChromiumDriverManager().install())
                service_chrome = ChromeService(executable_path=ChromeDriverManager().install())
                #service_firefox = FirefoxService(executable_path=GeckoDriverManager().install())

                service_edge.creation_flags =  CREATE_NO_WINDOW
                service_chrome.creation_flags =  CREATE_NO_WINDOW
                #service_firefox.creation_flags =  CREATE_NO_WINDOW
                
                
            
            except:
                return 0

    #Checks whether user is using a supported browser then returns a webdriver object for the respective used browser
            try:
                driver_edge = webdriver.Edge(service=service_edge, options=edge_options)
                return driver_edge
            except:
                try:
                    driver_chrome = webdriver.Chrome(service=service_chrome, options=chrome_options)
                    return driver_chrome
                except:
                    print(" Sowwy the onwy supported browsers are Chrome, Edge")
                    webbrowser.open_new("https://google.com/chrome")

        browser_page = SupportedBrowserCheck()


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
    

        #absolute dogshit progress bar, fails half the time XD
        def ProgressBar(episode_size, download_folder_path, anime_title, index):
            

            with tqdm(total=round(episode_size), unit='MB', unit_scale=True, desc=f' Downloading {anime_title} Episode {index+1}') as progress_bar:
            # Loop until the download is complete
                download_complete = False
                error = False
                while not download_complete and not error:
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
                          print("But the download should continue normally, I think.. .")
                          pass
                if not error:
                    progress_bar.update(episode_size-progress_bar.n)
                    progress_bar.set_description(f" Completed {anime_title} Episode {index+1}")
                    progress_bar.close()
                print("\n")



        tmpDeleter(download_folder_path)
        
        #keeps track of the number of currently downloaded files
        file_count = 0
        #total number of files to be downloaded
        total_downloads = len(predicted_episodes_links)

        print(" Give me a sec Senpai")

        while True:
                

                if not CompletionCheck(download_folder_path, total_downloads, file_count):

                    for index in range(total_downloads):
                        page_not_found = True
                        while page_not_found:
                            try:

                                #Selenium is used cause of the dynamically generated content
                                #get the pahewin predownload page
                                browser_page.get(predicted_episodes_links[index])
                                #wait for the link to be dynamically generated
                                time.sleep(6)
                                print(" ( ⚆ _ ⚆) Working on it.. .")
                                #parse the new page with the link to the download page then search for the ddownload link
                                soup = BeautifulSoup(browser_page.page_source, "html.parser")
                                server_download_link = soup.find_all("a", class_="btn btn-primary btn-block redirect")[0]["href"]
                                #get the final download page

                                browser_page.get(server_download_link)                       
                                server_download_link = server_download_link.replace("/f/", "/d/", 1)
                                #click the download link by submitting a dynamically generated form
                                browser_page.find_element(By.CSS_SELECTOR, 'form[action="%s"]' %server_download_link).submit()
                                page_not_found = False
                            except:
                                page_not_found = False
                        #wait for the file being downloaded to reflect in the download folder
                        print(" ( ⚆ _ ⚆) Almost there.. .")
                        time.sleep(4)
                        file_count+=1
                        current_time = time.time()

                        episode_index = predicted_episodes_indices[index]
                        ProgressBar(predicted_episodes_sizes[index], download_folder_path, anime_title, episode_index)
                        while(StillDownloading(download_folder_path)):

                            if current_time - time.time() > 10800:
                                browser_page.quit()
                            #if one download takes more than 3 hours then exit as a fail
                                return 0
                            time.sleep(2)
                        file_paths = list(pathlib.Path(download_folder_path).glob("*"))
                        # Sort the list by the creation time of the files
                        file_paths.sort(key=lambda x: os.path.getctime(x))
                        downloaded_file = file_paths[-1]                            
                        episode_number = str(episode_index+1)
                        new_episode_name = anime_title+" Episode "+episode_number+".mp4"

                        new_folder_path = os.path.dirname(downloaded_file)
                        new_file_path = os.path.join(new_folder_path, new_episode_name)
                        os.rename(downloaded_file, new_file_path)
                        
                        if file_count-1 == 0:
                        #if the first download has completed then open the folder
                            os.startfile(new_folder_path)
                        
                        


                    

                else:
                    browser_page.quit()
                    #If the last download is complete then open the folder again
                    os.startfile(new_folder_path)
                    return 1

#Simply checks the status of downloads from DownloadEpisodes after automation is complete, print the messages depending on what DownloadEpisodes returns
#Takes DownloadEpisodes as the arguerment
def DownloadStatus(download_status):
    if download_status:
        return " All downloads completed succesfully [(^O^)] , Senpwai ga saikyou no stando Da MUDA"
    elif not download_status:
        return " Error while trying to download (⌣̩̩́_⌣̩̩̀) , you probably don't have an internet connection. Or something goofy happened on my end. Please try again uWu\nAlready downloaded episodes will be ignored, you can count on me"

#Once downloading is done prompts if the user wants to download more
def ContinueLooper():
    print(" Would you like to continue downloading anime?")
    reply = input("> ")
    if len([n for n in no_list if n == reply]) > 0:
        print("\n Exiting.. .")
        time.sleep(5)
        return False
    elif len([y for y in yes_list if y == reply]) > 0:
        return True

#Predicts which episodes to download by detecting the ones that have already been downloaded then excluding them
def DynamicEpisodePredictor(download_folder_path, configured_download_links, configured_download_sizes, anime_title, start_index):
    
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
    predicted_episodes_indices = [episode_index for episode_index in range(len(configured_download_links)) if episode_index not in already_available_episodes_indices and episode_index >= start_index]

    predicted_episodes_links = [configured_download_links[predicted_episode_link] for predicted_episode_link in predicted_episodes_indices]
    predicted_episodes_sizes = [configured_download_sizes[predicted_episode_size] for predicted_episode_size in predicted_episodes_indices]
    return predicted_episodes_indices, predicted_episodes_links, predicted_episodes_sizes

#Calculates the total download size of the predicted episodes that are to be queued 
def DownloadSizeCalculator(predicted_episodes_sizes, download_folder_path):
    tmpDeleter(download_folder_path)
    return sum(predicted_episodes_sizes)

#Determeines from which episode to start downloading based of user input
def StartEpisodePrompt(configured_download_links):
    print("I can either automatically detect the currently downloaded episodes in the folder then download ONLY the missing ones for example if there are no episodes I will start downloading from episode one and so on, but this only works if I'm the one that downloaded them, OR you can enter the episode from which you want to start downloading from")
    reply = input(" Enter d to automatically detect or enter the episode number to start from a specific episode> ")
    try:
        start_index = int(reply)-1
        try:
            configured_download_links[start_index]
            return start_index
        except: 
            while True:
                start_index = int(input("Enter a valid Episode, (*/\*) bakayarou> "))-1
                try:
                    configured_download_links[start_index]
                    return start_index
                except:
                    pass
    except:
        return 0

#Shows the calculated total download size to the user and prompts them if they want to continue
def SizePrompt(calculated_download_size):
    prompt_reply = input(f"The total download size is {calculated_download_size} MB. Continue? ")
    
    if len([y for y in yes_list if y == prompt_reply]) > 0:
        print(" If you experience any glitches, crashes, errors or failed downloads just restart the app :O\n If they persist post your issue on https://github.com/SenZmaKi/Senpwai/issues for my creator to hopefully address it\n")
        print(" Hol up let me cook")
        return 1
        
    elif len([n for n in no_list if n == prompt_reply]) > 0:
        return 0

#Main program loop


def __main__():

    print(" Hewwo\n")
    atexit.register(ProcessTerminator)
    ProcessTerminator()
    InternetTest()
    run = True
    VersionUpdater(current_version, repo_url, github_home_url, version_download_url)

    while run:
        anime_id, anime_title = AnimeSelection(Searcher())

        #If the anime isn't found keep prompting the user
        while anime_id == 0 and anime_title == 0:
            anime_id, anime_title = AnimeSelection(Searcher())
        print(" Just give me a moment, choto choto :P")
        #Links to the episodes
        episode_links = EpisodeLinks(anime_id)
        #Split the generated links into download_links and info about the downloads i.e quality and size
        download_links, download_info = DownloadData(episode_links)
        #From the download_info extract the sizes of each episode per quality
        download_sizes = DownloadSizes(download_info)
        quality, sub_or_dub, default_download_folder_path = SaveSettings(senpwai_stuff_path)
        download_folder_path = default_download_folder_path+"\\"+anime_title
        #Based off the user's setting configure the links and sizes
        configured_download_links, configured_download_sizes = ConfigureDownloadData(download_links, download_sizes, quality, sub_or_dub)

        start_index = StartEpisodePrompt(configured_download_links)
        predicted_episodes_indices, predicted_episodes_links, predicted_episodes_sizes = DynamicEpisodePredictor(download_folder_path, configured_download_links, configured_download_sizes, anime_title, start_index)
        calculated_download_size = DownloadSizeCalculator(predicted_episodes_sizes, download_folder_path)

        size_prompt_reply = SizePrompt(calculated_download_size)

        if size_prompt_reply:

            if calculated_download_size > 0:
                print(DownloadStatus(DownloadEpisodes(predicted_episodes_indices, predicted_episodes_links, predicted_episodes_sizes, download_folder_path, anime_title)))
                run = ContinueLooper()
            
            elif  calculated_download_size <= 0:
                print(" Oe, baka, there's nothing to download (-_-) ")
                print(" You probably already have all the episodes of this anime ")
                run = ContinueLooper()
            
        elif not size_prompt_reply:
            print(" Sadge :(")
            run = ContinueLooper()

    print(" ( ͡° ͜ʖ ͡°) Sayonara")
    ProcessTerminator()

    try:
        sys.exit()
    except:
        os._exit(1)

__main__()
    
