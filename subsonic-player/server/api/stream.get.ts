import fs from 'fs';
import path from 'path';

const audioExtensions = new Set(['.m4a', '.mp3', '.flac', '.opus', '.ogg']);

export default defineEventHandler(async (event) => {
  const query = getQuery(event);
  const musicDir = path.resolve(process.env.MUSIC_FOLDER || '/music');

  const streamFile = (filePath: string) => {
    const stat = fs.statSync(filePath);
    const range = getRequestHeader(event, 'range');
    const extension = path.extname(filePath).toLowerCase();
    const contentType = extension === '.mp3' ? 'audio/mpeg' : extension === '.flac' ? 'audio/flac' : extension === '.opus' ? 'audio/ogg' : 'audio/mp4';

    if (range) {
      const match = /^bytes=(\d+)-(\d*)$/.exec(range);
      const start = match ? Number(match[1]) : NaN;
      const end = match && match[2] ? Math.min(Number(match[2]), stat.size - 1) : stat.size - 1;
      if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || start >= stat.size) {
        setResponseHeader(event, 'Content-Range', `bytes */${stat.size}`);
        throw createError({ statusCode: 416, statusMessage: 'Invalid byte range' });
      }

      setResponseStatus(event, 206);
      setResponseHeaders(event, {
        'Content-Range': `bytes ${start}-${end}/${stat.size}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': String(end - start + 1),
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=31536000, immutable',
      });
      return sendStream(event, fs.createReadStream(filePath, { start, end }));
    }

    setResponseHeaders(event, {
      'Content-Length': String(stat.size),
      'Content-Type': contentType,
      'Accept-Ranges': 'bytes',
      'Cache-Control': 'public, max-age=31536000, immutable',
    });
    return sendStream(event, fs.createReadStream(filePath));
  };

  if (query.file !== undefined) {
    if (typeof query.file !== 'string' || !query.file || !audioExtensions.has(path.extname(query.file).toLowerCase())) {
      throw createError({ statusCode: 400, statusMessage: 'Invalid audio file path' });
    }

    const filePath = path.resolve(musicDir, query.file);
    const relative = path.relative(musicDir, filePath);
    if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
      throw createError({ statusCode: 400, statusMessage: 'Audio file path is outside music directory' });
    }
    if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
      throw createError({ statusCode: 404, statusMessage: 'Track audio not ready in vault yet' });
    }

    const realMusicDir = fs.realpathSync(musicDir);
    const realFilePath = fs.realpathSync(filePath);
    const realRelative = path.relative(realMusicDir, realFilePath);
    if (!realRelative || realRelative === '..' || realRelative.startsWith(`..${path.sep}`) || path.isAbsolute(realRelative)) {
      throw createError({ statusCode: 400, statusMessage: 'Audio file path is outside music directory' });
    }
    return streamFile(filePath);
  }

  const title = typeof query.title === 'string' ? query.title.trim() : '';
  const artist = typeof query.artist === 'string' ? query.artist.trim() : '';
  if (!title) {
    throw createError({ statusCode: 400, statusMessage: 'title parameter is required' });
  }

  const clean = (value: string) => value.replace(/[\/\\:*?"<>|\x00-\x1f]/g, '').replace(/\s+/g, ' ').trim().toLowerCase();
  const targetTitle = clean(title);
  const targetArtist = clean(artist.replace(/;/g, ', '));
  const searchDirs = [musicDir, path.resolve(process.cwd(), '../my-music'), path.resolve(process.cwd(), './my-music')];
  const candidates: string[] = [];

  const collectFiles = (dir: string) => {
    try {
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) collectFiles(fullPath);
        else if (entry.isFile() && audioExtensions.has(path.extname(entry.name).toLowerCase())) candidates.push(fullPath);
      }
    } catch (_) {
      // A search directory may be unavailable during startup.
    }
  };

  for (const dir of searchDirs) {
    if (fs.existsSync(dir)) collectFiles(dir);
  }

  const basename = (filePath: string) => clean(path.parse(filePath).name);
  const exactArtistTitle = targetArtist ? candidates.find((filePath) => basename(filePath) === `${targetArtist} - ${targetTitle}`) : undefined;
  const exactTitle = candidates.find((filePath) => basename(filePath) === targetTitle);
  const substring = targetTitle.length >= 6
    ? candidates.find((filePath) => basename(filePath).includes(targetTitle) && (!targetArtist || basename(filePath).includes(targetArtist) || clean(path.dirname(filePath)).includes(targetArtist)))
    : undefined;
  const matchedFile = exactArtistTitle || exactTitle || substring;

  if (!matchedFile) {
    throw createError({ statusCode: 404, statusMessage: 'Track audio not ready in vault yet' });
  }
  return streamFile(matchedFile);
});
