#!/usr/bin/env python3
"""
setup_manager.py - Orquestador Global de Metamorfosis de Setup
Conmuta de forma atómica y en tiempo real todo el entorno:
- Quickshell (Dynamic Island vs Hyper-Utility Deck)
- Wallpaper (Sereno lago pastel vs Ciudad Cyberpunk neón) con Pywal
- Fastfetch (Pac-man retro vs Arch Cyberpunk con specs dev)
- Kitty Terminal (Tema pastel/cyan vs Tokio Night Neón y opacidad)
- Rofi Launcher (Spotlight minimalista claro vs Cockpit HUD oscuro neón)
- Thunar & GTK 3/4 (Tema claro adw-gtk3 + Tela-circle-nord vs oscuro adw-gtk3-dark + Tela-circle-dracula)
- Hyprland (Bordes curvados 16px suaves vs Bordes afilados 8px neón reactivos)
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
            "gtk_css": "gtk-daily.css",
            "color_scheme": "prefer-dark",
            "gtk_prefer_dark": "1",
            "fastfetch_config": "config-daily.jsonc",
            "rofi_config": "config-daily.rasi",
            "kitty_theme": "theme-daily.conf",
            "kitty_opacity": "0.78",
            "hypr_rounding": 16,
            "hypr_border_size": 1,
            "hypr_border_color": "rgba(a8d8e8ee) rgba(b8e0d2ee) 45deg",
            "hypr_opacity": "0.88"
        },
        "dev": {
            "name": "Programación (Cyberpunk Cockpit)",
            "bar_style": "deck",
            "wallpaper": str(WALLPAPERS_DIR / "cyber_city_ai.jpg"),
            "icon_theme": "Tela-circle-dracula-dark",
            "gtk_theme": "adw-gtk3-dark",
            "color_scheme": "prefer-dark",
            "gtk_prefer_dark": "1",
            "fastfetch_config": "config-dev.jsonc",
            "rofi_config": "config-dev.rasi",
            "kitty_theme": "theme-dev.conf",
            "kitty_opacity": "0.92",
            "hypr_rounding": 8,
            "hypr_border_size": 2,
            "hypr_border_color": "rgba(00ffccee) rgba(bd93f9ee) 45deg",
            "hypr_opacity": "0.95"
        },
        "pocket": {
            "name": "Isla Pocket (Dynamic Notch)",
            "bar_style": "notch",
            "wallpaper": str(WALLPAPERS_DIR / "windows-11-monochrome-crimson-v0-ji17gc6yntxh1.webp"),
            "icon_theme": "Tela-circle-nord-dark",
            "gtk_theme": "adw-gtk3-dark",
            "gtk_css": "gtk-pocket.css",
            "color_scheme": "prefer-dark",
            "gtk_prefer_dark": "1",
            "fastfetch_config": "config-pocket.jsonc",
            "rofi_config": "config-pocket.rasi",
            "kitty_theme": "theme-pocket.conf",
            "kitty_opacity": "0.85",
            "hyprlock_config": "hyprlock-pocket.conf",
            "hypr_rounding": 20,
            "hypr_border_size": 2,
            "hypr_border_color": "rgba(e056fdee) rgba(00f2feee) 45deg",
            "hypr_opacity": "0.90"
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

def link_file(src: Path, dst: Path):
    if src.exists():
        try:
            if dst.is_symlink() or dst.exists():
                dst.unlink()
            dst.symlink_to(src)
        except Exception:
            pass

def update_gtk_settings_ini(theme_name, icon_name, prefer_dark):
    ini_path = Path.home() / ".config" / "gtk-3.0" / "settings.ini"
    if not ini_path.exists():
        return
    try:
        lines = []
        with open(ini_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("gtk-theme-name="):
                    lines.append(f"gtk-theme-name={theme_name}\n")
                elif line.startswith("gtk-icon-theme-name="):
                    lines.append(f"gtk-icon-theme-name={icon_name}\n")
                elif line.startswith("gtk-application-prefer-dark-theme="):
                    lines.append(f"gtk-application-prefer-dark-theme={prefer_dark}\n")
                else:
                    lines.append(line)
        with open(ini_path, "w", encoding="utf-8") as f:
            f.writelines(lines)
    except Exception:
        pass

def apply_profile(profile_key, from_quickshell=False):
    data = load_data()
    if profile_key not in data.get("profiles", {}):
        profile_key = "dev"
    
    prof = data["profiles"][profile_key]
    data["active"] = profile_key
    save_data(data)

    home = Path.home()

    # 1. Fastfetch Switch (Symlink)
    ff_src = home / ".config" / "fastfetch" / prof.get("fastfetch_config", "config-daily.jsonc")
    ff_dst = home / ".config" / "fastfetch" / "config.jsonc"
    link_file(ff_src, ff_dst)

    # 2. Rofi Switch (Symlink)
    rofi_src = home / ".config" / "rofi" / prof.get("rofi_config", "config-daily.rasi")
    rofi_dst = home / ".config" / "rofi" / "config.rasi"
    link_file(rofi_src, rofi_dst)

    # 3. Kitty Terminal Theme & Opacity (Recarga en caliente sobre todos los sockets activos)
    kitty_src = home / ".config" / "kitty" / prof.get("kitty_theme", "theme-daily.conf")
    kitty_dst = home / ".config" / "kitty" / "theme.conf"
    link_file(kitty_src, kitty_dst)
    
    opacity = prof.get("kitty_opacity", "0.85")
    try:
        import re
        ss_out = subprocess.check_output(["ss", "-xl"], text=True, stderr=subprocess.DEVNULL)
        for sock in re.findall(r"@mykitty-\d+", ss_out):
            run_quiet(["kitty", "@", "--to", f"unix:{sock}", "set-colors", "--all", str(kitty_dst)])
            run_quiet(["kitty", "@", "--to", f"unix:{sock}", "set-background-opacity", opacity])
    except Exception:
        pass

    # 4. Hyprlock Lockscreen Switch (Symlink)
    hl_src = home / ".config" / "hypr" / "lockscreens" / prof.get("hyprlock_config", "hyprlock-dev.conf")
    hl_dst = home / ".config" / "hypr" / "hyprlock.conf"
    link_file(hl_src, hl_dst)

    # 5. GTK 3 CSS Switch (Symlink)
    gtk_css_src = home / ".config" / "gtk-3.0" / prof.get("gtk_css", "gtk-dev.css")
    gtk_css_dst = home / ".config" / "gtk-3.0" / "gtk.css"
    link_file(gtk_css_src, gtk_css_dst)

    # 6. GTK & Thunar Icons y Tema (GSettings + XFConf + INI)
    gtk_theme = prof.get("gtk_theme", "adw-gtk3-dark")
    icon_theme = prof.get("icon_theme", "Tela-circle-dracula-dark")
    color_scheme = prof.get("color_scheme", "prefer-dark")
    prefer_dark = prof.get("gtk_prefer_dark", "1")

    run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", gtk_theme])
    run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", icon_theme])
    run_quiet(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", color_scheme])
    
    run_quiet(["xfconf-query", "-c", "xsettings", "-p", "/Net/ThemeName", "-s", gtk_theme])
    run_quiet(["xfconf-query", "-c", "xsettings", "-p", "/Net/IconThemeName", "-s", icon_theme])
    update_gtk_settings_ini(gtk_theme, icon_theme, prefer_dark)

    # 7. Hyprland Rounding, Bordes y Opacidad en Caliente (Hyprland Lua eval)
    try:
        import re
        rounding = prof.get("hypr_rounding", 10)
        active_opacity = prof.get("hypr_opacity", "0.90")
        border_size = prof.get("hypr_border_size", 2)
        border_col = prof.get("hypr_border_color", "rgba(00ffccee) rgba(bd93f9ee) 45deg")
        colors_match = re.findall(r"rgba\([^)]+\)", border_col)
        if colors_match:
            lua_colors = "{" + ", ".join([f'"{c}"' for c in colors_match]) + "}"
        else:
            lua_colors = '{"rgba(00ffccee)", "rgba(bd93f9ee)"}'
        lua_code = f"hl.config({{ decoration = {{ rounding = {rounding}, active_opacity = {active_opacity} }}, general = {{ border_size = {border_size}, col = {{ active_border = {{ colors = {lua_colors}, angle = 45 }} }} }} }})"
        run_quiet(["hyprctl", "eval", lua_code])
    except Exception:
        pass

    # 8. Quickshell Bar Config & Switch
    bar_style = prof.get("bar_style", "deck")
    bar_cfg = home / ".config" / "quickshell" / "bar_config.json"
    try:
        with open(bar_cfg, "w", encoding="utf-8") as bf:
            json.dump({"style": bar_style}, bf, indent=2)
    except Exception:
        pass
    if not from_quickshell:
        run_quiet(["quickshell", "ipc", "call", "bar", "set", bar_style])

    # 9. Fondo de pantalla con Pywal + SDDM/Hyprlock
    wp_path = prof.get("wallpaper")
    if wp_path and Path(wp_path).exists():
        wallchange_script = home / ".config" / "hypr" / "scripts" / "wallchange.sh"
        if wallchange_script.exists():
            run_quiet([str(wallchange_script), wp_path])

    # 10. Notificación visual Cyberpunk / Zen
    run_quiet([
        "notify-send",
        "-a", "Setup Master",
        "-i", "preferences-desktop-theme",
        f"Modo {prof.get('name')} Activado",
        "Entorno transformado por completo"
    ])

    return profile_key

def toggle_profile(from_quickshell=False):
    data = load_data()
    curr = data.get("active", "dev")
    order = ["dev", "daily", "pocket"]
    idx = order.index(curr) if curr in order else 0
    nxt = order[(idx + 1) % len(order)]
    return apply_profile(nxt, from_quickshell=from_quickshell)

def set_wallpaper_for_active(wp_path):
    data = load_data()
    curr = data.get("active", "dev")
    if curr in data.get("profiles", {}):
        data["profiles"][curr]["wallpaper"] = str(wp_path)
        save_data(data)

if __name__ == "__main__":
    from_qs = "--from-quickshell" in sys.argv
    clean_argv = [a for a in sys.argv if a != "--from-quickshell"]
    if len(clean_argv) > 1:
        cmd = clean_argv[1].lower()
        if cmd == "switch" and len(clean_argv) > 2:
            print(apply_profile(clean_argv[2], from_quickshell=from_qs))
        elif cmd == "toggle":
            print(toggle_profile(from_quickshell=from_qs))
        elif cmd == "get":
            data = load_data()
            print(data.get("active", "dev"))
        elif cmd == "set-wp" and len(clean_argv) > 2:
            set_wallpaper_for_active(clean_argv[2])
        else:
            print(load_data().get("active", "dev"))
    else:
        print(load_data().get("active", "dev"))
