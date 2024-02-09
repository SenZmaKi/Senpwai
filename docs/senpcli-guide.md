# Senpcli

The CLI alternative for Senpwai.

## Installation

- **Windows 10/11**

Senpwai ships with the Senpcli executable preinstalled but you can install Senpcli as a completely seperate package by downloading and running [the setup](https://github.com/SenZmaKi/Senpwai/releases/latest/download/Senpcli-setup.exe).

- **Linux/Mac**

You'll have to [build from source](#building-from-source).

## Usage

```bash
senpcli [-h] [-v] [-sd {sub,dub}] [-s {pahe,gogo}] [-se START_EPISODE] [-ee END_EPISODE] [-q {1080p,720p,480p,360p}] [-hls] [-sc] [-msd] [-of] title
```

### Positional Arguments

- `title`: Title of the anime to download

### Options

- `-h, --help`: Show help message and exit
- `-v, --version`: Show program's version number and exit
- `-sd {sub,dub}, --sub_or_dub {sub,dub}`: Whether to download the subbed or dubbed version of the anime
- `-s {pahe,gogo}, --site {pahe,gogo}`: Site to download from
- `-se START_EPISODE, --start_episode START_EPISODE`: Episode to start downloading at
- `-ee END_EPISODE, --end_episode END_EPISODE`: Episode to stop downloading at
- `-q {1080p,720p,480p,360p}, --quality {1080p,720p,480p,360p}`: Quality to download the anime in
- `-hls, --hls`: Use HLS mode to download the anime (Gogo only and requires FFmpeg to be installed)
- `-sc, --skip_calculating`: Skip calculating the total download size (Gogo only)
- `-of, --open_folder`: Open the folder containing the downloaded anime once the download finishes
- `-msd MAX_SIMULTANEOUS_DOWNLOADS, --max_simultaneous_downloads MAX_SIMULTANEOUS_DOWNLOADS`: Maximum number of simultaneous downloads

### Settings

Senpcli by default uses your settings from Senpwai. If you don't have Senpwai installed and want to edit the settings you can find the settings.json at "%LOCALAPPDATA%\Senpwai\settings.json" on Windows and "~/.config/Senpwai/settings.json" on Linux/Mac.

## Building from Source

Ensure you have [Python 3.11](https://www.python.org/downloads/release/python-3111) and [Git](https://github.com/git-guides/install-git) installed.

Open a terminal and run the following commands.

1. **Set everything up.**

- Linux/Mac

```
git clone https://github.com/SenZmaKi/Senpwai && cd Senpwai && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

- Windows (Command Prompt)

```
git clone https://github.com/SenZmaKi/Senpwai && cd Senpwai && python -m venv .venv && .venv\Scripts\activate && pip install -r requirements.txt
```

2. **Build the tool into an executable.**

```
pip install cx_freeze==6.15.10 && python setup.py --senpcli build
```

- The executable will be built in `Senpwai\build\Senpcli`

3. **Alternatively you can run the tool directly via Python.**

```
cd src && python senpcli.py --help
```
