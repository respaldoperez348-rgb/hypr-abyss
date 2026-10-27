#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aura Music - Core Service Daemon
Ultra-lightweight persistent backend managing MPV via Unix Domain Socket IPC,
async yt-dlp queries, queue management, and line-delimited JSON IPC with Quickshell.
"""

import sys
import os
import json
import socket
import subprocess
import threading
import time
import re
import random
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).resolve().parent.parent
def get_favorites_path():
    qs_fav = Path(os.path.expanduser("~/.config/quickshell/favorites.json"))
    if qs_fav.exists():
        return qs_fav
    return BASE_DIR / "favorites.json"

FAVORITES_FILE = get_favorites_path()
MPV_SOCK = "/tmp/aura_mpv.sock"

# Regex for clean music titles
CLEAN_RE = re.compile(
    r"\s*[\(\[]"
    r"(?:official\s*(?:music\s*)?(?:4k\s*)?(?:hd\s*)?(?:video|audio|lyric\s*video|visualizer)|"
    r"video\s*oficial|letra|lyrics?|hd|4k|remastered\s*\d*)"
    r"[\)\]]",
    re.IGNORECASE,
)

def emit(event_type, **kwargs):
    """Emit JSON event line to stdout for Quickshell SplitParser."""
    payload = {"type": event_type, **kwargs}
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()

def clean_title_artist(raw_title, raw_artist):
    title = CLEAN_RE.sub("", raw_title or "Título Desconocido").strip()
    artist = (raw_artist or "Artista Desconocido").replace(" - Topic", "").strip()
    if " - " in title and artist.lower() in title.lower():
        parts = title.split(" - ", 1)
        if len(parts[1].strip()) > 1:
            artist = parts[0].strip()
            title = parts[1].strip()
    return title, artist


class FavoritesManager:
    def __init__(self, filepath):
        self.filepath = Path(filepath)
        self.items = self.load()

    def load(self):
        if self.filepath.exists():
            try:
                with open(self.filepath, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return []

    def save(self):
        try:
            with open(self.filepath, "w", encoding="utf-8") as f:
                json.dump(self.items, f, indent=2, ensure_ascii=False)
        except Exception as e:
            sys.stderr.write(f"Error saving favorites: {e}\n")

    def is_favorite(self, track_id):
        return any(t.get("id") == track_id or t.get("url") == track_id for t in self.items)

    def toggle(self, track):
        if not track:
            return self.items
        tid = track.get("id") or track.get("url")
        idx = next((i for i, t in enumerate(self.items) if t.get("id") == tid or t.get("url") == tid), None)
        if idx is not None:
            self.items.pop(idx)
        else:
            self.items.insert(0, track)
        self.save()
        return self.items


class MPVController:
    def __init__(self, sock_path):
        self.sock_path = sock_path
        self.proc = None
        self.sock = None
        self.running = False
        self.is_paused = False
        self.time_pos = 0.0
        self.duration = 0.0
        self.volume = 80
        self.lock = threading.Lock()
        self.on_eof_callback = None
        self.last_progress_emit = 0

    def start_mpv(self):
        try:
            subprocess.run(["pkill", "-9", "-f", f"input-ipc-server={self.sock_path}"], stderr=subprocess.DEVNULL)
            subprocess.run(["pkill", "-9", "-f", "title=Aura Music"], stderr=subprocess.DEVNULL)
        except Exception:
            pass
        if os.path.exists(self.sock_path):
            try:
                os.remove(self.sock_path)
            except Exception:
                pass

        cmd = [
            "mpv",
            "--idle=yes",
            "--no-video",
            f"--volume={self.volume}",
            f"--input-ipc-server={self.sock_path}",
            "--ao=pulse",
            "--really-quiet",
            "--ytdl-format=bestaudio/best",
            '--ytdl-raw-options=extractor-args=youtube:player-client=android',
            "--title=Aura Music",
        ]
        self.proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Wait up to 2 seconds for socket creation
        for _ in range(40):
            if os.path.exists(self.sock_path):
                break
            time.sleep(0.05)

        self.connect_socket()

    def connect_socket(self):
        try:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(self.sock_path)
            self.running = True
            
            # Observe MPV properties for real-time reactive events
            self.send_command(["observe_property", 1, "time-pos"])
            self.send_command(["observe_property", 2, "duration"])
            self.send_command(["observe_property", 3, "pause"])
            self.send_command(["observe_property", 4, "volume"])

            # Start background reader thread
            threading.Thread(target=self._reader_loop, daemon=True).start()
        except Exception as e:
            sys.stderr.write(f"MPV socket connect error: {e}\n")

    def _reader_loop(self):
        buffer = ""
        while self.running and self.sock:
            try:
                chunk = self.sock.recv(4096)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="ignore")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if line:
                        self._handle_mpv_message(line)
            except Exception:
                break
        self.running = False

    def _handle_mpv_message(self, line):
        try:
            data = json.loads(line)
            event = data.get("event")
            if event == "property-change":
                name = data.get("name")
                val = data.get("data")
                if name == "time-pos" and val is not None:
                    self.time_pos = float(val)
                    now = time.time()
                    # Throttle progress updates to ~4 times per second to prevent QML UI flooding
                    if now - self.last_progress_emit >= 0.25:
                        self.last_progress_emit = now
                        emit("progress", pos=round(self.time_pos, 1), duration=round(self.duration, 1))
                elif name == "duration" and val is not None and float(val) > 0:
                    self.duration = float(val)
                    emit("duration", duration=round(self.duration, 1))
                elif name == "pause":
                    self.is_paused = bool(val)
                    emit("state", playing=not self.is_paused)
                elif name == "volume" and val is not None:
                    self.volume = int(val)
                    emit("volume", volume=self.volume)
            elif event == "end-file":
                reason = data.get("reason")
                if reason in ("eof", "error") and self.on_eof_callback:
                    threading.Thread(target=self.on_eof_callback, daemon=True).start()
        except Exception:
            pass

    def send_command(self, cmd_args):
        with self.lock:
            if not self.sock:
                return
            try:
                msg = json.dumps({"command": cmd_args}) + "\n"
                self.sock.sendall(msg.encode("utf-8"))
            except Exception:
                pass

    def load_track(self, url):
        self.time_pos = 0.0
        self.duration = 0.0
        self.send_command(["loadfile", url, "replace"])
        self.send_command(["set_property", "pause", False])
        self.is_paused = False
        emit("state", playing=True)

    def toggle_play(self):
        self.send_command(["cycle", "pause"])

    def pause(self):
        self.send_command(["set_property", "pause", True])

    def resume(self):
        self.send_command(["set_property", "pause", False])

    def seek(self, seconds):
        self.send_command(["seek", seconds, "absolute"])

    def set_volume(self, vol):
        vol = max(0, min(100, int(vol)))
        self.volume = vol
        self.send_command(["set_property", "volume", vol])

    def quit(self):
        self.running = False
        if self.sock:
            try:
                self.send_command(["quit"])
                self.sock.close()
            except Exception:
                pass
        if self.proc:
            try:
                self.proc.terminate()
            except Exception:
                pass
        if os.path.exists(self.sock_path):
            try:
                os.remove(self.sock_path)
            except Exception:
                pass


class AuraService:
    def __init__(self):
        self.favorites = FavoritesManager(FAVORITES_FILE)
        self.mpv = MPVController(MPV_SOCK)
        self.mpv.on_eof_callback = self.handle_auto_next
        self.queue = list(self.favorites.items) if self.favorites.items else []
        self.current_index = 0
        self.current_track = self.queue[0] if self.queue else None
        self.shuffle = False
        self.repeat_mode = "none" # "none", "one", "all"
        self._last_auto_next = 0

    def start(self):
        import signal, atexit
        def _cleanup(*args):
            self.mpv.quit()
        atexit.register(_cleanup)
        try:
            signal.signal(signal.SIGTERM, _cleanup)
            signal.signal(signal.SIGINT, _cleanup)
            signal.signal(signal.SIGHUP, _cleanup)
        except Exception:
            pass

        self.mpv.start_mpv()
        
        # Initial state emit
        emit("init",
             favorites=self.favorites.items,
             queue=self.queue,
             currentTrack=self.current_track,
             shuffle=self.shuffle,
             repeat=self.repeat_mode,
             volume=self.mpv.volume)

        # Stdin command loop
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
                self.dispatch_command(msg)
            except Exception as e:
                sys.stderr.write(f"Command parse error: {e}\n")

    def dispatch_command(self, msg):
        cmd = msg.get("cmd")
        if not cmd:
            return

        if cmd == "play_track":
            track = msg.get("track")
            if track:
                self.play_track(track)
        elif cmd == "play_queue_index":
            idx = msg.get("index", 0)
            self.play_index(idx)
        elif cmd == "toggle":
            self.mpv.toggle_play()
        elif cmd == "pause":
            self.mpv.pause()
        elif cmd == "resume":
            self.mpv.resume()
        elif cmd == "next":
            self.play_next()
        elif cmd == "prev":
            self.play_prev()
        elif cmd == "seek":
            pos = float(msg.get("pos", 0))
            self.mpv.seek(pos)
        elif cmd == "set_volume":
            vol = int(msg.get("volume", 80))
            self.mpv.set_volume(vol)
        elif cmd == "toggle_favorite":
            track = msg.get("track") or self.current_track
            updated = self.favorites.toggle(track)
            emit("favorites", favorites=updated)
            if self.current_track:
                is_fav = self.favorites.is_favorite(self.current_track.get("id"))
                emit("current_favorite_status", isFavorite=is_fav)
        elif cmd == "get_favorites":
            emit("favorites", favorites=self.favorites.items)
        elif cmd == "play_all_favorites":
            if self.favorites.items:
                self.queue = list(self.favorites.items)
                emit("queue", queue=self.queue, index=0)
                self.play_index(0)
        elif cmd == "set_shuffle":
            self.shuffle = bool(msg.get("shuffle", False))
            emit("shuffle", shuffle=self.shuffle)
        elif cmd == "set_repeat":
            self.repeat_mode = msg.get("repeat", "none")
            emit("repeat", repeat=self.repeat_mode)
        elif cmd == "search":
            query = msg.get("query", "").strip()
            if query:
                threading.Thread(target=self.async_search, args=(query,), daemon=True).start()
        elif cmd == "quit":
            self.mpv.quit()
            sys.exit(0)

    def play_track(self, track):
        self.current_track = track
        url = track.get("url")
        if not url and track.get("id"):
            url = f"https://www.youtube.com/watch?v={track['id']}"

        dur = float(track.get("durationSec") or 0)
        self.mpv.duration = dur
        self.mpv.time_pos = 0.0

        # Synchronize queue index
        found = False
        for i, t in enumerate(self.queue):
            if (t.get("id") and t.get("id") == track.get("id")) or (t.get("url") and t.get("url") == url):
                self.current_index = i
                found = True
                break
        if not found:
            self.queue.insert(self.current_index + 1, track)
            self.current_index += 1
            emit("queue", queue=self.queue, index=self.current_index)
        else:
            emit("queue", queue=self.queue, index=self.current_index)

        emit("track", track=self.current_track, index=self.current_index)
        if dur > 0:
            emit("duration", duration=round(dur, 1))
        emit("progress", pos=0.0, duration=round(dur, 1))

        is_fav = self.favorites.is_favorite(track.get("id"))
        emit("current_favorite_status", isFavorite=is_fav)

        # Write metadata to RAM for MediaIsland (Dynamic Island / Notch) sync
        try:
            with open("/dev/shm/aura_now_playing.json", "w", encoding="utf-8") as f:
                json.dump({
                    "url": url,
                    "title": track.get("title", "Música"),
                    "artist": track.get("artist", "Aura Music"),
                    "thumbnail": track.get("thumbnail", "")
                }, f, ensure_ascii=False)
        except Exception:
            pass
        
        self.mpv.load_track(url)

    def play_index(self, index):
        if 0 <= index < len(self.queue):
            self.current_index = index
            self.play_track(self.queue[index])

    def play_next(self):
        if not self.queue:
            return
        if self.repeat_mode == "one":
            self.play_index(self.current_index)
            return

        if self.shuffle:
            next_idx = random.randint(0, len(self.queue) - 1)
        else:
            next_idx = self.current_index + 1
            if next_idx >= len(self.queue):
                if self.repeat_mode == "all" or self.repeat_mode == "none":
                    next_idx = 0
                else:
                    return

        self.play_index(next_idx)

    def play_prev(self):
        if not self.queue:
            return
        if self.mpv.time_pos > 3.0:
            # If already played > 3 seconds, replay current song
            self.mpv.seek(0)
            return

        prev_idx = self.current_index - 1
        if prev_idx < 0:
            prev_idx = len(self.queue) - 1 if self.repeat_mode == "all" else 0

        self.play_index(prev_idx)

    def handle_auto_next(self):
        now = time.time()
        if now - getattr(self, "_last_auto_next", 0) < 1.0:
            return
        self._last_auto_next = now
        self.play_next()

    def async_search(self, query):
        emit("searching", isSearching=True)
        try:
            cmd = [
                "yt-dlp",
                f"ytsearch12:{query}",
                "--dump-json",
                "--default-search=ytsearch",
                "--no-playlist",
                "--skip-download",
                "--no-warnings",
                "--flat-playlist",
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=12)
            results = []
            for line in res.stdout.strip().split("\n"):
                if not line.strip():
                    continue
                try:
                    e = json.loads(line)
                    vid_id = e.get("id")
                    if not vid_id:
                        continue
                    dur = int(e.get("duration") or 0)
                    mins, secs = divmod(dur, 60)
                    dur_str = f"{mins:02d}:{secs:02d}" if dur > 0 else "--:--"

                    thumbs = e.get("thumbnails") or []
                    thumb_url = thumbs[-1].get("url", "") if thumbs else f"https://i.ytimg.com/vi/{vid_id}/hqdefault.jpg"

                    raw_title = e.get("title", "Título Desconocido")
                    raw_artist = e.get("uploader") or e.get("channel") or "Artista Desconocido"
                    title, artist = clean_title_artist(raw_title, raw_artist)

                    results.append({
                        "id": vid_id,
                        "title": title,
                        "artist": artist,
                        "duration": dur_str,
                        "durationSec": dur,
                        "url": f"https://www.youtube.com/watch?v={vid_id}",
                        "thumbnail": thumb_url,
                    })
                except Exception:
                    pass

            emit("search_results", query=query, results=results)
        except Exception as e:
            sys.stderr.write(f"Search error: {e}\n")
            emit("search_results", query=query, results=[])
        finally:
            emit("searching", isSearching=False)


if __name__ == "__main__":
    service = AuraService()
    try:
        service.start()
    except KeyboardInterrupt:
        service.mpv.quit()
