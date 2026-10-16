#!/usr/bin/env bash
# ==============================================================================
# Hacker Stats Provider for Quickshell Dynamic Island
# Extrae CPU, Batería, WiFi, Bluetooth y GPU con latencia < 3ms
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
if grep -qE "wlp|wlan" /proc/net/wireless 2>/dev/null; then
    raw_sig=$(awk '/wlp|wlan/ {gsub(/\./, ""); print int($3)}' /proc/net/wireless 2>/dev/null)
    wifi_signal=$(( raw_sig > 100 ? 100 : raw_sig ))
    
    wifi_ssid=$(iwgetid -r 2>/dev/null)
    if [[ -z "$wifi_ssid" ]]; then
        wifi_ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^(yes|sí|true):/ {print $2; exit}')
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

# 5. Intel GPU (Calculado vía RC6 Residency Engine - card1)
gpu_pct=0
GPU_CACHE="/dev/shm/qs_gpu_cache"
RC6_FILE="/sys/class/drm/card1/device/drm/card1/gt/gt0/rc6_residency_ms"

if [[ -f "$RC6_FILE" ]]; then
    # Obtener tiempo de residencia e idilio actual en milisegundos de alta precisión
    read -r current_rc6 < "$RC6_FILE"
    current_time=$(date +%s%3N) # Epoch en milisegundos

    if [[ -f "$GPU_CACHE" ]]; then
        read -r prev_time prev_rc6 < "$GPU_CACHE"
        
        time_diff=$(( current_time - prev_time ))
        rc6_diff=$(( current_rc6 - prev_rc6 ))
        
        if (( time_diff > 0 )); then
            # El uso de la GPU es el tiempo total transcurrido MENOS el tiempo que pasó inactiva (RC6)
            idle_pct=$(( (100 * rc6_diff) / time_diff ))
            gpu_pct=$(( 100 - idle_pct ))
            
            # Limitar cotas por desbordamiento de hilos
            (( gpu_pct < 0 )) && gpu_pct=0
            (( gpu_pct > 100 )) && gpu_pct=100
        fi
    fi
    echo "$current_time $current_rc6" > "$GPU_CACHE"
fi

# Salida JSON limpia consolidada
printf '{"cpu": %d, "bat": %d, "bat_status": "%s", "bat_time": "%s", "bat_detail": "%s", "wifi_ssid": "%s", "wifi_signal": %d, "bt": %s, "bt_device": "%s", "gpu": %d}\n' \
  "$cpu_pct" \
  "$bat_pct" \
  "$bat_status" \
  "$bat_time" \
  "$bat_detail" \
  "$wifi_ssid" \
  "$wifi_signal" \
  "$bt_powered" \
  "$bt_device" \
  "$gpu_pct"
