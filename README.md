# Senpwai - Anime Tracker & Batch Downloder

![senpwai-icon](https://github.com/SenZmaKi/Senpwai/blob/master/src/senpwai-icon.png)

**Senpwai** is a blazingly fast and extremely convenient desktop app for batch downloading anime or tracking then automatically downloading new episodes of an anime as they come out. 


<p>
 <a href="https://github.com/SenZmaKi/Senpwai/releases"><img  height="30px" src="https://img.shields.io/github/downloads/SenZmaKi/Senpwai/total" alt="Downloads"></a>
  <a href="https://discord.gg/invite/e9UxkuyDX2" target="_blank"><img height="30px" alt="Discord" src="https://img.shields.io/discord/1131981618777702540?label=Discord&logo=discord"></a>
  <a href="https://www.reddit.com/r/Senpwai" target="_blank"><img height="30px" alt="Subreddit subscribers" src="https://img.shields.io/reddit/subreddit-subscribers/senpwai?label=Reddit&style=social"></a>


![image](https://github.com/SenZmaKi/Senpwai/assets/90490506/04a9cfba-7961-48b8-b8ff-392aaef5b4d4)


## Table of Contents
1. [Installation](#installation)
2. [Features](#features)
3. [Building from Source](#building-from-source)
4. [Support](#support)
5. [FAQ](#faq)
6. [Links](#links)
7. [Legal Disclaimer](#legal-disclaimer)
8. [Epilogue](#epilogue)

## Installation

- **Windows**
  
Download the setup from the [releases page](https://github.com/SenZmaKi/Senpwai/releases) and run it.

- **Linux/Mac**
  
 You'll have to [build from source](#building-from-source).

## Features

- Download any anime from [Animepahe](https://animepahe.ru) or [Gogoanime](https://gggoanimehd.io).
- Download a complete season or episodes within a range (e.g., 69-420).
- Choose between video qualities: 360p, 480p (Gogoanime only), 720p, or 1080p.
- Download in sub or dub (if available) depending on the user's preference.
- Automatically detects episodes you already have and avoids re-downloading them.
- Keep track of an anime and automatically download new episodes when they come out.
- Robust and graceful download error management.
- Goofy aah ahh GUI and Amogus.


## Building from Source

Ensure you have [Python](https://www.python.org/downloads/) (version 3.11 or newer) and [Git](https://github.com/git-guides/install-git) installed. For Linux users you also have to create a [Python virtual environment](https://docs.python.org/3/library/venv.html), the same is recommended for Mac and Windows, but you don't have to.


1. Clone the repository.

```
git clone https://github.com/SenZmaKi/Senpwai
```

2. Install the dependencies.

```
cd Senpwai
cd src
pip install -r requirements.txt
```

3. Run the app.

```
python senpwai.py
```


## Support

- You can support the development of Senpwai through donations on [GitHub Sponsors](https://github.com/sponsors/SenZmaKi) or [Patreon](https://patreon.com/Senpwai).
- You can also leave a star on the github for more weebs to know about it.
- Senpwai is open to pull requests, so if you have ideas for improvements, feel free to contribute!

## FAQ

<details> <summary> What is HLS mode? </summary>
 
HLS mode attempts to fix the problem of Captcha block with Gogoanime Normal mode. 
In HLS mode Gogoanime downloads are guaranteed to work, though with a few downsides:

- Requires [FFmpeg](https://www.hostinger.com/tutorials/how-to-install-ffmpeg) to be installed, though Senpwai can attempt to automatically install it for you.
  
- Ongoing downloads can't be paused.
  
- No download progress indication, the progress bars only indicate the completion of downloading each episode.
  
- May occasionally crash if you don't have an unstable internet connection.

</details>

<details> <summary> Do you intend to add more sources? </summary> 

One person can only do so much, I only plan on adding another source if something ever happens to Animepahe or Gogoanime.
More sources means more writing more code which in turn means fixing more bugs.

</details>


## Links

[Sub-reddit](https://reddit.com/r/Senpwai)

[Discord server](https://discord.com/invite/e9UxkuyDX2)

[GitHub Sponsors](https://github.com/sponsors/SenZmaKi)

[Patreon](https://patreon.com/Senpwai)

## Legal Disclaimer

Senpwai is designed solely for providing access to publicly available content. It is not intended to support or promote piracy or copyright infringement. As the creator of this app, I hereby declare that I am not responsible for, and in no way associated with, any external links or the content they direct to.

It is essential to understand that all the content available through this app are found freely accessible on the internet and the app does not host any copyrighted content. I do not exercise control over the nature, content, or availability of the websites linked within the app.

If you have any concerns or objections regarding the content provided by this app, please contact the respective website owners, webmasters, or hosting providers. Thank you.

## Epilogue

Truly one of the most apps ever of all time.
