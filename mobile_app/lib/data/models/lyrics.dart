class LyricsLine {
  final Duration timestamp;
  final String text;

  const LyricsLine({
    required this.timestamp,
    required this.text,
  });
}

class Lyrics {
  final String? artist;
  final String? title;
  final bool isSynced;
  final List<LyricsLine> lines;
  final String rawText;

  const Lyrics({
    this.artist,
    this.title,
    this.isSynced = false,
    this.lines = const [],
    required this.rawText,
  });

  factory Lyrics.fromLrc(String lrcContent, {String? artist, String? title}) {
    final lines = <LyricsLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regex.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final millisGroup = match.group(3);
        var milliseconds = 0;
        if (millisGroup != null) {
          milliseconds = int.tryParse(millisGroup) ?? 0;
          if (millisGroup.length == 2) {
            milliseconds *= 10;
          }
        }
        final text = (match.group(4) ?? '').trim();
        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
        lines.add(LyricsLine(timestamp: timestamp, text: text));
      }
    }

    // Sort by timestamp
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Lyrics(
      artist: artist,
      title: title,
      isSynced: lines.isNotEmpty,
      lines: lines,
      rawText: lrcContent,
    );
  }

  factory Lyrics.fromSubsonicJson(Map<String, dynamic> json, {String? artist, String? title}) {
    final lyricsList = json['structuredLyrics'];
    if (lyricsList is List && lyricsList.isNotEmpty) {
      final first = lyricsList.first;
      final lineList = first['line'];
      if (lineList is List) {
        final lines = <LyricsLine>[];
        for (final l in lineList) {
          if (l is Map) {
            final start = (l['start'] as num?)?.toInt() ?? 0;
            final value = l['value']?.toString() ?? '';
            lines.add(LyricsLine(timestamp: Duration(milliseconds: start), text: value));
          }
        }
        return Lyrics(
          artist: artist,
          title: title,
          isSynced: lines.isNotEmpty,
          lines: lines,
          rawText: lines.map((l) => l.text).join('\n'),
        );
      }
    }
    return Lyrics(
      artist: artist,
      title: title,
      isSynced: false,
      lines: const [],
      rawText: '',
    );
  }

  factory Lyrics.fromPlainText(String text, {String? artist, String? title}) {
    return Lyrics(
      artist: artist,
      title: title,
      isSynced: false,
      lines: const [],
      rawText: text,
    );
  }
}
