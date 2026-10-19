#!/usr/bin/env bash
# ==============================================================================
# Script de Control de Volumen y OSD (Basado en Dolphin Hyprland)
# ==============================================================================

iDIR="$HOME/.config/hypr/icons/vol"

# Sonido de feedback de volumen
play_sound() {
    canberra-gtk-play -i audio-volume-change -d "changeVolume" 2>/dev/null &
}

# Obtener si está silenciado
is_muted() {
    if command -v pamixer >/dev/null 2>&1; then
        pamixer --get-mute
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q "\[MUTED\]" && echo "true" || echo "false"
    elif command -v pactl >/dev/null 2>&1; then
        pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q "yes" && echo "true" || echo "false"
    else
        echo "false"
    fi
}

# Obtener porcentaje de volumen numérico (ej. 45)
get_volume_num() {
    if command -v pamixer >/dev/null 2>&1; then
        pamixer --get-volume 2>/dev/null || echo 0
    elif command -v wpctl >/dev/null 2>&1; then
        val=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
        awk "BEGIN {printf \"%.0f\", ${val:-0} * 100}" 2>/dev/null || echo 0
    elif command -v pactl >/dev/null 2>&1; then
        pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -n1 | awk '{print $5}' | tr -d '%' 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Obtener texto de volumen
get_volume() {
    if [[ "$(is_muted)" == "true" ]]; then
        echo "Muted"
    else
        echo "$(get_volume_num)%"
    fi
}

# Obtener icono correspondiente
get_icon() {
    if [[ "$(is_muted)" == "true" ]]; then
        echo "$iDIR/muted-speaker.svg"
    else
        local vol
        vol=$(get_volume_num)
        # Redondear al múltiplo de 5 más cercano para coincidir con los iconos vol-XX.svg
        local rounded=$(( ((vol + 2) / 5) * 5 ))
        (( rounded > 100 )) && rounded=100
        (( rounded < 0 )) && rounded=0
        local icon_path="$iDIR/vol-${rounded}.svg"
        if [[ -f "$icon_path" ]]; then
            echo "$icon_path"
        else
            echo "audio-volume-high"
        fi
    fi
}

# Lanzar notificación OSD unificada en la Dynamic Island (sin duplicar con notify-send/Dunst)
notify_user() {
    local muted_state
    muted_state=$(is_muted)
    local vol_val
    vol_val=$(get_volume_num)

    if pgrep -x quickshell >/dev/null 2>&1; then
        quickshell ipc call osd trigger "volume" "$vol_val" "$muted_state" >/dev/null 2>&1 &
        return 0
    fi

    local icon
    icon=$(get_icon)
    if [[ "$muted_state" == "true" ]]; then
        notify-send -e \
            -a "Volume" \
            -h string:x-dunst-stack-tag:volume_notif \
            -h string:x-canonical-private-synchronous:volume_notif \
            -h int:value:0 \
            -u low \
            -t 1500 \
            -i "$icon" \
            "Volume: Muted"
    else
        notify-send -e \
            -a "Volume" \
            -h string:x-dunst-stack-tag:volume_notif \
            -h string:x-canonical-private-synchronous:volume_notif \
            -h int:value:"$vol_val" \
            -u low \
            -t 1500 \
            -i "$icon" \
            "Volume: ${vol_val}%"
    fi
}

# Subir volumen (5%)
inc_volume() {
    if command -v pamixer >/dev/null 2>&1; then
        pamixer -i 5 --allow-boost --set-limit 150
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
    elif command -v pactl >/dev/null 2>&1; then
        pactl set-sink-volume @DEFAULT_SINK@ +5%
    fi
    play_sound
    notify_user
}

# Bajar volumen (5%)
dec_volume() {
    if command -v pamixer >/dev/null 2>&1; then
        pamixer -d 5 --allow-boost --set-limit 150
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    elif command -v pactl >/dev/null 2>&1; then
        pactl set-sink-volume @DEFAULT_SINK@ -5%
    fi
    play_sound
    notify_user
}

# Alternar Silencio (Mute)
toggle_mute() {
    if command -v pamixer >/dev/null 2>&1; then
        pamixer -t
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    elif command -v pactl >/dev/null 2>&1; then
        pactl set-sink-mute @DEFAULT_SINK@ toggle
    fi
    play_sound
    notify_user
}

# Alternar Silencio Micrófono
toggle_mic() {
    local mic_icon="$iDIR/unmuted-mic.svg"
    local mic_status="Unmuted"
    if command -v pamixer >/dev/null 2>&1; then
        pamixer --default-source -t
        if [[ "$(pamixer --default-source --get-mute)" == "true" ]]; then
            mic_icon="$iDIR/muted-mic.svg"
            mic_status="Muted"
        fi
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q "\[MUTED\]"; then
            mic_icon="$iDIR/muted-mic.svg"
            mic_status="Muted"
        fi
    fi
    notify-send -e \
        -a "Volume" \
        -h string:x-dunst-stack-tag:mic_notif \
        -h string:x-canonical-private-synchronous:mic_notif \
        -u low \
        -t 1500 \
        -i "$mic_icon" \
        "Microphone: $mic_status"
}

# Ejecutar según argumento
case "$1" in
    --get)        get_volume ;;
    --inc)        inc_volume ;;
    --dec)        dec_volume ;;
    --toggle)     toggle_mute ;;
    --toggle-mic) toggle_mic ;;
    --get-icon)   get_icon ;;
    *)            get_volume ;;
esac
