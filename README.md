# Senpwai - Bulk Anime Downloader

![senpwai-icon](https://github.com/SenZmaKi/Senpwai/blob/master/app/senpwai-icon.png)

**Senpwai** is a free and open-source desktop app designed for conveniently downloading anime in bulk. Ever thought, "Damn, I wish I could download all the One Piece episodes in a few clicks," well, that's exactly what Senpwai is built for, ignoring the occasional crashes *cough* *cough*.
The episodes are sourced from Animepahe and Gogoanime though Animepahe is recommended cause with Gogoanime you may encounter captcha block.

<p>
 <a href="https://github.com/SenZmaKi/Senpwai/releases"><img  height="30px" src="https://img.shields.io/github/downloads/SenZmaKi/Senpwai/total" alt="Downloads"></a>
  <a href="https://discord.gg/invite/e9UxkuyDX2" target="_blank"><img height="30px" alt="Discord" src="https://img.shields.io/discord/1131981618777702540?label=Discord&logo=discord"></a>
  <a href="https://www.reddit.com/r/Senpwai" target="_blank"><img height="30px" alt="Subreddit subscribers" src="https://img.shields.io/reddit/subreddit-subscribers/senpwai?label=Reddit&style=social"></a>

![download-page](https://github.com/SenZmaKi/Senpwai/assets/90490506/4a376a4f-bcaa-4f76-b3a3-68782580e4ed)

## Table of Contents
1. [Installation](#installation)
2. [Features](#features)
3. [Building from Source](#building-from-source)
4. [Support](#support)
5. [Links](#links)
6. [Legal Disclaimer](#legal-disclaimer)
7. [Epilogue](#epilogue)

## Installation

- **Windows**
  
Download the setup from the [releases](https://github.com/SenZmaKi/Senpwai/releases) page and run it.

- **Linux/Mac**
  
 You'll have to build it from source or use it as a Python script.

## Features

- Download any anime from Animepahe or Gogoanime.
- Download a complete season or episodes within a range (e.g., 69-420).
- Download in sub or dub (if available) depending on the user's preference.
- Choose between video qualities: 360p, 480p (Gogoanime only), 720p, or 1080p.
- Automatically detects episodes you already have and avoids re-downloading them.
- Robust and graceful download error management.
- Goofy aah ahh GUI and Amogus.


## Building from Source

Ensure you have [Python](https://www.python.org/downloads/) (version 3.11 or newer) and [Git](https://github.com/git-guides/install-git) installed. For Linux users, it's recommended to create a [Python virtual environment](https://docs.python.org/3/library/venv.html).


1. Clone the repository.

```
git clone https://github.com/SenZmaKi/Senpwai
```

2. Install the dependencies.

```
cd Senpwai
pip install -r requirements.txt
```

3. Run the app as a normal script.

```
cd app
python senpwai.py
```

4. Alternatively, you can build it into an executable and then run it.

- **Linux and Mac**

```
cd app
pyinstaller --windowed --name=Senpwai --icon=assets/senpwai-icon.ico --add-data "assets:assets" senpwai.py
dist/Senpwai/Senpwai
```

- **Windows**

```
cd app
pyinstaller --windowed --name=Senpwai --icon=assets\senpwai-icon.ico --add-data "assets;assets" --version-file=file_version_info.txt senpwai.py
dist\Senpwai\Senpwai
```

## Support

- You can support the development of Senpwai through donations on [GitHub Sponsors](https://github.com/sponsors/SenZmaKi) or [Patreon](https://patreon.com/Senpwai).
- You can also show your appreciation by leaving a star on the gituhb.
- Senpwai is open to pull requests, so if you have ideas for improvements, feel free to contribute!

## Links

[Sub-reddit](https://reddit.com/r/Senpwai)

[Discord server](https://discord.com/invite/e9UxkuyDX2)

[GitHub Sponsors](https://github.com/sponsors/SenZmaKi)

[Patreon](https://patreon.com/Senpwai)

## Legal Disclaimer

Senpwai is designed solely for providing access to publicly available content. It is not intended to support or promote piracy or copyright infringement. As the creator of this app, I hereby declare that I am not responsible for, and in no way associated with, any external links or the content they direct to.

It is essential to understand that all the content available through this app are found freely accessible on the internet, and the app does not host any copyrighted content. I do not exercise control over the nature, content, or availability of the websites linked within the app.

If you have any concerns or objections regarding the content provided by this app, please contact the respective website owners, webmasters, or hosting providers.

## Epilogue

Truly one of the most apps ever of all time
