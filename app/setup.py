from os.path import join
from cx_Freeze import setup, Executable
from shared.global_vars_and_funcs import app_name, assets_path, base_directory, senpwai_icon_path, version
from sys import platform


main_script = join(base_directory, "senpwai.py")
base = 'Win32GUI' if platform == 'win32' else None
executables = [Executable(main_script, target_name=app_name, icon=senpwai_icon_path, base=base, copyright="Sen ZmaKi")]
include_files = [assets_path]
setup(
    name=app_name,
    version=version,
    description="Desktop app for conveniently batch downloading anime",
    executables=executables,
    options={"build_exe": {
        "include_files": include_files,
        }
    }
)