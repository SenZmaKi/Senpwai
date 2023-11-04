#![windows_subsystem = "windows"] // Comment this out when debugging/developing cause otherwise you won't see output from print statements
use {
    native_dialog::{MessageDialog, MessageType},
    std::os::windows::process::CommandExt,
    std::process::Command,
    winapi::um::winuser,
};

const APP_TITLE: &str = "Senpwai";
const PYTHON_PATH: &str = "..\\.venv\\Scripts\\python.exe";
const MAIN_SCRIPT_PATH: &str = ".\\senpwai.py";
const CREATE_NO_WINDOW_FLAG: u32 = 0x08000000;
const HELP_MESSAGE: &str = "Help: Uninstall then reinstall the app using the setup from https:://github.com/SenZmaKi/Senpwai\n\nIf the error persists report it in either the\nDiscord Server: https://discord.gg/invite/e9UxkuyDX2\nGithub Issues: https://github.com/SenZmaKi/Senpwai/issues\nSubreddit: https://www.reddit.com/r/Senpwai";

fn main() {
    if bring_app_to_foreground_if_running() {
        return;
    }
    run_app()
}

fn bring_app_to_foreground_if_running() -> bool {
    // Convert the app title to a null-terminated C string
    let app_title_c = format!("{}\0", APP_TITLE);

    // Check if the app is already running by searching for its window
    let window = unsafe { winuser::FindWindowA(std::ptr::null(), app_title_c.as_ptr() as *const i8) };

    if window != std::ptr::null_mut() {
        // If the app is running, bring it into focus
        unsafe {
            winuser::ShowWindow(window, winuser::SW_RESTORE);
            winuser::SetForegroundWindow(window);
        }
        return true;
    }
    false
}

fn run_app() {
    let mut args = vec![MAIN_SCRIPT_PATH.to_owned()];
    // Skip the first arg cause it's the path/name of the current executable
    args.extend(std::env::args().skip(1));
    let result = Command::new(PYTHON_PATH)
        .args(args)
        .creation_flags(CREATE_NO_WINDOW_FLAG)
        .spawn();

    match result {
        Err(err) => {
            let err = err.to_string();
            if !err.is_empty() {
                let error_message = format!("{}\n\n{}", err, HELP_MESSAGE);
                show_error_message("Command Execution Error", &error_message);
            }
        }
        Ok(_) => {}
    }
}

fn show_error_message(error_title: &str, message: &str) {
    MessageDialog::new()
        .set_type(MessageType::Error)
        .set_title(error_title)
        .set_text(message)
        .show_alert()
        .unwrap();
}
