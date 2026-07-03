#!/usr/bin/env python3

import os
import re
import subprocess
import syncedlyrics

CACHE_DIR = os.path.expanduser("~/.cache/waybar-lyrics")
os.makedirs(CACHE_DIR, exist_ok=True)


def run(cmd):
    try:
        return subprocess.check_output(
            cmd,
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""


def get_metadata():
    title = run(["playerctl", "-p", "spotify", "metadata", "title"])
    artist = run(["playerctl", "-p", "spotify", "metadata", "artist"])

    if not title or not artist:
        return None, None

    return artist, title


def get_status():
    out = run([
        "gdbus", "call",
        "--session",
        "--dest", "org.mpris.MediaPlayer2.spotify",
        "--object-path", "/org/mpris/MediaPlayer2",
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.mpris.MediaPlayer2.Player",
        "PlaybackStatus"
    ])

    if "Playing" in out:
        return "Playing"

    if "Paused" in out:
        return "Paused"

    return "Stopped"


def get_position():
    out = run([
        "gdbus", "call",
        "--session",
        "--dest", "org.mpris.MediaPlayer2.spotify",
        "--object-path", "/org/mpris/MediaPlayer2",
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.mpris.MediaPlayer2.Player",
        "Position"
    ])

    m = re.search(r'int64\s+(\d+)', out)

    if not m:
        return 0

    return int(m.group(1)) / 1_000_000


artist, title = get_metadata()

if not artist or not title:
    exit()

status = get_status()

if status != "Playing":
    print("󰏤 Paused")
    exit()

position = get_position()

song = f"{artist} - {title}"

cache_file = os.path.join(
    CACHE_DIR,
    re.sub(r"[^a-zA-Z0-9]", "_", song) + ".lrc"
)

# --------------------------------------------------------------------
# Download lyrics if needed
# --------------------------------------------------------------------

if not os.path.exists(cache_file):

    # Search using title + artist instead of the cached filename.
    query = f"{title} {artist}"

    lyrics = syncedlyrics.search(query)

    # Retry with another format if the first search fails.
    if not lyrics:
        lyrics = syncedlyrics.search(f"{artist} - {title}")

    if not lyrics:
        print("♪ Loading...")
        exit()

    # Reject unsynced lyrics.
    if "[" not in lyrics:
        print("♪ No synced lyrics")
        exit()

    # Reject obviously tiny results.
    if len(lyrics.splitlines()) < 5:
        print("♪ No synced lyrics")
        exit()

    with open(cache_file, "w", encoding="utf-8") as f:
        f.write(lyrics)

# --------------------------------------------------------------------
# Read lyrics
# --------------------------------------------------------------------

try:
    with open(cache_file, encoding="utf-8") as f:
        lines = f.readlines()
except Exception:
    print("♪ Loading...")
    exit()

current = ""

for line in lines:

    m = re.match(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)", line)

    if not m:
        continue

    t = int(m.group(1)) * 60 + float(m.group(2))

    if t <= position:
        lyric = m.group(3).strip()

        if lyric:
            current = lyric
    else:
        break

if current:
    print("  " + current)
else:
    print("")
