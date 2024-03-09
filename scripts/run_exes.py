import subprocess
import time

from scripts.bump_version import log_error
from scripts.utils import ARGS


def run_process(command: str) -> None:
    process = subprocess.Popen(command)
    time.sleep(3)
    process.terminate()
    if process.returncode is not None and process.returncode != 0:
        log_error(f"Returncode {process.returncode} by {command}", True)


def main() -> None:
    all_ = "--all" in ARGS
    if "--senpwai" in ARGS or all_:
        run_process(
            r"C:\Users\PC\AppData\Local\Programs\Senpwai\senpwai.exe --minimised_to_tray"
        )
    if "--senpwai_pip" in ARGS or all_:
        run_process(
            r"C:\Users\PC\AppData\Local\Programs\Python\Python311\Scripts\senpwai.exe --minimised_to_tray"
        )

    if "--senpcli" in ARGS or all_:
        run_process(r"C:\Users\PC\AppData\Local\Programs\Senpcli\senpcli.exe --version")
    if "--senpcli_pip" in ARGS or all_:
        run_process(
            r"C:\Users\PC\AppData\Local\Programs\Python\Python311\Scripts\senpcli.exe --version"
        )


if __name__ == "__main__":
    main()
