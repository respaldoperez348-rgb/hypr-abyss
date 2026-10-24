#!/usr/bin/env python3
"""
clipboard_manager.py - Gestor de Portapapeles para Quickshell
Maneja lista, copia, borrado y limpieza con cliphist y wl-clipboard.
"""

import sys
import subprocess
import json

def get_item_type(content: str) -> tuple[str, str]:
    c = content.strip()
    if c.startswith("[[ binary data") or c.endswith((".png", ".jpg", ".jpeg", ".webp")):
        return ("image", "󰋩")
    if c.startswith(("http://", "https://", "ftp://", "www.")):
        return ("url", "󰖟")
    if any(k in c for k in ["def ", "class ", "import ", "const ", "let ", "function", "var ", "{", "}", "=>", ";", "public ", "private ", "<div", "<template"]):
        return ("code", "")
    if c.startswith(("/", "~/", "./", "../")) and len(c) < 120 and " " not in c:
        return ("path", "󰉋")
    return ("text", "󰦨")

def list_items():
    try:
        proc = subprocess.run(["cliphist", "list"], capture_output=True, text=True, check=True)
        lines = proc.stdout.splitlines()
    except Exception as e:
        print(json.dumps({"items": [], "error": str(e)}))
        return

    items = []
    # Límite de 60 elementos para máxima fluidez en Quickshell
    for line in lines[:60]:
        if "\t" not in line:
            continue
        parts = line.split("\t", 1)
        item_id = parts[0].strip()
        raw_text = parts[1]
        
        # Tipo e icono
        item_type, item_icon = get_item_type(raw_text)
        
        # Preview recortada limpia de saltos de línea
        preview = " ".join(raw_text.split())
        if len(preview) > 120:
            preview = preview[:117] + "..."

        items.append({
            "id": item_id,
            "raw": line,
            "preview": preview,
            "type": item_type,
            "icon": item_icon
        })

    print(json.dumps({"items": items}))

def copy_item(raw_line: str):
    if not raw_line:
        return
    try:
        # Decodifica de cliphist y lo inyecta a wl-copy
        decode_proc = subprocess.Popen(["cliphist", "decode"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        out, _ = decode_proc.communicate(input=raw_line.encode("utf-8"))
        if out:
            wl_proc = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
            wl_proc.communicate(input=out)
            print("OK")
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)

def delete_item(raw_line: str):
    if not raw_line:
        return
    try:
        del_proc = subprocess.Popen(["cliphist", "delete"], stdin=subprocess.PIPE)
        del_proc.communicate(input=raw_line.encode("utf-8"))
        print("DELETED")
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)

def wipe_history():
    try:
        subprocess.run(["cliphist", "wipe"], check=True)
        subprocess.run(["wl-copy", "--clear"], check=False)
        print("WIPED")
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        list_items()
    elif sys.argv[1] == "copy" and len(sys.argv) >= 3:
        copy_item(sys.argv[2])
    elif sys.argv[1] == "delete" and len(sys.argv) >= 3:
        delete_item(sys.argv[2])
    elif sys.argv[1] == "wipe":
        wipe_history()
    else:
        print(f"Uso: {sys.argv[0]} [list | copy <raw> | delete <raw> | wipe]")

if __name__ == "__main__":
    main()
