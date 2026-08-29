mod commands;

use commands::*;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            save_offline_track,
            get_offline_tracks,
            delete_offline_track,
            get_offline_audio_url
        ])
        .run(tauri::generate_context!())
        .expect("error while running LocalSpotify Tauri application");
}
