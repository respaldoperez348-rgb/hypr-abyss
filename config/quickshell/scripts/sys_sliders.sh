#!/usr/bin/env bash
# ==============================================================================
# Control y estado de Volumen (PipeWire/wpctl) y Brillo (brightnessctl/sysfs)
# Uso:
#   sys_sliders.sh status
#   sys_sliders.sh set_volume <0-150>
#   sys_sliders.sh toggle_mute
#   sys_sliders.sh set_brightness <5-100>
# ==============================================================================

ACTION="${1:-status}"
VALUE="$2"

case "$ACTION" in
    set_volume)
        if [[ -n "$VALUE" ]]; then
            wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null
            wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${VALUE}%" 2>/dev/null
        fi
        ;;
    toggle_mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null
        ;;
    set_brightness)
        if [[ -n "$VALUE" ]]; then
            (( VALUE < 5 )) && VALUE=5
            (( VALUE > 100 )) && VALUE=100
            brightnessctl set "${VALUE}%" -q 2>/dev/null
        fi
        ;;
esac

# Leer Volumen actual
raw_vol=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
muted=false
if [[ "$raw_vol" == *"[MUTED]"* ]]; then
    muted=true
fi
vol=$(echo "$raw_vol" | awk '{print int($2 * 100 + 0.5)}')
vol=${vol:-50}

# Leer Brillo actual (vía sysfs ultrarrápido o brightnessctl)
bri=80
bl_dir=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
if [[ -n "$bl_dir" && -f "$bl_dir/brightness" && -f "$bl_dir/max_brightness" ]]; then
    read -r cur_b < "$bl_dir/brightness"
    read -r max_b < "$bl_dir/max_brightness"
    if (( max_b > 0 )); then
        bri=$(( (cur_b * 100 + max_b / 2) / max_b ))
    fi
else
    bri=$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/, "", $4); print int($4)}')
    bri=${bri:-80}
fi

printf '{"volume": %d, "muted": %s, "brightness": %d}\n' "$vol" "$muted" "$bri"
