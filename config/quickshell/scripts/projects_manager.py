#!/usr/bin/env python3
import os
import sys
import json
import subprocess
from pathlib import Path

PROJECTS_DIR = Path.home() / "Proyectos"
CONFIGS_DIR = Path.home() / ".config"
DOTFILES_DIR = Path.home() / "dotfiles"

CURATED_CONFIGS = {
    "hypr": ("Hyprland", "Window Manager & Keybinds", ""),
    "quickshell": ("Quickshell", "Dynamic Island & Widgets QML", "󱐋"),
    "kitty": ("Kitty", "Terminal GPU Emulator", ""),
    "cava": ("CAVA", "Audio Visualizer PipeWire", "󰝚"),
    "zed": ("Zed Editor", "Editor Configs & Keybinds", "󰨞"),
    "rofi": ("Rofi", "App Launcher Menus", "󰀻"),
    "wal": ("Pywal", "Paletas de Colores Dinámicas", "󰏘"),
    "fastfetch": ("Fastfetch", "Información del Sistema", "󰘚"),
    "fish": ("Fish Shell", "Shell Config & Funciones", "󰈺"),
    "dunst": ("Dunst", "Servidor de Notificaciones", "󰂚"),
    "mpv": ("MPV", "Reproductor Multimedia", "󰎆"),
    "htop": ("Htop", "Monitor de Procesos", "󰓅"),
    "gtk-3.0": ("GTK 3", "Tema GTK y Bookmarks", "󰉋"),
    "xfce4": ("XFCE / Thunar", "Gestor de Archivos", "󰉋"),
}

IGNORE_CONFIG_DIRS = {
    "procps", "dconf", "systemd", "pulse", "Thunar", "BraveSoftware",
    "mozilla", "google-chrome", "zoom", "onlyoffice"
}

def get_project_type_and_icon(path: Path):
    if (path / "android").exists() or (path / "capacitor.config.json").exists() or (path / "capacitor.config.ts").exists():
        return "Mobile App", "󰀲"
    if (path / "package.json").exists():
        return "Node / Web", "󰎙"
    if (path / "requirements.txt").exists() or (path / "pyproject.toml").exists() or any(path.glob("*.py")):
        return "Python", "󰌠"
    if (path / "Cargo.toml").exists():
        return "Rust", "󱘗"
    if (path / "shell.qml").exists():
        return "Quickshell", "󱐋"
    if (path / ".git").exists():
        return "Git Repo", "󰊢"
    return "Project", "󰉋"

def get_git_info(path: Path):
    if not (path / ".git").exists():
        return "", False
    try:
        branch = subprocess.check_output(
            ["git", "-C", str(path), "rev-parse", "--abbrev-ref", "HEAD"],
            stderr=subprocess.DEVNULL, text=True, timeout=1
        ).strip()
        status = subprocess.check_output(
            ["git", "-C", str(path), "status", "--porcelain"],
            stderr=subprocess.DEVNULL, text=True, timeout=1
        ).strip()
        return branch, bool(status)
    except Exception:
        return "", False

def list_data():
    if not PROJECTS_DIR.exists():
        PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
    
    # 1. Proyectos en ~/Proyectos
    projects = []
    for item in sorted(PROJECTS_DIR.iterdir()):
        if item.is_dir() and not item.name.startswith("."):
            ptype, icon = get_project_type_and_icon(item)
            branch, dirty = get_git_info(item)
            try:
                mtime = item.stat().st_mtime
            except Exception:
                mtime = 0
            projects.append({
                "name": item.name,
                "path": str(item),
                "type": ptype,
                "icon": icon,
                "branch": branch,
                "dirty": dirty,
                "mtime": mtime
            })
    
    projects.sort(key=lambda x: x["mtime"], reverse=True)

    # 2. Configuraciones (~/.config y ~/dotfiles)
    configs = []
    
    # 2.1 Raíz ~/.config
    configs.append({
        "name": ".config (Todo)",
        "path": str(CONFIGS_DIR),
        "type": "Config Root",
        "desc": "Directorio raíz ~/.config",
        "icon": "󰒓",
        "branch": "",
        "dirty": False
    })

    # 2.2 Dotfiles Git Repo
    if DOTFILES_DIR.exists():
        dot_branch, dot_dirty = get_git_info(DOTFILES_DIR)
        configs.append({
            "name": "dotfiles",
            "path": str(DOTFILES_DIR),
            "type": "Git Repo",
            "desc": "Repositorio personal de dotfiles",
            "icon": "",
            "branch": dot_branch or "main",
            "dirty": dot_dirty
        })

    # 2.3 Paquetes curados de ~/.config
    seen_folders = set()
    for key, (display_name, desc, icon) in CURATED_CONFIGS.items():
        p = CONFIGS_DIR / key
        if p.exists() and p.is_dir():
            seen_folders.add(key)
            branch, dirty = get_git_info(p)
            configs.append({
                "name": display_name,
                "path": str(p),
                "type": "Config",
                "desc": desc,
                "icon": icon,
                "branch": branch,
                "dirty": dirty
            })

    # 2.4 Resto de carpetas de ~/.config no curadas
    if CONFIGS_DIR.exists():
        for item in sorted(CONFIGS_DIR.iterdir()):
            if item.is_dir() and not item.name.startswith(".") and item.name not in seen_folders and item.name not in IGNORE_CONFIG_DIRS:
                configs.append({
                    "name": item.name,
                    "path": str(item),
                    "type": "Config",
                    "desc": f"Configuración de {item.name}",
                    "icon": "󰉋",
                    "branch": "",
                    "dirty": False
                })

    print(json.dumps({
        "projects": projects,
        "configs": configs,
        "base_dir": str(PROJECTS_DIR),
        "configs_dir": str(CONFIGS_DIR)
    }, ensure_ascii=False))

def create_project(name: str):
    clean_name = name.strip()
    if not clean_name:
        print(json.dumps({"success": False, "error": "Nombre vacío"}))
        return
    
    target = PROJECTS_DIR / clean_name
    if target.exists():
        print(json.dumps({"success": False, "error": "El proyecto ya existe"}))
        return
    
    try:
        target.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "-C", str(target), "init"], capture_output=True, text=True)
        subprocess.Popen(["antigravity-ide", str(target)])
        print(json.dumps({"success": True, "path": str(target)}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

def open_project(path_str: str, editor: str = "antigravity"):
    p = Path(path_str)
    if not p.exists():
        print(json.dumps({"success": False, "error": "Ruta no encontrada"}))
        return
    
    if editor == "terminal":
        subprocess.Popen(["kitty", "--directory", str(p)])
    elif editor == "files":
        subprocess.Popen(["xdg-open", str(p)])
    elif editor == "zed":
        subprocess.Popen(["zeditor", str(p)])
    else:
        subprocess.Popen(["antigravity-ide", str(p)])
    print(json.dumps({"success": True}))

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        list_data()
    elif sys.argv[1] == "create" and len(sys.argv) >= 3:
        create_project(sys.argv[2])
    elif sys.argv[1] == "open" and len(sys.argv) >= 3:
        editor = sys.argv[3] if len(sys.argv) >= 4 else "antigravity"
        open_project(sys.argv[2], editor)
    else:
        print(json.dumps({"error": "Comando no reconocido"}))
