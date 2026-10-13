/// Lowercase, strip punctuation, collapse whitespace. Unicode-aware so Arabic
/// (and any non-Latin) text survives: an ASCII-only `\w` strips it to blanks,
/// which makes unrelated Arabic titles compare equal.
String textKey(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
