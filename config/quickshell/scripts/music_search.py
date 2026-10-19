#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import re
import json
import subprocess

CLEAN_RE = re.compile(
    r"\s*[\(\[]"
    r"(?:official\s*(?:music\s*)?(?:4k\s*)?(?:hd\s*)?(?:video|audio|lyric\s*video|visualizer)|"
    r"video\s*oficial|letra|lyrics?|hd|4k|remastered\s*\d*)"
    r"[\)\]]",
    re.IGNORECASE,
)

def clean_title(raw_title, raw_artist):
    title = CLEAN_RE.sub("", raw_title or "Título Desconocido").strip()
    artist = (raw_artist or "Artista Desconocido").replace(" - Topic", "").strip()
    if " - " in title and artist.lower() in title.lower():
        parts = title.split(" - ", 1)
        if len(parts[1].strip()) > 1:
            artist = parts[0].strip()
            title = parts[1].strip()
    return title, artist

def format_entry(e):
    if not e or not e.get("id"):
        return None
    vid_id = e.get("id")
    dur = int(e.get("duration") or 0)
    mins, secs = divmod(dur, 60)
    dur_str = f"{mins:02d}:{secs:02d}" if dur > 0 else "--:--"

    thumbs = e.get("thumbnails") or []
    thumb_url = thumbs[-1].get("url", "") if thumbs else ""
    if not thumb_url:
        thumb_url = f"https://i.ytimg.com/vi/{vid_id}/hqdefault.jpg"

    raw_title = e.get("title", "Título Desconocido")
    raw_artist = e.get("uploader") or e.get("channel") or "Artista Desconocido"
    title, artist = clean_title(raw_title, raw_artist)

    return {
        "id": vid_id,
        "title": title,
        "artist": artist,
        "duration": dur_str,
        "durationSec": dur,
        "url": f"https://www.youtube.com/watch?v={vid_id}",
        "thumbnail": thumb_url,
    }

def search(query, limit=12):
    clean_q = query.strip()
    if not clean_q:
        print("[]")
        return

    cmd_primary = [
        "yt-dlp",
        f"ytsearch1:{clean_q}",
        "--dump-single-json",
        "--flat-playlist",
        "--socket-timeout", "5",
        "--no-warnings",
        "--quiet",
    ]

    primary_id = None
    try:
        res1 = subprocess.run(cmd_primary, capture_output=True, text=True, timeout=8)
        if res1.returncode == 0 and res1.stdout.strip():
            d1 = json.loads(res1.stdout)
            entries1 = d1.get("entries") or []
            if entries1 and entries1[0]:
                primary_id = entries1[0].get("id")
    except Exception:
        pass

    results = []

    if primary_id:
        cmd_mix = [
            "yt-dlp",
            f"https://www.youtube.com/watch?v={primary_id}&list=RD{primary_id}",
            "--dump-single-json",
            "--flat-playlist",
            "--playlist-items", f"1:{limit}",
            "--socket-timeout", "5",
            "--no-warnings",
            "--quiet",
        ]
        try:
            res_mix = subprocess.run(cmd_mix, capture_output=True, text=True, timeout=10)
            if res_mix.returncode == 0 and res_mix.stdout.strip():
                dm = json.loads(res_mix.stdout)
                for e in dm.get("entries") or []:
                    item = format_entry(e)
                    if item:
                        results.append(item)
        except Exception:
            results = []

    if len(results) < 2:
        cmd_fallback = [
            "yt-dlp",
            f"ytsearch{limit}:{clean_q}",
            "--dump-single-json",
            "--flat-playlist",
            "--socket-timeout", "5",
            "--no-warnings",
            "--quiet",
        ]
        try:
            res_fb = subprocess.run(cmd_fallback, capture_output=True, text=True, timeout=10)
            if res_fb.returncode == 0 and res_fb.stdout.strip():
                dfb = json.loads(res_fb.stdout)
                results = []
                for e in dfb.get("entries") or []:
                    item = format_entry(e)
                    if item:
                        results.append(item)
        except Exception:
            pass

    print(json.dumps(results, ensure_ascii=False))

if __name__ == "__main__":
    q = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "Coldplay Yellow"
    search(q, limit=12)
