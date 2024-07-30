import subprocess
import time


from scripts.bump_version import log_error
from argparse import ArgumentParser
from scripts.common import join_from_local_appdata, join_from_py_scripts



def run_process(command: str) -> None:
    process = subprocess.Popen(command)
    time.sleep(3)
    process.terminate()
    if process.returncode is not None and process.returncode != 0:
        log_error(f"Returncode {process.returncode} by {command}", True)



def run_normal_install(app_name: str, args: str):
    app_path = join_from_local_appdata("Senpwai", f"{app_name}.exe")
    run_process(rf"{app_path} {args}")




def run_pip_install(app_name: str, args: str):
    pip_path = join_from_py_scripts(app_name)
    run_process(rf"{pip_path} {args}")


def main() -> None:
    parser = ArgumentParser(description="Run executables")
    parser.add_argument("-a", "--all", action="store_true", help="Run all executables")
    parser.add_argument("-sw", "--senpwai", action="store_true", help="Run Senpwai")
    parser.add_argument(
        "-swp", "--senpwai_pip", action="store_true", help="Run Senpwai pip"
    )
    parser.add_argument("-sc", "--senpcli", action="store_true", help="Run Senpcli")
    parser.add_argument(
        "-scp", "--senpcli_pip", action="store_true", help="Run Senpcli pip"
    )
    parsed = parser.parse_args()

    if parsed.senpwai or parsed.all:
        run_normal_install("senpwai", "--minimised_to_tray")
    if parsed.senpwai_pip or parsed.all:
        run_pip_install("senpwai", "--minimised_to_tray")
    if parsed.senpcli or parsed.all:
        run_normal_install("senpcli", "--version")
    if parsed.senpcli_pip or parsed.all:
        run_pip_install("senpcli", "--version")


if __name__ == "__main__":
    main()
