from argparse import ArgumentParser
import shutil


from scripts.common import BUILD_DIR, RELEASE_DIR


def make_portable(name: str) -> None:
    src = BUILD_DIR / name
    dest = RELEASE_DIR / f"{name}-portable-win"
    shutil.make_archive(str(dest), "zip", src)


def main() -> None:
    parser = ArgumentParser(description="Make portable release")
    parser.add_argument("-a", "--all", action="store_true", help="Make all portables")
    parser.add_argument(
        "-sw", "--senpwai", action="store_true", help="Make Senpwai portable"
    )
    parser.add_argument(
        "-sc", "--senpcli", action="store_true", help="Make Senpcli portable"
    )
    parsed = parser.parse_args()

    if parsed.senpwai or parsed.all:
        print("Making Senpwai portable")
        make_portable("Senpwai")
    if parsed.senpcli or parsed.all:
        print("Making Senpcli portable")
        make_portable("Senpcli")


if __name__ == "__main__":
    main()
