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
    pkill -9 -f "input-ipc-server=$SOCK" 2>/dev/null
    rm -f "$SOCK"

    local script_args=()
    # mpv automatically loads ~/.config/mpv/scripts/mpris.so; only add if not in user scripts dir
    if [ ! -f "$HOME/.config/mpv/scripts/mpris.so" ] && [ -n "$MPRIS_SCRIPT" ]; then
        script_args+=("--script=$MPRIS_SCRIPT")
    fi
    if [ -f "$HOME/.config/quickshell/scripts/mpv_next.lua" ]; then
        script_args+=("--script=$HOME/.config/quickshell/scripts/mpv_next.lua")
    fi

    setsid mpv --idle=yes \
        --no-video \
        --volume=80 \
        --ao=pulse \
        --input-ipc-server="$SOCK" \
        "${script_args[@]}" \
        --ytdl-format="bestaudio/best" \
        --ytdl-raw-options="extractor-args=youtube:player-client=android" \
        --title="Aura Music" \
        --really-quiet </dev/null >/dev/null 2>&1 &

    for i in {1..40}; do
        if [ -S "$SOCK" ]; then
            python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(0.1)
s.connect(sys.argv[1])
s.close()
' "$SOCK" 2>/dev/null && break
        fi
        sleep 0.05
    done
}

send_to_mpv() {
    python3 -c '
import socket, json, sys, time

sock_path = sys.argv[1]
url = sys.argv[2]
title = sys.argv[3] if len(sys.argv) > 3 else ""

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(2.0)

connected = False
for _ in range(30):
    try:
        s.connect(sock_path)
        connected = True
        break
    except Exception:
        time.sleep(0.05)

if not connected:
    sys.exit(1)

cmds = [
    {"command": ["set_property", "pause", False]},
    {"command": ["loadfile", url, "replace"]}
]
if title.strip():
    cmds.append({"command": ["set_property", "force-media-title", title.strip()]})
cmds.append({"command": ["set_property", "pause", False]})

payload = "".join(json.dumps(c) + "\n" for c in cmds).encode("utf-8")
s.sendall(payload)

try:
    s.settimeout(0.2)
    s.recv(2048)
except Exception:
    pass
s.close()
' "$SOCK" "$URL" "$TITLE"
}

is_mpv_running() {
    [ -S "$SOCK" ] && pgrep -f "input-ipc-server=$SOCK" >/dev/null
}

if ! is_mpv_running; then
    start_mpv
fi

if ! send_to_mpv; then
    start_mpv
    send_to_mpv
fi
