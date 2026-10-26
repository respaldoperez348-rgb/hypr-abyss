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

def link_file(src: Path, dst: Path):
    if src.exists():
        try:
            if dst.is_symlink() or dst.exists():
                dst.unlink()
            dst.symlink_to(src)
        except Exception:
            pass

def sync_environment(style):
    home = Path.home()
    is_dev = (style == "deck")
    
    # 1. Rofi Launcher Switch
    rofi_mode = "config-dev.rasi" if is_dev else "config-daily.rasi"
    link_file(home / ".config" / "rofi" / rofi_mode, home / ".config" / "rofi" / "config.rasi")

    # 2. Fastfetch Specs Switch
    ff_mode = "config-dev.jsonc" if is_dev else "config-daily.jsonc"
    link_file(home / ".config" / "fastfetch" / ff_mode, home / ".config" / "fastfetch" / "config.jsonc")

    # 3. GTK 3 CSS Switch
    gtk_css_mode = "gtk-dev.css" if is_dev else "gtk-daily.css"
    link_file(home / ".config" / "gtk-3.0" / gtk_css_mode, home / ".config" / "gtk-3.0" / "gtk.css")

    # 4. Hyprland Borders & Rounding
    if is_dev:
        os.system("hyprctl keyword decoration:rounding 8 >/dev/null 2>&1")
        os.system("hyprctl keyword general:border_size 2 >/dev/null 2>&1")
    else:
        os.system("hyprctl keyword decoration:rounding 16 >/dev/null 2>&1")
        os.system("hyprctl keyword general:border_size 1 >/dev/null 2>&1")

def set_style(style):
    if style not in ["deck", "island", "notch"]:
        style = "deck"
    data = {"style": style}
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.system(f"quickshell ipc call bar set {style} >/dev/null 2>&1")
    sync_environment(style)
    return style

def toggle_style():
    current = get_style()
    styles = ["deck", "island", "notch"]
    idx = styles.index(current) if current in styles else 0
    new_style = styles[(idx + 1) % len(styles)]
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
