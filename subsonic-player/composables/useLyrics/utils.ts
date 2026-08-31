import type { LyricLine } from './types';

/**
 * Parse an LRC-formatted string into a structured list of lyric lines with timestamps.
 * Supports standard formats: [mm:ss.xx] and [mm:ss.xxx]
 */
export function parseLrc(lrcText: string): LyricLine[] {
  if (!lrcText) return [];

  const lines = lrcText.split('\n');
  const parsedLines: LyricLine[] = [];
  const timeRegex = /\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\]/g;

  for (const rawLine of lines) {
    const trimmed = rawLine.trim();
    if (!trimmed) continue;

    const matches = Array.from(trimmed.matchAll(timeRegex));
    if (!matches.length) {
      if (/^\[[a-zA-Z]+:.*\]$/.test(trimmed)) {
        continue;
      }
      parsedLines.push({ text: trimmed });
      continue;
    }

    const text = trimmed.replace(timeRegex, '').trim();

    for (const match of matches) {
      const minutes = parseInt(match[1], 10);
      const seconds = parseInt(match[2], 10);
      let milliseconds = 0;

      if (match[3]) {
        milliseconds =
          match[3].length === 2
            ? parseInt(match[3], 10) * 10
            : parseInt(match[3], 10);
      }

      const totalTime = minutes * 60 + seconds + milliseconds / 1000;
      parsedLines.push({
        text,
        time: totalTime,
      });
    }
  }

  return parsedLines.sort((a, b) => {
    if (a.time !== undefined && b.time !== undefined) {
      return a.time - b.time;
    }
    return 0;
  });
}

/**
 * Clean track title by removing extraneous tags like (feat. X), [Remastered], .mp3, etc.
 */
export function cleanTrackTitle(title?: string): string {
  if (!title) return '';
  return title
    .replace(/\.[a-zA-Z0-9]{3,4}$/, '')
    .replace(/\s*[\(\[](?:feat|ft|with|prod)\.?\s+[^\)\]]+[\)\]]/gi, '')
    .replace(
      /\s*[\(\[](?:official\s+(?:audio|video|music\s+video)|remastered|remix|bonus\s+track|deluxe\s+edition)[\)\]]/gi,
      '',
    )
    .trim();
}

/**
 * Clean artist name
 */
export function cleanArtistName(artist?: string): string {
  if (!artist) return '';
  return artist
    .replace(/\s*[\(\[](?:feat|ft|with)\.?\s+[^\)\]]+[\)\]]/gi, '')
    .trim();
}
