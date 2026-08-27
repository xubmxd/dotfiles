#!/usr/bin/env python3

import subprocess
import urllib.parse
import urllib.request
import json
import time
import re
import threading


PLAYER = "mewsic"

POLL_INTERVAL = 0.1
DISPLAY_INTERVAL = 0.1
POSITION_CHANGE_THRESHOLD = 0.01
SEEK_THRESHOLD = 0.75


def run_playerctl(args):
    try:
        result = subprocess.check_output(
            ["playerctl", "-p", PLAYER] + args,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()

        return result if result else None

    except Exception:
        return None


def get_snapshot():
    metadata = run_playerctl([
        "metadata",
        "--format",
        "{{artist}}||{{title}}",
    ])

    status = run_playerctl(["status"])
    position = run_playerctl(["position"])

    try:
        position = float(position) if position is not None else None
    except ValueError:
        position = None

    return metadata, status, position


def parse_lrc(lrc_str):
    lines = []
    pattern = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)")

    for line in lrc_str.splitlines():
        match = pattern.match(line)

        if match:
            minutes = int(match.group(1))
            seconds = float(match.group(2))
            text = match.group(3).strip()

            if text:
                timestamp = minutes * 60 + seconds
                lines.append((timestamp, text))

    return lines


def fetch_synced_lyrics(artist, title):
    clean_title = re.sub(
        r"\(.*?\)|\[.*?\]",
        "",
        title,
    ).strip()

    query = urllib.parse.urlencode({
        "track_name": clean_title,
        "artist_name": artist,
    })

    url = f"https://lrclib.net/api/get?{query}"

    try:
        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": "MewsicLyricsWidget/1.0"
            },
        )

        with urllib.request.urlopen(
            request,
            timeout=5,
        ) as response:

            data = json.loads(
                response.read().decode()
            )

            synced = data.get("syncedLyrics")

            if synced:
                return parse_lrc(synced)

            if data.get("plainLyrics"):
                return "unsynced"

    except Exception:
        pass

    return None


def get_lyric(lyrics, position):
    current_line = "♪ ..."

    for timestamp, text in lyrics:
        if timestamp <= position:
            current_line = text
        else:
            break

    return current_line


def main():
    current_track = None
    current_lyrics = None

    lyrics_loading = False
    lyrics_lock = threading.Lock()

    synced = False
    waiting_for_track_sync = False

    playback_status = None

    base_position = 0.0
    base_time = time.monotonic()

    last_authoritative_position = None
    transition_position = None

    player_available = False
    last_poll = 0.0

    def load_lyrics(track):
        nonlocal current_lyrics
        nonlocal lyrics_loading

        if not track or "||" not in track:
            with lyrics_lock:
                current_lyrics = None
                lyrics_loading = False
            return

        artist, title = track.split("||", 1)

        lyrics = fetch_synced_lyrics(
            artist.strip(),
            title.strip(),
        )

        with lyrics_lock:
            if track == current_track:
                current_lyrics = lyrics

            lyrics_loading = False

    while True:
        now = time.monotonic()

        if now - last_poll >= POLL_INTERVAL:
            last_poll = now

            track, new_status, position = get_snapshot()

            if new_status is None:
                player_available = False

                current_track = None

                with lyrics_lock:
                    current_lyrics = None

                lyrics_loading = False

                synced = False
                waiting_for_track_sync = False

                playback_status = None

                base_position = 0.0
                base_time = now

                last_authoritative_position = None
                transition_position = None

            else:
                player_available = True

                track_changed = track != current_track

                if track_changed:
                    current_track = track

                    synced = False
                    waiting_for_track_sync = True

                    base_position = 0.0
                    base_time = now

                    last_authoritative_position = None

                    transition_position = position

                    with lyrics_lock:
                        current_lyrics = None

                    lyrics_loading = True

                    thread = threading.Thread(
                        target=load_lyrics,
                        args=(track,),
                        daemon=True,
                    )

                    thread.start()

                if waiting_for_track_sync:

                    fresh_position_received = (
                        position is not None
                        and (
                            transition_position is None
                            or abs(
                                position
                                - transition_position
                            )
                            > POSITION_CHANGE_THRESHOLD
                        )
                    )

                    if (
                        new_status == "Playing"
                        and fresh_position_received
                        and current_track is not None
                    ):
                        base_position = position
                        base_time = now

                        last_authoritative_position = position

                        synced = True
                        waiting_for_track_sync = False

                elif synced:

                    if playback_status == "Playing":
                        local_position = (
                            base_position
                            + (now - base_time)
                        )
                    else:
                        local_position = base_position

                    status_changed = (
                        new_status != playback_status
                    )

                    position_updated = (
                        position is not None
                        and (
                            last_authoritative_position is None
                            or abs(
                                position
                                - last_authoritative_position
                            )
                            > POSITION_CHANGE_THRESHOLD
                        )
                    )

                    if status_changed:

                        if position is not None:
                            base_position = position
                            last_authoritative_position = position
                        else:
                            base_position = local_position

                        base_time = now

                    elif (
                        new_status == "Playing"
                        and position_updated
                    ):
                        position_difference = abs(
                            position
                            - local_position
                        )

                        if (
                            position_difference
                            > SEEK_THRESHOLD
                        ):
                            base_position = position
                            base_time = now

                        last_authoritative_position = position

                playback_status = new_status

        now = time.monotonic()

        if (
            synced
            and playback_status == "Playing"
        ):
            current_position = (
                base_position
                + (now - base_time)
            )
        else:
            current_position = base_position

        with lyrics_lock:
            lyrics = current_lyrics

        if not player_available:
            output = "Waiting for Mewsic..."

        elif current_track is None:
            output = "Waiting for song..."

        elif waiting_for_track_sync:
            output = "♪ ..."

        elif lyrics_loading:
            output = "♪ ..."

        elif current_lyrics == "unsynced":
            output = "Lyrics are not time-synced."

        elif lyrics is None:
            output = "No lyrics found."

        else:
            output = get_lyric(
                lyrics,
                current_position,
            )

        print(
            json.dumps({
                "text": output
            }),
            flush=True,
        )

        time.sleep(DISPLAY_INTERVAL)


if __name__ == "__main__":
    main()
