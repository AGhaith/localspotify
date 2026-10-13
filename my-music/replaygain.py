#!/usr/bin/env python3
"""Measure and optionally write track ReplayGain tags for local music."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import logging
import math
from pathlib import Path
import re
import subprocess

from mutagen.flac import FLAC
from mutagen.id3 import TXXX
from mutagen.mp3 import MP3
from mutagen.mp4 import MP4, MP4FreeForm


REFERENCE_LUFS = -14.0
SUFFIXES = {".m4a", ".mp3", ".flac"}
M4A_GAIN = "----:com.apple.iTunes:replaygain_track_gain"
M4A_PEAK = "----:com.apple.iTunes:replaygain_track_peak"


def parse_ebur128(stderr):
    summary = stderr.rsplit("Summary:", 1)[-1]
    integrated = re.search(r"(?m)^\s*I:\s*(-?(?:\d+(?:\.\d+)?|inf))\s+LUFS", summary)
    peak = re.search(r"(?m)^\s*Peak:\s*(-?(?:\d+(?:\.\d+)?|inf))\s+dBFS", summary)
    if not integrated or not peak:
        raise ValueError("ffmpeg ebur128 summary has no integrated loudness or true peak")
    lufs = float(integrated.group(1))
    peak_db = float(peak.group(1))
    if not math.isfinite(lufs):
        raise ValueError("audio has no measurable loudness")
    return lufs, 10 ** (peak_db / 20)


def measure(path):
    command = ["ffmpeg", "-nostats", "-hide_banner", "-i", str(path),
               "-filter_complex", "ebur128=peak=true", "-f", "null", "-"]
    completed = subprocess.run(command, capture_output=True, text=True, errors="replace")
    if completed.returncode:
        raise RuntimeError(f"ffmpeg failed for {path}: {completed.stderr[-500:]}")
    return parse_ebur128(completed.stderr)


def gain_for_lufs(lufs):
    return round(REFERENCE_LUFS - lufs, 2)


def open_audio(path):
    return {".m4a": MP4, ".mp3": MP3, ".flac": FLAC}[path.suffix.lower()](path)


def has_track_gain(path):
    audio = open_audio(path)
    if audio.tags is None:
        return False
    if path.suffix.lower() == ".m4a":
        return M4A_GAIN in audio and M4A_PEAK in audio
    if path.suffix.lower() == ".mp3":
        descriptions = {frame.desc.upper() for frame in audio.tags.getall("TXXX")}
        return {"REPLAYGAIN_TRACK_GAIN", "REPLAYGAIN_TRACK_PEAK"} <= descriptions
    return "REPLAYGAIN_TRACK_GAIN" in audio and "REPLAYGAIN_TRACK_PEAK" in audio


def write_tags(path, gain_db, peak):
    audio = open_audio(path)
    if audio.tags is None:
        audio.add_tags()
    gain_text = f"{gain_db:.2f} dB"
    peak_text = f"{peak:.6f}"
    if path.suffix.lower() == ".m4a":
        audio[M4A_GAIN] = [MP4FreeForm(gain_text.encode("utf-8"))]
        audio[M4A_PEAK] = [MP4FreeForm(peak_text.encode("utf-8"))]
    elif path.suffix.lower() == ".mp3":
        audio.tags.delall("TXXX:REPLAYGAIN_TRACK_GAIN")
        audio.tags.delall("TXXX:REPLAYGAIN_TRACK_PEAK")
        audio.tags.add(TXXX(encoding=3, desc="REPLAYGAIN_TRACK_GAIN", text=gain_text))
        audio.tags.add(TXXX(encoding=3, desc="REPLAYGAIN_TRACK_PEAK", text=peak_text))
    else:
        audio["REPLAYGAIN_TRACK_GAIN"] = gain_text
        audio["REPLAYGAIN_TRACK_PEAK"] = peak_text
    audio.save()


def apply_replaygain(path, force=False):
    try:
        path = Path(path)
        if not force and has_track_gain(path):
            return False
        lufs, peak = measure(path)
        write_tags(path, gain_for_lufs(lufs), peak)
        return True
    except Exception as error:
        logging.error("ReplayGain failed for %s: %s", path, error)
        return False


def inspect_file(path, apply, force):
    try:
        if not force and has_track_gain(path):
            return "skipped", path, None
        lufs, peak = measure(path)
        gain = gain_for_lufs(lufs)
        if apply:
            write_tags(path, gain, peak)
        return "written" if apply else "measured", path, (lufs, gain)
    except Exception as error:
        logging.error("ReplayGain failed for %s: %s", path, error)
        return "failed", path, None


def selftest():
    sample = """[Parsed_ebur128_0] Summary:
  Integrated loudness:
    I:         -10.8 LUFS
  True peak:
    Peak:       -0.1 dBFS
"""
    lufs, peak = parse_ebur128(sample)
    assert lufs == -10.8
    assert abs(peak - 10 ** (-0.1 / 20)) < 1e-10
    assert gain_for_lufs(lufs) == -3.2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", nargs="?", type=Path, default=Path(__file__).resolve().parent)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="measure without writing (default)")
    mode.add_argument("--apply", action="store_true", help="write ReplayGain tags")
    parser.add_argument("--force", action="store_true", help="re-measure tagged files")
    parser.add_argument("-j", type=int, default=2, metavar="N", help="parallel workers")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        print("selftest passed")
        return
    if args.j < 1:
        parser.error("-j must be at least 1")
    if not args.folder.is_dir():
        parser.error(f"folder does not exist: {args.folder}")
    paths = (path for path in args.folder.rglob("*") if path.suffix.lower() in SUFFIXES)
    counts = {"measured": 0, "written": 0, "skipped": 0, "failed": 0}
    with ThreadPoolExecutor(max_workers=args.j) as pool:
        for status, path, numbers in pool.map(lambda path: inspect_file(path, args.apply, args.force), paths):
            counts[status] += 1
            if numbers:
                print(f"{path}  {numbers[0]:.2f} LUFS  {numbers[1]:+.2f} dB")
    print("Summary: " + ", ".join(f"{key}={count}" for key, count in counts.items()))


if __name__ == "__main__":
    main()
