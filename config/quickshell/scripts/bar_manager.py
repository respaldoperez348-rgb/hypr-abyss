#!/usr/bin/env python3
import sys
import json
import os
from pathlib import Path

CONFIG_PATH = Path.home() / ".config" / "quickshell" / "bar_config.json"

def get_style():
    if CONFIG_PATH.exists():
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("style", "deck")
        except Exception:
            pass
    return "deck"

def set_style(style):
    if style not in ["deck", "island"]:
        style = "deck"
    data = {"style": style}
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    return style

def toggle_style():
    current = get_style()
    new_style = "island" if current == "deck" else "deck"
    return set_style(new_style)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1].lower()
        if cmd == "get":
            print(get_style())
        elif cmd == "set" and len(sys.argv) > 2:
            print(set_style(sys.argv[2]))
        elif cmd == "toggle":
            print(toggle_style())
        else:
            print(get_style())
    else:
        print(get_style())
