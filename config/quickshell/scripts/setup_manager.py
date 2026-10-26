#!/usr/bin/env python3
"""
setup_manager.py - Orquestador Global de Metamorfosis de Setup
Conmuta de forma atómica y en tiempo real todo el entorno:
- Quickshell (Dynamic Island vs Hyper-Utility Deck)
- Fastfetch (Pac-man retro vs Arch Cyberpunk)
- Kitty Terminal (Opacidad y paleta en caliente vía IPC)
- Thunar & GTK (Iconos y temas con gsettings)
- Hyprland (Bordes, radio de curvatura y animaciones)
- Fondos de pantalla independientes con Pywal
- Sincronización de bloqueo (Hyprlock) y login
"""
import sys
import os
import json
import subprocess
from pathlib import Path

CONFIG_DIR = Path.home() / ".config"
QUICKSHELL_DIR = CONFIG_DIR / "quickshell"
PROFILE_FILE = QUICKSHELL_DIR / "setup_profile.json"
WALLPAPERS_DIR = Path.home() / "Pictures" / "Wallpapers"

DEFAULT_CONFIG = {
    "active": "dev",
    "profiles": {
        "daily": {
            "name": "Diario (Zen Glass)",
            "bar_style": "island",
            "wallpaper": str(WALLPAPERS_DIR / "train_and_lake.png"),
            "icon_theme": "Tela-circle-nord-dark",
            "gtk_theme": "adw-gtk3-dark",
            "fastfetch_config": "config-daily.jsonc",
            "kitty_opacity": "0.76",
            "hypr_rounding": 14,
            "hypr_border_size": 1
        },
        "dev": {
            "name": "Programación (Cyberpunk)",
            "bar_style": "deck",
            "wallpaper": str(WALLPAPERS_DIR / "hacker.png"),
            "icon_theme": "Tela-circle-dracula-dark",
            "gtk_theme": "adw-gtk3-dark",
            "fastfetch_config": "config-dev.jsonc",
            "kitty_opacity": "0.88",
            "hypr_rounding": 8,
            "hypr_border_size": 2
        }
    }
}

def load_data():
    if PROFILE_FILE.exists():
        try:
            with open(PROFILE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data
        except Exception:
            pass
    save_data(DEFAULT_CONFIG)
    return DEFAULT_CONFIG

def save_data(data):
    PROFILE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(PROFILE_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

def run_quiet(cmd):
    try:
        subprocess.run(cmd, shell=isinstance(cmd, str), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def apply_profile(profile_key):
    data = load_data()
    if profile_key not in data.get("profiles", {}):
        profile_key = "dev"
    
    prof = data["profiles"][profile_key]
    data["active"] = profile_key
    save_data(data)

    home = Path.home()

    # 1. Fastfetch Switch (Symlink a la configuración activa)
    ff_src = home / ".config" / "fastfetch" / prof.get("fastfetch_config", "config-daily.jsonc")
    ff_dst = home / ".config" / "fastfetch" / "config.jsonc"
    if ff_src.exists():
        try:
            if ff_dst.is_symlink() or ff_dst.exists():
                ff_dst.unlink()
            ff_dst.symlink_to(ff_src)
        except Exception:
            pass

    # 2. GTK & Thunar Icons y Tema
    run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", prof.get("icon_theme", "Tela-circle-dracula-dark")])
    run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", prof.get("gtk_theme", "adw-gtk3-dark")])

    # 3. Hyprland Rounding y Bordes en Caliente
    run_quiet(["hyprctl", "keyword", "decoration:rounding", str(prof.get("hypr_rounding", 10))])
    run_quiet(["hyprctl", "keyword", "general:border_size", str(prof.get("hypr_border_size", 2))])

    # 4. Kitty Terminal Opacity Live Reload
    opacity = prof.get("kitty_opacity", "0.85")
    run_quiet(["kitty", "@", "--to", "unix:@mykitty", "set-background-opacity", opacity])

    # 5. Quickshell Bar Switch vía IPC
    bar_style = prof.get("bar_style", "deck")
    run_quiet(["quickshell", "ipc", "call", "bar", "set", bar_style])

    # 6. Fondo de pantalla con Pywal + Hyprlock/SDDM
    wp_path = prof.get("wallpaper")
    if wp_path and Path(wp_path).exists():
        wallchange_script = home / ".config" / "hypr" / "scripts" / "wallchange.sh"
        if wallchange_script.exists():
            run_quiet([str(wallchange_script), wp_path])

    # 7. Notificación visual
    run_quiet([
        "notify-send",
        "-a", "Setup Master",
        "-i", "preferences-desktop-theme",
        f"Modo {prof.get('name')} Activado",
        "Ecosistema visual transformado por completo"
    ])

    return profile_key

def toggle_profile():
    data = load_data()
    curr = data.get("active", "dev")
    nxt = "daily" if curr == "dev" else "dev"
    return apply_profile(nxt)

def set_wallpaper_for_active(wp_path):
    data = load_data()
    curr = data.get("active", "dev")
    if curr in data.get("profiles", {}):
        data["profiles"][curr]["wallpaper"] = str(wp_path)
        save_data(data)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1].lower()
        if cmd == "switch" and len(sys.argv) > 2:
            print(apply_profile(sys.argv[2]))
        elif cmd == "toggle":
            print(toggle_profile())
        elif cmd == "get":
            data = load_data()
            print(data.get("active", "dev"))
        elif cmd == "set-wp" and len(sys.argv) > 2:
            set_wallpaper_for_active(sys.argv[2])
        else:
            print(load_data().get("active", "dev"))
    else:
        print(load_data().get("active", "dev"))
