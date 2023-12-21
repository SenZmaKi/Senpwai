from cx_Freeze import setup, Executable
from os.path import join as join_paths
from os.path import isfile as path_isfile
from os.path import abspath as path_abspath
from os import unlink as os_unlink
from typing import cast
import sys


def duo_value_parser(file_path: str, split_str: str) -> list[tuple[str, str]]:
    extracted: list[tuple[str, str]] = []
    with open(file_path) as f:
        lines = f.readlines()
        for l in lines:
            if not l.startswith("#"):
                split = l.split(split_str, 1)
                key_value = cast(
                    tuple[str, str], tuple([split[0].strip(), split[1].strip()])
                )
                extracted.append(key_value)
    return extracted


def get_metadata() -> dict[str, str]:
    key_and_value = duo_value_parser("metadata.yml", ":")
    return dict(key_and_value)


def get_executables(
    metadata: dict[str, str], src_dir: str, senpcli_only: bool
) -> list[Executable]:
    gui_script_path = join_paths(src_dir, "senpwai.py")
    cli_script_path = join_paths(src_dir, "senpcli.py")
    gui_base = "WIN32GUI" if sys.platform == "win32" else None
    gui_executable = Executable(
        script=gui_script_path,
        icon=metadata["Icon"],
        base=gui_base,
        target_name=metadata["Name"].lower(),
        copyright=metadata["Copyright"],
    )
    cli_executable = Executable(
        script=cli_script_path,
        base=None,
        icon=metadata["Icon"],
        target_name=metadata["CliName"].lower(),
        copyright=metadata["Copyright"],
    )
    return [cli_executable] if senpcli_only else [gui_executable, cli_executable]


def get_options(build_directory: str, src_dir, senpcli_only: bool) -> dict:
    return {
        "build_exe": {"build_exe": build_directory, "silent_level": 3}
        if senpcli_only
        else {
            "build_exe": build_directory,
            "include_files": join_paths(src_dir, "assets"),
            "zip_include_packages": "PyQt6",
            "silent_level": 3,
        }
    }


def main():
    senpcli_only = "--senpcli" in sys.argv
    if senpcli_only:
        sys.argv.remove("--senpcli")
    src_dir = "src"
    sys.path.append(src_dir)
    metadata = get_metadata()
    name = metadata["CliName"] if senpcli_only else metadata["Name"]
    build_directory = join_paths("build", name)
    setup(
        name=name,
        version=metadata["Version"],
        options=get_options(build_directory, src_dir, senpcli_only),
        executables=get_executables(metadata, src_dir, senpcli_only),
    )
    license_file = join_paths(build_directory, "frozen_application_license.txt")
    if path_isfile(license_file):
        os_unlink(license_file)
    print(f"Built at: {path_abspath(build_directory)}")


if __name__ == "__main__":
    main()
