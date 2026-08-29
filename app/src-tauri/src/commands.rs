use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use tauri::{AppHandle, Manager};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TrackPayload {
    #[serde(rename = "trackId")]
    pub track_id: String,
    #[serde(rename = "streamUrl")]
    pub stream_url: String,
    #[serde(rename = "coverUrl")]
    pub cover_url: Option<String>,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration: u32,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct OfflineTrack {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration: u32,
    #[serde(rename = "audioPath")]
    pub audio_path: String,
    #[serde(rename = "coverPath")]
    pub cover_path: Option<String>,
    #[serde(rename = "savedAt")]
    pub saved_at: u64,
}

fn get_storage_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let app_dir = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("Failed to get app data dir: {}", e))?;
    let offline_dir = app_dir.join("offline_tracks");
    if !offline_dir.exists() {
        fs::create_dir_all(&offline_dir)
            .map_err(|e| format!("Failed to create offline dir: {}", e))?;
    }
    Ok(offline_dir)
}

fn read_index(storage_dir: &PathBuf) -> Vec<OfflineTrack> {
    let index_file = storage_dir.join("index.json");
    if index_file.exists() {
        if let Ok(content) = fs::read_to_string(index_file) {
            if let Ok(tracks) = serde_json::from_str::<Vec<OfflineTrack>>(&content) {
                return tracks;
            }
        }
    }
    Vec::new()
}

fn write_index(storage_dir: &PathBuf, tracks: &[OfflineTrack]) -> Result<(), String> {
    let index_file = storage_dir.join("index.json");
    let json = serde_json::to_string_pretty(tracks)
        .map_err(|e| format!("Failed to serialize index: {}", e))?;
    fs::write(index_file, json).map_err(|e| format!("Failed to write index.json: {}", e))?;
    Ok(())
}

#[tauri::command]
pub async fn save_offline_track(
    app: AppHandle,
    payload: TrackPayload,
) -> Result<OfflineTrack, String> {
    let storage_dir = get_storage_dir(&app)?;
    let audio_file_name = format!("{}.m4a", payload.track_id);
    let audio_path = storage_dir.join(&audio_file_name);

    // 1. Download Audio Stream
    let client = reqwest::Client::new();
    let resp = client
        .get(&payload.stream_url)
        .send()
        .await
        .map_err(|e| format!("Download stream request failed: {}", e))?;

    if !resp.status().is_success() {
        return Err(format!("Stream download failed with status: {}", resp.status()));
    }

    let bytes = resp
        .bytes()
        .await
        .map_err(|e| format!("Failed reading audio bytes: {}", e))?;

    let mut file = File::create(&audio_path)
        .map_err(|e| format!("Failed creating audio file: {}", e))?;
    file.write_all(&bytes)
        .map_err(|e| format!("Failed writing audio file: {}", e))?;

    // 2. Download Cover Artwork (optional)
    let mut cover_path_str = None;
    if let Some(cover_url) = payload.cover_url {
        if !cover_url.is_empty() {
            let cover_file_name = format!("{}.jpg", payload.track_id);
            let cover_path = storage_dir.join(&cover_file_name);
            if let Ok(c_resp) = client.get(&cover_url).send().await {
                if c_resp.status().is_success() {
                    if let Ok(c_bytes) = c_resp.bytes().await {
                        if let Ok(mut c_file) = File::create(&cover_path) {
                            let _ = c_file.write_all(&c_bytes);
                            cover_path_str = Some(cover_path.to_string_lossy().to_string());
                        }
                    }
                }
            }
        }
    }

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();

    let new_track = OfflineTrack {
        id: payload.track_id,
        title: payload.title,
        artist: payload.artist,
        album: payload.album,
        duration: payload.duration,
        audio_path: audio_path.to_string_lossy().to_string(),
        cover_path: cover_path_str,
        saved_at: now,
    };

    // Update Index
    let mut tracks = read_index(&storage_dir);
    tracks.retain(|t| t.id != new_track.id);
    tracks.push(new_track.clone());
    write_index(&storage_dir, &tracks)?;

    Ok(new_track)
}

#[tauri::command]
pub fn get_offline_tracks(app: AppHandle) -> Result<Vec<OfflineTrack>, String> {
    let storage_dir = get_storage_dir(&app)?;
    Ok(read_index(&storage_dir))
}

#[tauri::command]
pub fn delete_offline_track(app: AppHandle, track_id: String) -> Result<(), String> {
    let storage_dir = get_storage_dir(&app)?;
    let mut tracks = read_index(&storage_dir);

    if let Some(track) = tracks.iter().find(|t| t.id == track_id) {
        let audio_path = PathBuf::from(&track.audio_path);
        if audio_path.exists() {
            let _ = fs::remove_file(audio_path);
        }
        if let Some(cover_str) = &track.cover_path {
            let cover_path = PathBuf::from(cover_str);
            if cover_path.exists() {
                let _ = fs::remove_file(cover_path);
            }
        }
    }

    tracks.retain(|t| t.id != track_id);
    write_index(&storage_dir, &tracks)?;
    Ok(())
}

#[tauri::command]
pub fn get_offline_audio_url(app: AppHandle, track_id: String) -> Result<String, String> {
    let storage_dir = get_storage_dir(&app)?;
    let audio_path = storage_dir.join(format!("{}.m4a", track_id));
    if audio_path.exists() {
        Ok(format!("asset://localhost/{}", audio_path.to_string_lossy()))
    } else {
        Err(format!("Offline track not found for id: {}", track_id))
    }
}
