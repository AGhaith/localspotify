import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from main import DownloadRequest, select_audio_candidates, version_signature


def main() -> int:
    cases = json.loads(Path(__file__).with_name("match_cases.json").read_text(encoding="utf-8"))
    print("Result | Requested | Source | Chosen title / channel | Delta")
    failures = 0
    for case in cases:
        track = DownloadRequest(**case)
        choices = select_audio_candidates(track)
        if choices:
            source, chosen = choices[0]
            delta = abs(chosen.seconds - track.durationMs / 1000)
            valid = delta <= (3 if source in ("isrc", "ytmusic") else 15)
            valid &= version_signature(track.title) == version_signature(chosen.title)
            title_channel = f"{chosen.title} / {', '.join(chosen.artists)}"
            delta_text = f"{delta:.1f}s"
        else:
            source, title_channel, delta_text, valid = "fallback", "unknown", "n/a", False
        status = "PASS" if valid else "FAIL"
        failures += not valid
        print(f"{status} | {track.artist} - {track.title} | {source} | {title_channel} | {delta_text}")
    return int(failures > 0)


if __name__ == "__main__":
    raise SystemExit(main())
