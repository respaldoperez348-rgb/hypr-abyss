local home = os.getenv("HOME")

hl.on("hyprland.start", function ()
    -- Agente de autenticación polkit
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1 || systemctl --user start hyprpolkitagent")

    -- Demonio de wallpapers para cambio dinámico
    hl.exec_cmd("swww-daemon || awww-daemon || " .. home .. "/.local/bin/swww-daemon")

    -- Quickshell (Dynamic Island)
    hl.exec_cmd("quickshell")

    -- Inicialización de fondo y sincronización de tema
    hl.exec_cmd(home .. "/.config/hypr/scripts/wallchange.sh")

    -- Demonio de inactividad y bloqueo automático (hypridle)
    hl.exec_cmd("hypridle")

    -- B.O.D.Y. HUD
    hl.exec_cmd(home .. "/.local/bin/body --minimized")

    -- Demonio de Portapapeles (cliphist para historial en Quickshell)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
