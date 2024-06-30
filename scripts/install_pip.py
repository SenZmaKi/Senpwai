import subprocess

from scripts.common import ROOT_DIR


def main() -> None:
    # Global pip cause venv pip is weird sometimes cause poetry and stuff
    pip_path = r"C:\Users\PC\AppData\Local\Programs\Python\Python311\Scripts\pip.exe"
    dist_dir = ROOT_DIR.joinpath("dist")
    distributable = next(dist_dir.glob("*"))
    subprocess.run(f"{pip_path} uninstall senpwai -y").check_returncode()
    subprocess.run(f"{pip_path} install {distributable}").check_returncode()


if __name__ == "__main__":
    main()
