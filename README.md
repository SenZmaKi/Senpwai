# Senpwai

 Free and open source windows console app written in python that automates downloading complete seasons or batches of an anime

The app applies web scraping techniques using BeautifulSoup and Selenium to automate the download process

The episodes are sourced from animepahe

Wrote it cause I got tired of clicking links upon links and a having a billion tabs on my browser, Mendokusai naa

[Video demo](https://youtu.be/JHWPWLrmrlE)

## Capabilities
- Download any anime

- Download a complete season or episodes within a range e.g 14-21

- Download either sub or dub depending on user's preference

- Download anime in either 360p, 720p or 1080p depending on user's preference

- Automatically detect and keep track of already downloaded episodes then avoid downloading them

- Calculate then show the total download size to the user

- Cool sound and vfx, at least in my opinion lol


## Installation

### Pre-requisites

- Only Windows OS is currently supported

- You'll need to also have Google Chrome installed


### For the non-tech savvy users

I built the python script to an executable (app), the link to the releases is down below:

https://github.com/SenZmaKi/Senpwai/releases

Just run it normally like an app, Senpwai will handle the rest



### For the nerds

To install all the libraries I used in your virtual environment, once you clone the repository run 

```pip install -r requirements.txt```

Rename the global variable ```app_name``` to whatever window you're running the code from in order for the script to register your keyboard inputs

Then just run the code as you would normally do

If you want to build it into an executable like I did; 

- First install pyinstaller, it's not included in the requirements cause it's not actually used in the source code, it's just used to build the script into an exe
```pip install pyinstaller```

- Then run
```pyinstaller --onefile --icon=Senpwai_icon.ico --add-data "audio;audio" Senpwai.py```

## Disclaimer
It is preferable to use the python script since your antivirus may flag the executable as malware cause I basically converted the python script into an executable, this video explains it: https://youtu.be/bqNvkAfTvIc?t=100. The complete source code is up on the repo.


## Epilogue
She may not be the cleanest, the most well documented or the most optimised but she's my first ever real project so she holds a special place in my black heart

Gambarte and take care of Senpwai for me, she's a fragile one

## Donations

[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/SenZmaKi)
