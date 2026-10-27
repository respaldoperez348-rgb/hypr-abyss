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
    if style == "deck":
        rofi_mode = "config-dev.rasi"
        ff_mode = "config-dev.jsonc"
        gtk_css_mode = "gtk-dev.css"
        rounding = 8
        border_sz = 2
    elif style == "notch":
        rofi_mode = "config-pocket.rasi"
        ff_mode = "config-pocket.jsonc"
        gtk_css_mode = "gtk-pocket.css"
        rounding = 20
        border_sz = 2
    else:
        rofi_mode = "config-daily.rasi"
        ff_mode = "config-daily.jsonc"
        gtk_css_mode = "gtk-daily.css"
        rounding = 16
        border_sz = 1
    
    # 1. Rofi Launcher Switch
    link_file(home / ".config" / "rofi" / rofi_mode, home / ".config" / "rofi" / "config.rasi")

    # 2. Fastfetch Specs Switch
    link_file(home / ".config" / "fastfetch" / ff_mode, home / ".config" / "fastfetch" / "config.jsonc")

    # 3. GTK 3 CSS Switch
    link_file(home / ".config" / "gtk-3.0" / gtk_css_mode, home / ".config" / "gtk-3.0" / "gtk.css")

    # 4. Hyprland Borders & Rounding (vía Hyprland Lua eval)
    os.system(f"hyprctl eval 'hl.config({{ decoration = {{ rounding = {rounding} }}, general = {{ border_size = {border_sz} }} }})' >/dev/null 2>&1")

def set_style(style, from_quickshell=False):
    if style not in ["deck", "island", "notch"]:
        style = "deck"
    
    # Sincronizar con el orquestador maestro setup_manager
    setup_mgr = Path.home() / ".config" / "quickshell" / "scripts" / "setup_manager.py"
    if setup_mgr.exists():
        mode_map = {"deck": "dev", "island": "daily", "notch": "pocket"}
        mode = mode_map.get(style, "dev")
        qs_flag = ["--from-quickshell"] if from_quickshell else []
        os.system(f"python3 {setup_mgr} switch {mode} {' '.join(qs_flag)} >/dev/null 2>&1")
    else:
        sync_environment(style)

    data = {"style": style}
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    
    if not from_quickshell:
        os.system(f"quickshell ipc call bar set {style} >/dev/null 2>&1")
    return style

def toggle_style(from_quickshell=False):
    current = get_style()
    styles = ["deck", "island", "notch"]
    idx = styles.index(current) if current in styles else 0
    new_style = styles[(idx + 1) % len(styles)]
    return set_style(new_style, from_quickshell=from_quickshell)

if __name__ == "__main__":
    from_qs = "--from-quickshell" in sys.argv
    clean_argv = [a for a in sys.argv if a != "--from-quickshell"]
    if len(clean_argv) > 1:
        cmd = clean_argv[1].lower()
        if cmd == "get":
            print(get_style())
        elif cmd == "set" and len(clean_argv) > 2:
            print(set_style(clean_argv[2], from_quickshell=from_qs))
        elif cmd == "toggle":
            print(toggle_style(from_quickshell=from_qs))
        else:
            print(get_style())
    else:
        print(get_style())
