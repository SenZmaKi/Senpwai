from cx_Freeze import setup, Executable
import os
from typing import cast
import sys
from scripts.common import BUILD_DIR, ROOT_DIR


def duo_value_parser(
    file_path: str, split_str: str, ignore_if_startswith=["#"]
) -> list[tuple[str, str]]:
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
    gui_script_path = os.path.join(senpwai_package_dir, "main.py")
    cli_script_path = os.path.join(senpwai_package_dir, "senpcli/main.py")
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
        target_name=metadata["cli_name"],
        copyright=metadata["copyright"],
    )
    return [cli_executable] if senpcli_only else [gui_executable, cli_executable]


def get_options(build_dir: str, assets_dir: str, senpcli_only: bool) -> dict:
    common_options = {
        "build_exe": build_dir,
        "silent_level": 3,
        "include_msvcr": True,
        "replace_paths": [
            (os.path.abspath("."), ""),
        ],
    }

    if senpcli_only:
        return {
            "build_exe": common_options,
        }
    return {
        "build_exe": {
            **common_options,
            "include_files": assets_dir,
            "zip_include_packages": "PyQt6",
        },
    }


def main():
    try:
        sys.argv.remove("--senpcli")
        senpcli_only = True
    except ValueError:
        senpcli_only = False
    senpwai_package_dir = ROOT_DIR / "senpwai"
    sys.path.append(str(senpwai_package_dir))
    metadata = parse_metadata()
    name = metadata["cli_name"] if senpcli_only else metadata["name"]
    build_dir = BUILD_DIR / name.capitalize()
    assets_dir = ROOT_DIR / senpwai_package_dir / "assets"
    assets_dir = senpwai_package_dir / "assets"
    options = get_options(str(build_dir), str(assets_dir), senpcli_only)
    exececutables = get_executables(metadata, str(senpwai_package_dir), senpcli_only)
    setup(
        name=name,
        version=metadata["version"],
        options=options,
        executables=exececutables,
    )
    license_file = build_dir / "frozen_application_license.txt"
    license_file.unlink(missing_ok=True)
    print(f"Built at: {build_dir}")


if __name__ == "__main__":
    main()
