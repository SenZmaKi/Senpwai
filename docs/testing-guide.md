# Guide for the testing module

## Troubleshooting

Ask the user to open CMD/Command Prompt then type the following. If they don't know how to open CMD ask them to type CMD in the search bar.

- Go to the src directory

```
cd %appdata%\..\Local\Programs\Senpwai\src
```

- Activate the virtual environment

```
"..\.venv\Scripts\activate.bat"
```

- Run all tests for both sites with default arguements

```
python -m scrapers.test all --site pahe && python -m scrapers.test all --site gogo
```

## Commands/Tests:

- **search**: Test searching
- **dub_available**: Test dub availablity checking
- **metadata**: Test getting metadata
- **episode_page**: Test getting episode page links
- **download_page**: Test getting download page links
- **download_size**: Test extraction (pahe)/ getting (gogo) of total download size
- **direct_links**: Test getting direct download links
- **hls_links**: Test getting hls links
- **match_links**: Test matching hls links to user quality
- **segments_urls**: Test getting segments urls
- **download**: Test downloading (Implicitly performs all tests)
- **all**: Perform all tests (alias to download). Only performs all tests for one site, defaults to pahe

## Options:

- `--site, -s`: Specify the site (i.e., pahe, gogo). Default: pahe
- `--title, -t`: Specify the anime title. Default: "Boku no Hero Academia"
- `--quality, -q`: Specify the video quality (i.e., 360p, 480p, 720p, 1080p). Default: 360p
- `--sub_or_dub, -sd`: Specify sub or dub. Default: sub
- `--path, -p`: Specify the download folder path. Default: ./src/test-downloads
- `--start_episode, -se`: Specify the starting episode number. Default: 1
- `--end_episode, -ee`: Specify the ending episode number. Default: 2
- `--verbose, -v`: Enable verbose mode for more detailed explanations of test results
- `--silent, -s`: Only output critical information
- `--help, -h`: Display help message

## Example:

```
python scrapers.test --site pahe --title "Naruto" --quality 720p --sub_or_dub sub
```

## Note:

- Tests are hierarchial, If for example episode_page is the command/test to run, both search and metadata test will be performed cause they are required in order to get episode_page links
- Tests are site specific, the `all` command does not perform tests for each site it implicitly defaults to pahe
