#!/usr/bin/env bash
# ==============================================================================
# Dynamic Wallpaper & System-Wide Cyberpunk Theme Synchronizer
# ==============================================================================

export PATH="$HOME/.local/bin:$PATH"

WALL_DIR="$HOME/Pictures/Wallpapers"
THUMB_DIR="$HOME/.cache/wallpaper_thumbs"
mkdir -p "$WALL_DIR" "$THUMB_DIR"

# 1. Seleccionar imagen / video (por argumento o aleatoria)
if [[ -n "$1" && -f "$1" ]]; then
    WALLPAPER="$1"
else
    WALLPAPER=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" \) | shuf -n 1)
fi

# Fallback si no hay archivos
if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    curl -sL https://raw.githubusercontent.com/cybrcore/cybrpapers/main/wallpapers/akihabara/akihabara-1920x1080.jpg -o "$WALL_DIR/cyberpunk-akihabara.jpg"
    WALLPAPER="$WALL_DIR/cyberpunk-akihabara.jpg"
fi

# 2. Iniciar el demonio de wallpaper si no está activo
if ! pgrep -x awww-daemon >/dev/null && ! pgrep -x swww-daemon >/dev/null; then
    if command -v swww-daemon >/dev/null 2>&1; then
        swww-daemon &
    elif command -v awww-daemon >/dev/null 2>&1; then
        awww-daemon &
    fi
    sleep 0.6
fi

# 3. Comprobar si es video o imagen
ext="${WALLPAPER##*.}"
ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

wal_target="$WALLPAPER"
wp_target="$WALLPAPER"

if [[ "$ext" =~ ^(mp4|webm|mkv)$ ]]; then
    h=$(echo -n "$WALLPAPER" | md5sum | awk '{print $1}')
    thumb="$THUMB_DIR/${h}.jpg"
    if [[ ! -f "$thumb" ]]; then
        ffmpeg -y -ss 00:00:01 -i "$WALLPAPER" -vframes 1 -q:v 2 "$thumb" -v quiet
    fi
    wal_target="$thumb"
    wp_target="$thumb"
fi

# 4. Aplicar fondo con transición animada fluida
WP_CMD=""
if command -v swww >/dev/null 2>&1; then
    WP_CMD="swww"
elif command -v awww >/dev/null 2>&1; then
    WP_CMD="awww"
fi

if [[ -n "$WP_CMD" ]]; then
    $WP_CMD img "$wp_target" --transition-type wipe --transition-angle 30 --transition-step 90 --transition-fps 60 2>/dev/null || \
    $WP_CMD img "$wp_target" 2>/dev/null
fi

# 5. Extraer paleta de 16 colores con Pywal de forma rápida
wal -i "$wal_target" -n -q -s -t -e 2>/dev/null || true
mkdir -p "$HOME/.config/hypr/.cache"
ln -sf "$wal_target" "$HOME/.config/hypr/.cache/current_wallpaper.png"

# Generar colores dinámicos GTK 3 (Thunar) a partir de la paleta del wallpaper
if [[ -f "$HOME/.cache/wal/colors.json" ]]; then
    python3 -c '
import json, os
try:
    with open(os.path.expanduser("~/.cache/wal/colors.json")) as f:
        data = json.load(f)
    bg = data.get("special", {}).get("background", "#0d1117")
    fg = data.get("special", {}).get("foreground", "#f0f6fc")
    accent = data.get("colors", {}).get("color4", "#00ffcc")
    accent2 = data.get("colors", {}).get("color6", "#bd93f9")
    sidebar = data.get("colors", {}).get("color0", "#090d13")
    card = data.get("colors", {}).get("color8", "#161b22")
    
    css = f"""/* Generated dynamically from active wallpaper pywal palette */
@define-color wal_bg {bg};
@define-color wal_fg {fg};
@define-color wal_accent {accent};
@define-color wal_accent2 {accent2};
@define-color wal_sidebar_bg {sidebar};
@define-color wal_card_bg {card};
"""
    out_path = os.path.expanduser("~/.config/gtk-3.0/colors-wal.css")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as out:
        out.write(css)
except Exception:
    pass
'
    # Recargar GTK notificando a las ventanas activas
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true
    xfconf-query -c xsettings -p /Net/ThemeName -s "adw-gtk3-dark" 2>/dev/null || true
fi

# Sincronizar banner vertical de Rofi con el wallpaper actual
mkdir -p "$HOME/.config/rofi/assets"
rm -f "$HOME/.config/rofi/assets/current_wallpaper.jpg"
real_img="$(realpath -q "$wal_target" 2>/dev/null || echo "$wal_target")"
magick "$real_img" -resize "600x900^" -gravity center -extent 600x900 "$HOME/.config/rofi/assets/current_wallpaper.jpg" 2>/dev/null || cp "$real_img" "$HOME/.config/rofi/assets/current_wallpaper.jpg" 2>/dev/null || true

# 6. Recargar colores en caliente en Kitty a través de los sockets activos
if pgrep -x kitty >/dev/null; then
    for sock in $(ss -xl 2>/dev/null | grep -o '@mykitty-[0-9]*'); do
        timeout 0.3s kitty @ --to "unix:$sock" set-colors --all "$HOME/.cache/wal/colors-kitty.conf" 2>/dev/null || true
    done
fi

# 7. Sincronizar Hyprland y Dunst con la paleta de Pywal en tiempo real (Lua eval)
if [[ -f "$HOME/.cache/wal/colors.json" ]]; then
    c4=$(python3 -c "import json; data=json.load(open('$HOME/.cache/wal/colors.json')); print(data.get('colors',{}).get('color4','#00ffcc').lstrip('#'))" 2>/dev/null || echo "00ffcc")
    c5=$(python3 -c "import json; data=json.load(open('$HOME/.cache/wal/colors.json')); print(data.get('colors',{}).get('color5','#bd93f9').lstrip('#'))" 2>/dev/null || echo "bd93f9")
    hyprctl eval "hl.config({ general = { col = { active_border = { colors = { 'rgba(${c4}ee)', 'rgba(${c5}ee)' }, angle = 45 } } } })" 2>/dev/null || true
fi
"$HOME/.config/dunst/update_dunst_theme.sh" 2>/dev/null || true

# 8. Notificación visual si notify-send está disponible
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Cyberpunk Theme" -i "$wal_target" "Theme Synchronized" "$(basename "$WALLPAPER")" 2>/dev/null || true
fi
