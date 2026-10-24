#!/usr/bin/env python3
import os
import sys
import json
import subprocess
from pathlib import Path

PROJECTS_DIR = Path.home() / "Proyectos"

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

def list_projects():
    if not PROJECTS_DIR.exists():
        PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
    
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
    
    # Sort by mtime descending (most recently modified first)
    projects.sort(key=lambda x: x["mtime"], reverse=True)
    print(json.dumps({"projects": projects, "base_dir": str(PROJECTS_DIR)}, ensure_ascii=False))

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
        # Open in Zed
        subprocess.Popen(["zeditor", str(target)])
        print(json.dumps({"success": True, "path": str(target)}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

def open_project(path_str: str, editor: str = "zed"):
    p = Path(path_str)
    if not p.exists():
        print(json.dumps({"success": False, "error": "Ruta no encontrada"}))
        return
    
    if editor == "terminal":
        subprocess.Popen(["kitty", "--directory", str(p)])
    elif editor == "files":
        subprocess.Popen(["xdg-open", str(p)])
    else:
        subprocess.Popen(["zeditor", str(p)])
    print(json.dumps({"success": True}))

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        list_projects()
    elif sys.argv[1] == "create" and len(sys.argv) >= 3:
        create_project(sys.argv[2])
    elif sys.argv[1] == "open" and len(sys.argv) >= 3:
        editor = sys.argv[3] if len(sys.argv) >= 4 else "zed"
        open_project(sys.argv[2], editor)
    else:
        print(json.dumps({"error": "Comando no reconocido"}))
