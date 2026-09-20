import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { title, artist, album, coverUrl, durationMs, durationSec, username } = body || {};

  if (!title || !artist) {
    throw createError({
      statusCode: 400,
      statusMessage: 'title and artist are required',
    });
  }

  // Look for import script in /music or host path
  const scriptCandidates = [
    '/music/import_spotify_playlist.py',
    path.resolve(process.cwd(), '../my-music/import_spotify_playlist.py'),
    path.resolve(process.cwd(), './scripts/import_spotify_playlist.py'),
    path.resolve(process.cwd(), './import_spotify_playlist.py'),
  ];
  const scriptPath = scriptCandidates.find((p) => fs.existsSync(p));

  const musicDir = process.env.MUSIC_FOLDER || '/music';
  const serverUrl = process.env.NUXT_PUBLIC_SERVER_URL || 'http://localhost:6767';
  const targetDir = fs.existsSync(musicDir)
    ? musicDir
    : path.resolve(process.cwd(), '../my-music');

  if (scriptPath) {
    const args = [
      scriptPath,
      '--track-title',
      title,
      '--track-artist',
      artist,
      '--track-album',
      album || 'Singles',
      '--music-dir',
      targetDir,
      '--server',
      serverUrl,
    ];

    if (coverUrl) {
      args.push('--track-cover', coverUrl);
    }
    const ms = durationMs || (durationSec ? durationSec * 1000 : 0);
    if (ms > 0) {
      args.push('--track-duration-ms', String(ms));
    }

    // Spawn download worker in background
    const child = spawn('python3', args, {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
  }

  return {
    success: true,
    status: 'downloading',
    title,
    artist,
    timestamp: new Date().toISOString(),
  };
});
