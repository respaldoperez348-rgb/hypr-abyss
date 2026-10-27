# 🌌 Hypr-Abyss (Cyberpunk / Frosted Glass Setup)

<div align="center">

[![Hyprland](https://img.shields.io/badge/Hyprland-0.56+-00ffff?style=for-the-badge&logo=archlinux)](https://hyprland.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-QML-ff007f?style=for-the-badge&logo=qt)](https://quickshell.outfoxxed.me)
[![Pywal](https://img.shields.io/badge/Pywal-Dynamic_Colors-bd93f9?style=for-the-badge)](https://github.com/dylanaraps/pywal)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)]()

**A state-of-the-art, ultra-lightweight Cyberpunk / Frosted Glass desktop setup for Hyprland and Quickshell.**  
Designed for minimal CPU usage (idles at 1-3% CPU), dynamic Pywal theme synchronization, draggable desktop widgets, and standalone YouTube music streaming.

[English](#-english) | [Español](#-español)

</div>





---

## 🇺🇸 English

### ✨ Key Features

1. **🏝️ Dynamic Island Bar**
   - Floating frosted-glass capsule centered at the top of the screen.
   - **Pacman / Cyberpunk Workspaces**: Icons turn into `ᗧ` when windows are active, with glowing neon indicators.
   - **Hardware Telemetry**: Real-time CPU, WiFi signal, Bluetooth connection, and Battery status.
   - **Expanded MPRIS Media Island**: When music plays, the island automatically expands to reveal an animated 4-bar visualizer, title/artist marquee, volume bar, and playback controls (`⏮`, `⏯`, `⏭`).
   - Automatically hides when entering full-screen mode (`Super + F`).

2. **⏰ Retro Draggable Desktop Clock Widget (`Super + B`)**
   - Inspired by vintage Material You aesthetics with deep emerald green `#1D3D37`, peach digits `#F9B49E`, and pastel accents.
   - **Freely Draggable**: Drag it anywhere across your monitor with the mouse.
   - **Persistent Config**: Coordinates, scale, language, and theme are saved automatically to `clock_config.json`.
   - **Interactive Menu**: Click the gear icon to toggle 12h/24h format, language (English / Spanish), themes (Retro, Pywal, Cyberpunk, Cream), scale slider, and position lock.

3. **🎵 Aura Music Player (`Super + Y`)**
   - High-performance, lightweight floating music player powered by `mpv`, `yt-dlp`, and `socat`.
   - **Instant Search & Daily Mix**: Type any song or artist, and enjoy automatic YouTube Mix / Radio recommendations.
   - **Favorites Playlist**: Heart songs to save them to your personal favorites collection (`favorites.json`).
   - **Draggable & Resizable Window**: Drag the header to position the player anywhere.
   - **Seamless Scrubbing & Volume**: Smooth progress bar with elapsed/total time and volume slider.
   - **One-Key Termination (`Super + R`)**: Closes the player and cleanly stops all background audio.

4. **🎛️ Control Center & Quick Settings (`Super + N` / Click Clock)**
   - Smooth right-side sliding panel.
   - **WiFi Scanner**: View available networks, signal strength, and connect with 1-click.
   - **Bluetooth Manager**: Scan, pair, connect, and disconnect devices.
   - **System Sliders**: Interactive audio volume and display brightness controls with OSD feedback.
   - **Quick Actions**: Screenshots (region/fullscreen with shutter sound), Screen Recorder (`wf-recorder` with mixed audio), Keep Awake (caffeine sleep inhibitor), and Do Not Disturb (DND).

5. **⚡ Power & Session Menu (`Super + P`)**
   - Cyberpunk frosted-glass modal with full keyboard navigation (`1-5`, `Esc`, `L`, `E`, `R`, `P`, `S`).
   - Cross-distro compatible shutdown and reboot (`systemctl` + `loginctl` fallback).
   - Confirmation dialogs to prevent accidental shutdowns.

6. **🖼️ Live Wallpaper Selector (`Super + V` & `Super + W`)**
   - **Super + V**: Bottom sliding drawer with visual thumbnail cards of all wallpapers in `~/Pictures/Wallpapers`.
   - **Super + W**: Cycles to a random wallpaper with smooth transition animations.
   - Automatic Pywal color extraction that immediately updates Kitty, Dunst, Quickshell, and Hyprland without restarting.

---

### ⌨️ Keybindings Cheat Sheet

| Keybinding | Action | Description |
|---|---|---|
| `Super + Y` | **Aura Music Player** | Open/close floating YouTube music player & mix |
| `Super + R` | **Stop Music & Close** | Kill audio process and close music player |
| `Super + B` | **Toggle Desktop Clock** | Show/hide draggable retro desktop clock widget |
| `Super + N` | **Control Center** | Toggle WiFi, Bluetooth, Quick Toggles & Sliders |
| `Super + P` | **Power Menu** | Open Lock, Logout, Reboot, Shutdown menu |
| `Super + V` | **Wallpaper Selector** | Open bottom visual wallpaper carousel |
| `Super + W` | **Random Wallpaper** | Switch wallpaper & synchronize Pywal theme |
| `Super + Z` | **Terminal** | Launch Kitty terminal |
| `Super + A` | **Application Launcher**| Open Rofi drun application menu |
| `Super + E` | **File Manager** | Launch Thunar file manager |
| `Super + X` | **Zen Browser** | Open Zen Browser / Scratchpad |
| `Super + Q` | **Close Window** | Close active focused window |
| `Super + F` | **Fullscreen** | Toggle window fullscreen (auto-hides island) |
| `Super + Shift + F` | **Floating** | Toggle window floating state |
| `Super + D` | **Center Floating** | Resize active window to 960x560 and center |
| `Print` | **Capture Region** | Interactive area screenshot to Swappy |
| `Super + Print`| **Full Screenshot** | Copy full desktop screenshot to clipboard |

---

### 📦 Dependencies

Install the following packages on Arch Linux:

```bash
# Core window manager & shell
sudo pacman -S hyprland kitty rofi dunst pipewire wireplumber pamixer brightnessctl grim slurp wl-clipboard

# Quickshell (available in Arch AUR)
yay -S quickshell-git

# Audio & Music Player
sudo pacman -S mpv socat yt-dlp playerctl

# Theming & Wallpaper
sudo pacman -S python-pywal python-gobject swww

# Fonts
sudo pacman -S ttf-jetbrains-mono-nerd ttf-font-awesome noto-fonts-emoji
```

---

### 🚀 One-Command Installation

Clone the repository and run the automated installer:

```bash
git clone https://github.com/respaldoperez348-rgb/hypr-abyss.git ~/hypr-abyss
cd ~/hypr-abyss
./install.sh
```

The installer will:
1. Detect your package manager and install any missing dependencies.
2. Backup any existing configuration folders to `~/.config.bak.<timestamp>`.
3. Copy all dotfiles to `~/.config/`.
4. Ensure all helper scripts have executable permissions (`chmod +x`).
5. Create `~/Pictures/Wallpapers` with a sample starter wallpaper.

---

## 🇪🇸 Español

### ✨ Características Principales

- **Dynamic Island Flotante**: Cápsula de vidrio esmerilado en la parte superior con workspaces estilo Pacman, telemetría de CPU/WiFi/BT/Batería y módulo MPRIS dinámico con ecualizador animado de 4 barras.
- **Reloj de Escritorio Retro Arrastrable (`Super + B`)**: Widget estilo Material You con persistencia de posición en pantalla, selector de temas, escala y formato 12h/24h.
- **Reproductor de Música Aura Music (`Super + Y`)**: Transmisión de audio directa de YouTube en segundo plano (MPV + yt-dlp + socat), recomendación de Mix Diario, guardado de favoritos y cierre instantáneo con `Super + R`.
- **Centro de Control (`Super + N`)**: Gestión rápida de redes WiFi, dispositivos Bluetooth, control de brillo/volumen, capturas de pantalla y grabador.
- **Menú de Energía (`Super + P`)**: Apagado, reinicio, bloqueo y suspensión con compatibilidad universal para cualquier distribución.
- **Selector de Fondos (`Super + V`)**: Carrusel inferior con previsualizaciones y sincronización automática de paleta con Pywal.

### 🛠️ Instalación Rápida

```bash
git clone https://github.com/respaldoperez348-rgb/hypr-abyss.git ~/hypr-abyss
cd ~/hypr-abyss
./install.sh
```

---
<img width="1920" height="1080" alt="swappy-20261027_092916" src="https://github.com/user-attachments/assets/6f0f8c55-9f4d-4727-a394-106355bae626" />

<img width="1920" height="1080" alt="screenshot_2026-10-27_09-28-16" src="https://github.com/user-attachments/assets/ab1d4506-fe52-43fb-856d-f18b743e9bea" />





<div align="center">
  <sub>Desarrollado con ❤️ para la comunidad de Hyprland & Linux.</sub>
</div>






