
import requests
import json
from bs4 import BeautifulSoup
home_url = "https://animepahe.ru/"
anime_url = home_url+"anime/"
api_url_extension = "api?m="
search_url_extension = api_url_extension+"search&q="
quality = "720p"
sub_or_dub = "sub"

#keyword = input("Enter the name of the anime you want to download> ")

keyword = "Boku no hero"

full_search_url = home_url+search_url_extension+keyword


response = requests.get(full_search_url)
results = json.loads(response.content.decode("UTF-8"))["data"]



print("Please enter the number belonging to the anime you want from the list below")
for index, result in enumerate(results):
    print(index+1, result["title"])

#index_of_chosen_anime = input("Number> ")-1
index_of_chosen_anime = 5


for index, result in enumerate(results):
    if index == index_of_chosen_anime:
        anime_id = result["session"]
        break

anime_id


response = requests.get(home_url+api_url_extension+"release&id="+anime_id+"&sort=episode_asc")
episodes = json.loads(response.content.decode("UTF-8"))["data"]
test_episode = home_url+"play/"+anime_id+"/"+str(episodes[0]["session"])



response = requests.get(test_episode)
page = response.content
soup = BeautifulSoup(page, "html.parser")
episode_links = soup.find_all("a", class_="dropdown-item", target="_blank")

quality = input("What quality do you want to download in Senpwai uWu? 360p, 720p or 1080p> ")

def quality_chooser(quality="720"):
    if quality == "360p" or quality == "360":
        return 0
    elif quality == "720p" or quality =="720":
        return 1
    elif quality == "1080p" or quality =="1080":
        return 2
    else:
        return "error"

while(True):
    if quality_chooser == "error":
        sub_or_dub = input("Pwease enter a valid choice Senpai> ")
    else:
        break


sub_or_dub = input("Sub or dub> ")

while(True):
    if sub_or_dub.lower() == "sub":
        link = [link["href"] for link in episode_links[:3]]
        break
    elif sub_or_dub.lower() == "dub":
        link = [link["href"] for link in episode_links[3:]]
        print(link)
        break
    else:
        sub_or_dub = input("Please enter a valid choice Senpwai> ")





download_page = requests.get(link[quality_chooser(quality)])

print(link[quality_chooser(quality)])


