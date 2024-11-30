# Senpcli

The CLI alternative for Senpwai.

## Installation

-   **Windows 10/11**

You can install Senpcli as a completely separate package by downloading and running [the setup](https://github.com/SenZmaKi/Senpwai/releases/latest/download/Senpcli-setup.exe).

-   **Cross-platform (Linux, Mac, Windows 10/11)**

Needs [Python 3.11](https://www.python.org/downloads/release/python-3119)+ installed.

Senpwai ships with the Senpcli pre-installed.

```bash
pip install senpwai
```

-   **Android (Using [termux](https://github.com/termux/termux-app), note that the android port is currently really buggy and barely even works)**

***CURRENTLY BROKEN !!!***

```sh
pkg update -y && curl https://raw.githubusercontent.com/SenZmaKi/Senpwai/master/termux/install.sh | bash
```

-   **Other**

[Build from source](#building-from-source).

## Usage

```bash
senpcli [-h] [-v] [-sd {sub,dub}] [-s {pahe,gogo}] [-se] [-ee] [-q {1080p,720p,480p,360p}] [-hls] [-sc] [-msd] [-of] [-cta] [-ata] [-rta] [-ddl] title
```

### Positional Arguments

-   `title`: Title of the anime to download

### Options

-   `-h, --help`: Show help message and exit
-   `-v, --version`: Show program's version number and exit
-   `-c, --config` Show config file contents and location
-   `-u, --update` Check for updates
-   `-s {pahe,gogo}, --site {pahe,gogo}`: Site to download from
-   `-se, --start_episode`: Episode to start downloading at
-   `-ee, --end_episode`: Episode to stop downloading at
-   `-q {1080p,720p,480p,360p}, --quality {1080p,720p,480p,360p}`: Quality to download the anime in
-   `-sd {sub,dub}, --sub_or_dub {sub,dub}`: Whether to download the subbed or dubbed version of the anime
-   `-hls, --hls`: Use HLS mode to download the anime (Gogo only and requires FFmpeg to be installed)
-   `-of, --open_folder`: Open the folder containing the downloaded anime once the download finishes
-   `-msd, --max_simultaneous_downloads`: Maximum number of simultaneous downloads
-   ` -cta, --check_tracked_anime`: Check tracked anime for new episodes then download
-   `-ata, --add_tracked_anime`: Add an anime to the tracked anime list. Use the anime's title as it appears on your tracking site
-   `-rta, --remove_tracked_anime`: Remove an anime from the tracked anime list
-   `-ddl, --direct_download_links`: Print direct download links instead of downloading

### Settings

Senpcli by default uses your settings from Senpwai. You can find the location of settings.json by running

```sh
senpcli --config
```

## Building from Source
Ensure you have [Python 3.11](https://www.python.org/downloads/release/python-3119) (3.11 specifically!!!) and [Git](https://github.com/git-guides/install-git) installed.

Open a terminal and run the following commands.

1. **Set everything up.**

```
git clone https://github.com/SenZmaKi/Senpwai --depth 1 && cd Senpwai && pip install -r dev-requirements.txt && poetry install
```

2. **Build the tool into an executable.**

```
poetry run poe build_senpcli_exe
```

-   The executable will be built in `Senpwai\build\Senpcli`

3. **Alternatively you can instead run the tool directly via Python.**

-   Activate virtual environment

```
poetry shell
```

-   Run the tool

```
python -m senpcli --help
```

-   Both steps at once, but it is slower since it activates the virtual environment every time

```
poetry run senpcli --help
```
