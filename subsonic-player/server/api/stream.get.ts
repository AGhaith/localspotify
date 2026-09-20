import fs from 'fs';
import path from 'path';

export default defineEventHandler(async (event) => {
  const query = getQuery(event);
  const title = (query.title as string)?.trim() || '';
  const artist = (query.artist as string)?.trim() || '';

  if (!title) {
    throw createError({
      statusCode: 400,
      statusMessage: 'title parameter is required',
    });
  }

  const musicDir = process.env.MUSIC_FOLDER || '/music';
  const searchDirs = [
    musicDir,
    path.resolve(process.cwd(), '../my-music'),
    path.resolve(process.cwd(), './my-music'),
  ];

  const clean = (s: string) => s.replace(/[\/\\:*?"<>|]/g, '').toLowerCase().trim();
  const targetTitle = clean(title);
  const targetArtist = clean(artist);

  let matchedFile: string | null = null;

  for (const dir of searchDirs) {
    if (!fs.existsSync(dir)) continue;

    const findMatch = (currentDir: string): string | null => {
      try {
        const files = fs.readdirSync(currentDir, { withFileTypes: true });
        for (const f of files) {
          const fullPath = path.join(currentDir, f.name);
          if (f.isDirectory()) {
            const found = findMatch(fullPath);
            if (found) return found;
          } else {
            const lower = f.name.toLowerCase();
            if (
              lower.endsWith('.m4a') ||
              lower.endsWith('.mp3') ||
              lower.endsWith('.flac') ||
              lower.endsWith('.opus')
            ) {
              if (lower.includes(targetTitle)) {
                if (!targetArtist || lower.includes(targetArtist) || fullPath.toLowerCase().includes(targetArtist)) {
                  return fullPath;
                }
              }
            }
          }
        }
      } catch (_) {}
      return null;
    };

    matchedFile = findMatch(dir);
    if (matchedFile) break;
  }

  if (matchedFile && fs.existsSync(matchedFile)) {
    const stat = fs.statSync(matchedFile);
    const range = getRequestHeader(event, 'range');
    const contentType = matchedFile.endsWith('.mp3') ? 'audio/mpeg' : 'audio/mp4';

    if (range) {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : stat.size - 1;
      const chunksize = end - start + 1;
      const stream = fs.createReadStream(matchedFile, { start, end });

      setResponseStatus(event, 206);
      setResponseHeaders(event, {
        'Content-Range': `bytes ${start}-${end}/${stat.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': String(chunksize),
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      });
      return sendStream(event, stream);
    } else {
      setResponseHeaders(event, {
        'Content-Length': String(stat.size),
        'Content-Type': contentType,
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'public, max-age=31536000, immutable',
      });
      return sendStream(event, fs.createReadStream(matchedFile));
    }
  }

  throw createError({
    statusCode: 404,
    statusMessage: 'Track audio not ready in vault yet',
  });
});
