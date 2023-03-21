#!/usr/bin/env python
# coding: utf-8

# In[ ]:


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

home_url = "https://animepahe.ru/"
google_url = "https://google.com"
anime_url = home_url+"anime/"
api_url_extension = "api?m="
search_url_extension = api_url_extension+"search&q="
quality = "720p"
sub_or_dub = "sub"

yes_list = ["yes", "yeah", "1", "y"]
no_list = ["no", "nope", "0", "n"]

default_download_folder_path = None
senpwai_stuff_path = "C:\\Senpwai_stuff"


valid_connection = False
mendokusai = 0
download_again = True

#main program loop
while download_again:
#tests if user has a valid internet connection
    while not valid_connection:
        print("Testing for a valid internet connection.. .")
        try:
            internet_test = requests.get(google_url)
            print("Success!!!\n")
            valid_connection = True

        except:
            mendokusai +=1
            time.sleep(2)
            print("Baka you don't have an internet connection")
            if mendokusai >= 5:
                print("What a drag\n")
                mendokusai = 0
            elif mendokusai < 5:
                print("\n")
            time.sleep(5)
        

    #Searches for the anime in the animepahe database
    def Searcher():
        try:
            keyword = input("Enter the name of the anime you want to download> ")
            full_search_url = home_url+search_url_extension+keyword
            response = requests.get(full_search_url)
            results = json.loads(response.content.decode("UTF-8"))["data"]
            return results
        except:
            print("\nI couldn't find that anime maybe check for a spelling error or try a different name? ")
            return Searcher()



    # In[ ]:

    #Prompts the user to select the index of the anime they want from a list of the search results and returns the id of the chosen anime
    def AnimeSelection(results):
        while "anime_id" not in locals():    
            print("Please enter the number belonging to the anime you want from the list below")
            for index, result in enumerate(results):
                print(f" {index+1} {result['title']}")
            print("Or if the anime isn't in the list above enter s to search again")
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
                print("\nInvalid number Senpwai")
                return 0, 0
            
    anime_id, anime_title = AnimeSelection(Searcher())

    while anime_id == 0 and anime_title == 0:
        anime_id, anime_title = AnimeSelection(Searcher())


    # In[ ]:


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





    # In[ ]:

    print("Just give me a moment, choto choto")

    #Issues a GET request to the server together with the id of the anime and returns a list of the links(not donwload links) to all the episodes of that anime
    def EpisodeLinks(anime_id):
        response = requests.get(home_url+api_url_extension+"release&id="+anime_id+"&sort=episode_asc")
        episode_data = json.loads(response.content.decode("UTF-8"))["data"]
        episode_sessions = [episode["session"] for episode in episode_data]
        episode_links = [home_url+"play/"+anime_id+"/"+str(episode_session) for episode_session in episode_sessions]
        return  episode_links

    episode_links = EpisodeLinks(anime_id)




    # In[ ]:





    # In[ ]:


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
    download_links, download_info = DownloadData(episode_links)


    # In[ ]:


    #Returns the sizes of the downloads
    def DownloadSizes(download_info):
        #You dont have to understand what happens here cause even I don't lol, ChatGpt for the win
        #The function uses a regular expression to find an expression that matches it's "syntax" starts with ( and ends with MB)
        #This match is then striped of the MB part in order to convert it into an integer, but before that it is converted into a string cause re.findall returns a string
        #The string is then converted into an integer and voila we have the sizes of our episodes
        download_sizes = [[int("".join(re.findall(r'\((.*?)MB\)'.strip("MB"), episode_info))) for episode_info in episode_data] for episode_data in download_info]
        return download_sizes

    download_sizes = DownloadSizes(download_info)


    # In[ ]:





    # In[ ]:


    #Prompts the user for the settings of their downloads, the quality and whether subbed or dubbed

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
                quality = input("What quality do you want to download in Senpwai uWu? 360p, 720p or 1080p> ").lower()
                quality = DownloadSettings(quality=quality)[0]

            met_conditions+=1

            sub_or_dub = DownloadSettings(sub_or_dub=sub_or_dub)[1]
            while sub_or_dub == "error":
                sub_or_dub = input("Sub or dub> ").lower()
                sub_or_dub = DownloadSettings(sub_or_dub=sub_or_dub)[1]
            met_conditions+=1
        return quality, sub_or_dub



        


    # In[ ]:


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
            print("Would you like to uWuse the following swaved settings?")
            with open(config_path) as config_file:
                config_settings = json.load(config_file)
                print(f"Quality: {config_settings['quality']}")
                print(f"Default download folder: {config_settings['default_download_folder_path']}")
                print(f"Sub or dub: {config_settings['sub_or_dub']}")

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
                    print("I don't understand what you mean. Yes or no?")
                    reply = False

        elif not config_path.is_file():
            quality, sub_or_dub = SettingsPrompt()
            default_download_folder_path = SetDownloadFolderPath()
            save_dict = {"quality": quality, "sub_or_dub": sub_or_dub, "default_download_folder_path": default_download_folder_path}
            with open(config_path, "w") as config_file   :
                json.dump(save_dict, config_file)
            
        return quality, sub_or_dub, default_download_folder_path


    quality, sub_or_dub, default_download_folder_path = SaveSettings(senpwai_stuff_path)
    download_folder_path = default_download_folder_path+"\\"+anime_title


    # In[ ]:


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
                print("There seems to be no dub for this anime, switching to sub")
                configured_download_links = [episode_links[:3] for episode_links in download_links]
                configured_download_sizes = [episode_links[:3] for episode_links in download_sizes]
            elif len(download_links[0]) == 6:
                configured_download_links = [episode_links[3:] for episode_links in download_links]
                configured_download_sizes = [episode_links[3:] for episode_links in download_sizes]

        configured_download_links = [episode_links[quality] for episode_links in configured_download_links]
        configured_download_sizes = [episode_links[quality] for episode_links in configured_download_sizes]
        
        return configured_download_links, configured_download_sizes
    configured_download_links, configured_download_sizes = ConfigureDownloadData(download_links, download_sizes, quality, sub_or_dub)
    total_download_size = sum(configured_download_sizes)


    #Delete every file that ends with .crdownload or .tmp which are temporarily held on files as browser downloads since they will cause errors later on
    def tmpDeleter(download_folder_path): 
        files = pathlib.Path(download_folder_path).glob("*")
        #Checks for temporary files
        for f in files:
            if f.suffix == ".crdownload" or f.suffix == ".tmp":
                #deletes the temporary file
                f.unlink()

    def DownloadSizeCalculator(configured_download_sizes, download_folder_path):
        running_instance = True
        while running_instance:
            try:
                tmpDeleter(download_folder_path)
                running_instance = False
            except:
                print("Please restart your computer, this program uses a headless browser and there seems to be one that has gone rogue :O")
                print("And it is 1 billion percent not my fault :O\n")
                time.sleep(5)

        files = pathlib.Path(download_folder_path).glob("*")
        file_count = len(list(files))
        download_size = sum(configured_download_sizes[file_count:])
        return download_size


    # In[ ]:



    #Automates download process
    #This is some pretty sensitive code especially the file manipulation part, most of it is Supaghetti code and I don't understand how half of it works
    #Alter at your risk, you have been warned
    def DownloadEpisodes(configured_download_links, download_folder_path, configured_download_sizes, anime_title):
        #with the way winows handles stuff without this line the anime wont be able to be downloaded to the C:\\ drive or D:\\ annoying ass bug
        fixed_download_folder_path = download_folder_path.replace("\\\\", "\\")




    #Installs browser driver manages and checks whether user is using supported browser then creates a webdriver object of the respective browser as a headless browser and returns it
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
                    print("Sowwy the onwy supported browsers are Chrome, Edge")
                    webbrowser.open_new("https://google.com/chrome")

        browser_page = SupportedBrowserCheck()

                    


        #Warning!!! sensitive supaghetti code, alter at your risk

            


        #Check whether downloads are complete and returns True or False
        def CompletionCheck(download_folder_path, total_downloads):
            files = pathlib.Path(download_folder_path).glob("*")
            file_count = len(list(files))
            files = pathlib.Path(download_folder_path).glob("*")
        #search for .tmp or .crdownload file which means downloads are still in progress
            for f in files:
                if f.suffix == ".crdownload" or f.suffix == ".tmp":
                    time.sleep(2)
                    return 0
        #check if the the number of files is is less than the total number of files to be download
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
        def ProgressBar(total_size, download_folder_path, anime_title, index):
            

            with tqdm(total=round(total_size), unit='MB', unit_scale=True, desc=f'Downloading {anime_title} Episode {index+1}') as progress_bar:
            # Loop until the download is complete
                download_complete = False
                while not download_complete:
                    try:
                        download_file = list(pathlib.Path(download_folder_path).glob("*"))
                        # Calculate the progress of the download
                        current_size = round(os.path.getsize(download_file[-1])/1000000)
                        # Update the progress bar
                        progress_bar.update(current_size - progress_bar.n)
                        # Check if the download is complete
                        if current_size >= total_size:
                            download_complete = True
                    except:
                        download_complete = True
                        pass
                progress_bar.update(total_size-progress_bar.n)
                progress_bar.set_description(f"Completed {anime_title} Episode {index+1}")
                progress_bar.close()
                print("\n")
        

        tmpDeleter(download_folder_path)
        
        files = pathlib.Path(download_folder_path).glob("*")
        file_count = len(list(files))
        start_index = file_count
        total_downloads = len(configured_download_links)

        try:
            while True:

                    if not CompletionCheck(download_folder_path, total_downloads):

                        if file_count < total_downloads:
                            for index in range(start_index, total_downloads):
                                page_not_found = True
                                while page_not_found:
                                    try:
                                        files = pathlib.Path(download_folder_path).glob("*")

                                        #Selenium is used causse of the dynamically generated content
                                        #get the pahewin predownload page
                                        browser_page.get(configured_download_links[index])
                                        #wait for the link to be dynamically generated
                                        time.sleep(6)
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
                                time.sleep(2)
                                file_count+=1
                                current_time = time.time()

                                ProgressBar(configured_download_sizes[index], download_folder_path, anime_title, index)
                                while(StillDownloading(download_folder_path)):

                                    if current_time - time.time() > 10800:
                                        browser_page.quit()
                                    #if one download takes more than 3 hours then exit as a fail
                                        return 0
                                    time.sleep(2)
                                #if the first download has completed then open the folder
                                if index - start_index == 0:
                                    os.startfile(download_folder_path)
                                


                            
                        else:
                            #wait before checking for completion again
                            time.sleep(2)
                    else:
                        browser_page.quit()
                        os.startfile(download_folder_path)
                        return 1
        except:
            try:
                browser_page.quit()
                return 0
            except:
                return 0


            
        


    def DownloadStatus(download_status):
        if download_status:
            return "All downloads completed succesfully, Senpwai ga saikyou no stando Da MUDA"
        elif not download_status:
            return "Error while trying to download, you probably don't have an internet connection, Baka. Or something goofy happened on my end. Please try again uWu\nAlready downloaded episodes will be ignored, you can count on me"


    def ContinueLooper():
        print("Would you like to continue downloading anime?")
        reply = input("> ")
        if len([n for n in no_list if n == reply]) > 0:
            print("\nExiting.. .")
            time.sleep(5)
            return False
        elif len([y for y in yes_list if y == reply]) > 0:
            return True

    prompt_reply = input(f"The total download size is {DownloadSizeCalculator(configured_download_sizes, download_folder_path)} MB. Continue? ")
    if len([y for y in yes_list if y == prompt_reply]) > 0:
        print("If you experience any glitches, crashes, errors or failed downloads just restart the app :O\nIf they persist check https://github.com/SenZmaKi/Senpwai for a new version of me\nOr post your issue on https://github.com/SenZmaKi/Senpwai/issues for my creator to hopefully address it\n")
        print("Hol up let me cook")
        print("Getting things ready.. .")
        print(DownloadStatus(DownloadEpisodes(configured_download_links, download_folder_path, configured_download_sizes, anime_title)))
        download_again = ContinueLooper()
        
        exit = True
    elif len([n for n in no_list if n == prompt_reply]) > 0:
        print("Sadge :(")
        download_again = ContinueLooper()

print("Sugoma")


# In[ ]:




