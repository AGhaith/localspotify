export interface LyricLine {
  time?: number;
  text: string;
}

export interface LyricsResponse {
  albumName?: string;
  artistName?: string;
  duration?: number;
  id?: number;
  instrumental?: boolean;
  plainLyrics?: string;
  syncedLyrics?: string;
  trackName?: string;
}
