import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { spotifyUrl, playlistName, tracks, username } = body || {};

  if (!spotifyUrl) {
    throw createError({
      statusCode: 400,
      statusMessage: 'spotifyUrl is required',
    });
  }

  // Look for import script in /music or host path
  const scriptCandidates = [
    '/music/import_spotify_playlist.py',
    path.resolve(process.cwd(), '../my-music/import_spotify_playlist.py'),
    path.resolve(process.cwd(), './scripts/import_spotify_playlist.py'),
  ];
  const scriptPath = scriptCandidates.find((p) => fs.existsSync(p));

  if (scriptPath) {
    const musicDir = process.env.MUSIC_FOLDER || '/music';
    const serverUrl = process.env.NUXT_PUBLIC_SERVER_URL || 'http://localhost:6767';

    // Spawn download worker asynchronously
    const targetDir = fs.existsSync(musicDir)
      ? musicDir
      : path.resolve(process.cwd(), '../my-music');

    const child = spawn(
      'python3',
      [scriptPath, spotifyUrl, '--music-dir', targetDir, '--server', serverUrl],
      {
        detached: true,
        stdio: 'ignore',
      }
    );
    child.unref();
  }

  return {
    success: true,
    status: 'downloading',
    playlistName: playlistName || 'Imported Playlist',
    trackCount: Array.isArray(tracks) ? tracks.length : 0,
    timestamp: new Date().toISOString(),
  };
});
