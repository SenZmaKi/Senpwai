from argparse import ArgumentParser
from scripts.announce.main import main
from scripts.common import get_piped_input

if __name__ == "__main__":
    parser = ArgumentParser("Announce a new release on Discord and Reddit")
    parser.add_argument("-t", "--title", type=str, help="Title of the release")
    parser.add_argument(
        "-r",
        "--release_notes",
        type=str,
        help="Release notes, will use stdin if not provided",
    )
    parsed = parser.parse_args()
    release_notes = parsed.release_notes or get_piped_input()
    main(parsed.title, release_notes)
