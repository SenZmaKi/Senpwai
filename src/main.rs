#![windows_subsystem = "windows"]
use ::std::process::Command;
use native_dialog::{MessageDialog, MessageType};
use std::os::windows::process::CommandExt;

const PYTHON_PATH: &str = "..\\.venv\\Scripts\\python.exe";
const MAIN_SCRIPT_PATH: &str = "senpwai.py";
const SRC_DIR: &str = "..\\src";
const CREATE_NO_WINDOW_FLAG: u32 = 0x08000000;
const HELP_MESSAGE: &str = "Help: Reinstall and run the setup from https:://github.com/SenZmaKi/Senpwai.\nIf the error persists report it in either the\nDiscord Server: https://discord.gg/invite/e9UxkuyDX2\nSubreddit: https://www.reddit.com/r/Senpwai\nGithub Issues: https://github.com/SenZmaKi/Senpwai/issues";

fn main() {
    let result = Command::new(PYTHON_PATH)
        .arg(MAIN_SCRIPT_PATH)
        .current_dir(SRC_DIR)
        .creation_flags(CREATE_NO_WINDOW_FLAG)
        .spawn();

    match result {
        Err(e) => {
            let err = e.to_string();
            if !err.is_empty() {
                show_error_message(&format!(
                    "Command Execution Error: {}\n{}",
                    e.to_string(),
                    HELP_MESSAGE
                ));
            }
        } 
        _ => {}
    }
}

fn show_error_message(message: &str) {
    MessageDialog::new()
        .set_type(MessageType::Error)
        .set_title("Error")
        .set_text(message)
        .show_alert()
        .unwrap();
}
