#!/bin/bash
URL="$1"
TITLE="$2"
ARTIST="$3"
THUMB="$4"
SOCK="/tmp/kiss_music_mpv.sock"
STATE_FILE="/dev/shm/aura_now_playing.json"

MPRIS_SCRIPT=""
if [ -f "$HOME/.config/mpv/scripts/mpris.so" ]; then
    MPRIS_SCRIPT="$HOME/.config/mpv/scripts/mpris.so"
elif [ -f "/usr/lib/mpv/mpris.so" ]; then
    MPRIS_SCRIPT="/usr/lib/mpv/mpris.so"
elif [ -f "/usr/lib64/mpv/mpris.so" ]; then
    MPRIS_SCRIPT="/usr/lib64/mpv/mpris.so"
fi

if [ -z "$URL" ]; then
    exit 0
fi

# Guardar metadatos actuales en RAM para sincronización instantánea con Dynamic Island
python3 -c '
import json, sys
data = {
    "url": sys.argv[1],
    "title": sys.argv[2],
    "artist": sys.argv[3],
    "thumbnail": sys.argv[4]
}
with open(sys.argv[5], "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
' "$URL" "${TITLE:-Música}" "${ARTIST:-Aura Music}" "${THUMB:-}" "$STATE_FILE" 2>/dev/null

start_mpv() {
    rm -f "$SOCK"
    pkill -9 -f "$SOCK" 2>/dev/null

    local script_args=()
    if [ -n "$MPRIS_SCRIPT" ]; then
        script_args+=("--script=$MPRIS_SCRIPT")
    fi
    if [ -f "$HOME/.config/quickshell/scripts/mpv_next.lua" ]; then
        script_args+=("--script=$HOME/.config/quickshell/scripts/mpv_next.lua")
    fi

    mpv --idle=yes \
        --no-video \
        --volume=80 \
        --input-ipc-server="$SOCK" \
        "${script_args[@]}" \
        --ytdl-format="bestaudio/best" \
        --title="Aura Music" \
        --really-quiet &

    for i in {1..30}; do
        if [ -S "$SOCK" ]; then
            break
        fi
        sleep 0.05
    done
}

send_to_mpv() {
    python3 -c '
import socket, json, sys

sock_path = sys.argv[1]
url = sys.argv[2]
title = sys.argv[3] if len(sys.argv) > 3 else ""

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(3.0)
s.connect(sock_path)
s.sendall(json.dumps({"command": ["set_property", "pause", False]}).encode("utf-8") + b"\n")
s.recv(1024)
s.sendall(json.dumps({"command": ["loadfile", url, "replace"]}).encode("utf-8") + b"\n")
s.recv(1024)
if title.strip():
    s.sendall(json.dumps({"command": ["set_property", "force-media-title", title.strip()]}).encode("utf-8") + b"\n")
    s.recv(1024)
s.sendall(json.dumps({"command": ["set_property", "pause", False]}).encode("utf-8") + b"\n")
s.recv(1024)
s.close()
' "$SOCK" "$URL" "$TITLE"
}

if [ ! -S "$SOCK" ] || ! pgrep -f "$SOCK" > /dev/null; then
    start_mpv
fi

if ! send_to_mpv 2>/dev/null; then
    start_mpv
    send_to_mpv 2>/dev/null
fi
