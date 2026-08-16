#!/usr/bin/env python3
import subprocess
import urllib.parse
import urllib.request
import json
import time
import re

def get_mpris_data():
    try:
        # 1. Get Artist and Title
        meta = subprocess.check_output(
            ['playerctl', '-p', 'mewsic', 'metadata', '--format', '{{artist}}||{{title}}'], 
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        
        # 2. Get Interpolated Position (in seconds)
        pos_str = subprocess.check_output(
            ['playerctl', '-p', 'mewsic', 'position'], 
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        
        return meta, float(pos_str)
    except Exception:
        return None, 0.0

def parse_lrc(lrc_str):
    lines = []
    pattern = re.compile(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)')
    for line in lrc_str.split('\n'):
        match = pattern.match(line)
        if match:
            mins = int(match.group(1))
            secs = float(match.group(2))
            text = match.group(3).strip()
            if text:
                lines.append((mins * 60 + secs, text))
    return lines

def fetch_synced_lyrics(artist, title):
    # Clean up the title to improve LRCLIB match rate (removes parenthesis/bracket tags)
    clean_title = re.sub(r'\(.*?\)|\[.*?\]', '', title).strip()
    query = urllib.parse.urlencode({'track_name': clean_title, 'artist_name': artist})
    url = f"https://lrclib.net/api/get?{query}"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'MewsicLyricsWidget/1.0'})
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode())
            if data.get('syncedLyrics'):
                return parse_lrc(data['syncedLyrics'])
            elif data.get('plainLyrics'):
                return "unsynced"
    except Exception:
        pass
    return None

def main():
    current_meta = None
    current_lyrics = None
    
    while True:
        meta, pos = get_mpris_data()
        
        if meta and meta != current_meta:
            current_meta = meta
            if '||' in meta:
                artist, title = meta.split('||', 1)
                current_lyrics = fetch_synced_lyrics(artist.strip(), title.strip())
            else:
                current_lyrics = None

        output_text = "♪ ..."
        
        if not meta:
            output_text = "Waiting for Mewsic..."
        elif current_lyrics == "unsynced":
            output_text = "(Lyrics found, but not time-synced)"
        elif current_lyrics is None:
            output_text = "No lyrics found."
        else:
            current_line = "♪ ..."
            for time_sec, text in current_lyrics:
                if time_sec <= pos:
                    current_line = text
                else:
                    break
            output_text = current_line
        
        print(json.dumps({"text": output_text}), flush=True)
        time.sleep(0.1)

if __name__ == "__main__":
    main()
