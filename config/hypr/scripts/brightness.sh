#!/usr/bin/env bash
# ==============================================================================
# Script de Control de Brillo y OSD (Basado en Dolphin Hyprland)
# ==============================================================================

iDIR="$HOME/.config/hypr/icons/brightness"

# Obtener brillo actual en porcentaje (sin símbolo %)
get_backlight() {
    brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
}

# Obtener icono correspondiente
get_icon() {
    local current
    current=$(get_backlight)
    local step=$(( ((current + 5) / 10) * 10 ))
    (( step > 100 )) && step=100
    (( step < 0 )) && step=0
    local icon_path="$iDIR/brightness-${step}.png"
    if [[ -f "$icon_path" ]]; then
        echo "$icon_path"
    else
        echo "notification-display-brightness"
    fi
}

# Lanzar notificación OSD unificada en la Dynamic Island (sin duplicar con notify-send/Dunst)
notify_user() {
    local current
    current=$(get_backlight)

    if pgrep -x quickshell >/dev/null 2>&1; then
        quickshell ipc call osd trigger "brightness" "$current" "false" >/dev/null 2>&1 &
        return 0
    fi

    local icon
    icon=$(get_icon)

    notify-send -e \
        -a "Brightness" \
        -h string:x-dunst-stack-tag:brightness_notif \
        -h string:x-canonical-private-synchronous:brightness_notif \
        -h int:value:"$current" \
        -u low \
        -t 1500 \
        -i "$icon" \
        "Brightness: ${current}%"
}

# Aplicar cambio de brillo
change_backlight() {
    brightnessctl set "$1" -n >/dev/null 2>&1
    notify_user
}

# Procesar argumentos
case "$1" in
    up|--inc)
        change_backlight "+5%"
        ;;
    down|--dec)
        change_backlight "5%-"
        ;;
    --get)
        get_backlight
        ;;
    --get-icon)
        get_icon
        ;;
    *)
        get_backlight
        ;;
esac
