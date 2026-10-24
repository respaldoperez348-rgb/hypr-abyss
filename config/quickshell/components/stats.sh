#!/usr/bin/env bash
# ==============================================================================
# Hacker Stats Provider for Quickshell Dynamic Island
# Extrae CPU, Batería, WiFi y Bluetooth con latencia < 3ms
# ==============================================================================

# 1. CPU
CACHE_FILE="/dev/shm/qs_cpu_cache"
read -r _ u n s i w x y z _ < /proc/stat
total=$((u + n + s + i + w + x + y + z))
idle=$((i + w))

cpu_pct=0
if [[ -f "$CACHE_FILE" ]]; then
    read -r prev_total prev_idle < "$CACHE_FILE"
    diff_total=$((total - prev_total))
    diff_idle=$((idle - prev_idle))
    if (( diff_total > 0 )); then
        cpu_pct=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
        (( cpu_pct < 0 )) && cpu_pct=0
        (( cpu_pct > 100 )) && cpu_pct=100
    fi
fi
echo "$total $idle" > "$CACHE_FILE"

# 1.5. RAM y CPU Temp
ram_pct=0
ram_used="0G"
ram_total="0G"
if [[ -f /proc/meminfo ]]; then
    read -r ram_pct ram_used ram_total < <(awk '
        /MemTotal/ { t=$2 }
        /MemAvailable/ { a=$2 }
        END {
            if (t > 0) {
                pct = int((t - a) * 100 / t);
                u_gb = sprintf("%.1f", (t - a) / 1024 / 1024);
                t_gb = sprintf("%.1f", t / 1024 / 1024);
                printf "%d %sG %sG\n", pct, u_gb, t_gb;
            } else {
                print "0 0G 0G";
            }
        }' /proc/meminfo 2>/dev/null)
fi
ram_pct=${ram_pct:-0}

cpu_temp=0
for tz in /sys/class/thermal/thermal_zone*/temp; do
    if [[ -f "$tz" ]]; then
        t=$(< "$tz")
        t=$(( t / 1000 ))
        if (( t >= 20 && t <= 105 && t > cpu_temp )); then
            cpu_temp=$t
        fi
    fi
done

# 2. Batería
bat_path=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
bat_pct=100
bat_status="Full"
bat_time=""
bat_detail="Completa"

if [[ -n "$bat_path" ]]; then
    [[ -f "$bat_path/capacity" ]] && read -r bat_pct < "$bat_path/capacity"
    [[ -f "$bat_path/status" ]] && read -r bat_status < "$bat_path/status"
    bat_pct=${bat_pct:-100}
    bat_status=${bat_status:-"Full"}

    energy_now=0
    power_now=0
    energy_full=0
    [[ -f "$bat_path/energy_now" ]] && read -r energy_now < "$bat_path/energy_now"
    [[ -f "$bat_path/power_now" ]] && read -r power_now < "$bat_path/power_now"
    [[ -f "$bat_path/energy_full" ]] && read -r energy_full < "$bat_path/energy_full"

    if (( energy_now == 0 )) && [[ -f "$bat_path/charge_now" ]]; then
        read -r energy_now < "$bat_path/charge_now" 2>/dev/null
        read -r power_now < "$bat_path/current_now" 2>/dev/null
        read -r energy_full < "$bat_path/charge_full" 2>/dev/null
    fi

    energy_now=${energy_now:-0}
    power_now=${power_now:-0}
    energy_full=${energy_full:-0}

    if [[ "$bat_status" == "Discharging" ]] && (( power_now > 1000 && energy_now > 0 )); then
        total_mins=$(( (energy_now * 60) / power_now ))
        h=$(( total_mins / 60 ))
        m=$(( total_mins % 60 ))
        if (( h > 0 )); then
            bat_time="${h}h ${m}m"
        else
            bat_time="${m}m"
        fi
        bat_detail="${bat_time} restantes"
    elif [[ "$bat_status" == "Charging" ]] && (( power_now > 1000 && energy_full > energy_now )); then
        rem_energy=$(( energy_full - energy_now ))
        total_mins=$(( (rem_energy * 60) / power_now ))
        h=$(( total_mins / 60 ))
        m=$(( total_mins % 60 ))
        if (( h > 0 )); then
            bat_time="${h}h ${m}m"
        else
            bat_time="${m}m"
        fi
        bat_detail="Cargando (${bat_time})"
    elif [[ "$bat_status" == "Charging" ]]; then
        bat_detail="Cargando"
    elif [[ "$bat_status" == "Discharging" ]]; then
        # Fallback a upower si power_now no estuviera disponible
        up_time=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | awk -F: '/time to empty/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')
        if [[ -n "$up_time" ]]; then
            bat_detail="${up_time} restantes"
        else
            bat_detail="Descargando"
        fi
    fi
fi

# 3. WiFi (Lectura directa de /proc/net/wireless y /sys/class/net)
wifi_signal=0
wifi_ssid="Disconnected"
if grep -q "wlp" /proc/net/wireless 2>/dev/null; then
    raw_sig=$(awk '/wlp/ {gsub(/\./, ""); print int($3)}' /proc/net/wireless 2>/dev/null)
    wifi_signal=$(( raw_sig > 100 ? 100 : raw_sig ))
    wifi_ssid=$(iwgetid -r 2>/dev/null)
    if [[ -z "$wifi_ssid" ]]; then
        wifi_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^yes:/ || /^sí:/ {print $2; exit}')
    fi
    wifi_ssid=${wifi_ssid:-"Connected"}
fi

# 4. Bluetooth (Rápido vía bluetoothctl)
bt_powered=false
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    bt_powered=true
fi
bt_device=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)
bt_device=${bt_device:-""}

# 5. Volumen y Brillo (para OSD reactivo en Dynamic Island)
raw_vol=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
vol_muted=false
[[ "$raw_vol" == *"[MUTED]"* ]] && vol_muted=true
vol_pct=$(echo "$raw_vol" | awk '{print int($2 * 100 + 0.5)}')
vol_pct=${vol_pct:-50}

bri_pct=80
bl_dir=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
if [[ -n "$bl_dir" && -f "$bl_dir/brightness" && -f "$bl_dir/max_brightness" ]]; then
    read -r cur_b < "$bl_dir/brightness"
    read -r max_b < "$bl_dir/max_brightness"
    (( max_b > 0 )) && bri_pct=$(( (cur_b * 100 + max_b / 2) / max_b ))
fi

# 6. Ventana activa (Hyprland)
active_class=$(hyprctl activewindow -j 2>/dev/null | awk -F'"' '/"class":/ {print $4; exit}')
active_class=${active_class:-"Desktop"}

# Salida JSON limpia
printf '{"cpu": %d, "cpu_temp": %d, "ram": %d, "ram_used": "%s", "ram_total": "%s", "bat": %d, "bat_status": "%s", "bat_time": "%s", "bat_detail": "%s", "wifi_ssid": "%s", "wifi_signal": %d, "bt": %s, "bt_device": "%s", "volume": %d, "vol_muted": %s, "brightness": %d, "active_app": "%s"}\n' \
  "$cpu_pct" "$cpu_temp" "$ram_pct" "$ram_used" "$ram_total" "$bat_pct" "$bat_status" "$bat_time" "$bat_detail" "$wifi_ssid" "$wifi_signal" "$bt_powered" "$bt_device" "$vol_pct" "$vol_muted" "$bri_pct" "$active_class"
