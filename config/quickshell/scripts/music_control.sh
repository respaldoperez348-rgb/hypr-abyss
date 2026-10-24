#!/bin/bash
ACTION="$1"
VALUE="$2"
SOCK="/tmp/kiss_music_mpv.sock"
STATE_FILE="/dev/shm/aura_now_playing.json"

if [ "$ACTION" = "quit" ]; then
    echo "{\"command\": [\"quit\"]}" | socat - "$SOCK" 2>/dev/null
    pkill -f "music_play.sh" 2>/dev/null
    sleep 0.05
    pkill -9 -f "input-ipc-server=$SOCK" 2>/dev/null
    rm -f "$SOCK" "$STATE_FILE" 2>/dev/null
    exit 0
fi

if [ ! -S "$SOCK" ]; then
    exit 0
fi

python3 -c '
import socket, json, sys

sock_path = sys.argv[1]
action = sys.argv[2]
val = sys.argv[3] if len(sys.argv) > 3 else "0"

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(1.5)
s.connect(sock_path)

if action == "seek":
    cmd = ["seek", float(val), "relative"]
elif action == "seek_abs":
    cmd = ["seek", float(val), "absolute"]
elif action == "volume":
    cmd = ["set_property", "volume", float(val)]
elif action == "toggle":
    cmd = ["cycle", "pause"]
elif action == "stop":
    cmd = ["stop"]
else:
    cmd = None

if cmd:
    s.sendall(json.dumps({"command": cmd}).encode("utf-8") + b"\n")
s.close()
' "$SOCK" "$ACTION" "$VALUE" 2>/dev/null
