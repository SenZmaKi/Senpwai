from cx_Freeze import setup, Executable
from os import path, unlink as os_unlink
from typing import cast
import sys


def duo_value_parser(file_path: str, split_str: str, ignore_if_startswith = ["#"]) -> list[tuple[str, str]]:
    extracted: list[tuple[str, str]] = []

    def process_str(s: str) -> str:
        return s.strip().replace('"', "").replace("'", "")

    with open(file_path) as f:
        readlines = f.readlines()
        for line in readlines:
            if not any([line.startswith(i) for i in ignore_if_startswith]):
                split = line.split(split_str, 1)
                if len(split) < 2:
                    continue
                key_value = cast(
                    tuple[str, str],
                    tuple([process_str(split[0]), process_str(split[1])]),
                )
                extracted.append(key_value)
    return extracted


def parse_metadata() -> dict[str, str]:
    key_and_value = duo_value_parser("pyproject.toml", " = ")
    return dict(key_and_value)


def get_executables(
    metadata: dict[str, str], senpwai_package_dir: str, senpcli_only: bool
) -> list[Executable]:
    gui_script_path = path.join(senpwai_package_dir, "senpwai.py")
    cli_script_path = path.join(senpwai_package_dir, "senpcli/senpcli.py")
    gui_base = "WIN32GUI" if sys.platform == "win32" else None
    gui_executable = Executable(
        script=gui_script_path,
        icon=metadata["icon"],
        base=gui_base,
        target_name=metadata["name"],
        copyright=metadata["copyright"],
    )
    cli_executable = Executable(
        script=cli_script_path,
        base=None,
        icon=metadata["icon"],
        target_name=metadata["senpcli_name"],
        copyright=metadata["copyright"],
    )
    return [cli_executable] if senpcli_only else [gui_executable, cli_executable]


def get_options(build_dir: str, assets_dir: str, senpcli_only: bool) -> dict:
    return {
        "build_exe": {"build_exe": build_dir, "silent_level": 3}
        if senpcli_only
        else {
            "build_exe": build_dir,
            "include_files": assets_dir,
            "zip_include_packages": "PyQt6",
            "silent_level": 3,
        }
    }


def main():
    senpcli_only = "--senpcli" in sys.argv
    if senpcli_only:
        sys.argv.remove("--senpcli")
    root_dir = path.dirname(path.realpath(__file__))
    senpwai_package_dir = path.join(root_dir, "senpwai")
    sys.path.append(senpwai_package_dir)
    metadata = parse_metadata()
    name = metadata["senpcli_name"] if senpcli_only else metadata["name"]
    build_dir = path.join(root_dir, "build", name.capitalize())
    assets_dir = path.join(senpwai_package_dir, "assets")
    setup(
        name=name,
        version=metadata["version"],
        options=get_options(build_dir, assets_dir, senpcli_only),
        executables=get_executables(metadata, senpwai_package_dir, senpcli_only),
    )
    license_file = path.join(build_dir, "frozen_application_license.txt")
    if path.isfile(license_file):
        os_unlink(license_file)
    print(f"Built at: {path.abspath(build_dir)}")


if __name__ == "__main__":
    main()

