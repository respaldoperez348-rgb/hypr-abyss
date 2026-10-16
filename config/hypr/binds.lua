local mainMod = "SUPER"
local home = os.getenv("HOME") or "/home/david-tineo"

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "pkill rofi || rofi -show drun -show-icons"
local browser   = "microsoft-edge-stable"
-- Aplicaciones y control de ventanas
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(home .. "/.config/quickshell/scripts/music_control.sh quit; quickshell ipc call musicplayer close"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
-- Application launcher
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
--hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("ryotunes"))

-- Captura directa de toda la pantalla al portapapeles con Super + Print
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("grim - | wl-copy"))


-- Atajo para cambiar Wallpaper + Recargar tema dinámico
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/wallchange.sh"))

-- Atajo para abrir Selector Visual de Fondos (Super + V)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("quickshell ipc call wallpaper toggle"))

-- Atajo para abrir Centro de Control y Notificaciones (Super + N)
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("quickshell ipc call controlcenter toggle"))

-- Atajo para abrir Menú de Energía y Apagado (Super + P)
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("quickshell ipc call powermenu toggle"))
-- Launch vscode
hl.bind(mainMod .. " + ", hl.dsp.exec_cmd("code"))

-- Atajo para mostrar/ocultar Reloj de Escritorio (Super + B)
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("quickshell ipc call clock toggle"))

-- Atajo para Actualización Segura del Sistema (Super + U)
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("kitty --class arch-updater --title 'Actualización del Sistema Arch Linux' -e " .. home .. "/.config/hypr/scripts/system_update.sh"))

-- Atajo para Reproductor de Música (Super + Y)
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("quickshell ipc call musicplayer toggle"))

-- Navegación con flechas
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces 1 al 10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Multimedia y Brillo (con OSD interactivo estilo Dolphin)
local volScript    = home .. "/.config/hypr/scripts/volumecontrol.sh"
local brightScript = home .. "/.config/hypr/scripts/brightness.sh"

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(volScript .. " --inc"),        { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(volScript .. " --dec"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(volScript .. " --toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(volScript .. " --toggle-mic"), { locked = true, repeating = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(brightScript .. " up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(brightScript .. " down"), { locked = true, repeating = true })

-- ==============================================================================
-- Control de Ventanas, Fullscreen y Modo Compacto (Super + D)
-- ==============================================================================

hl.bind(mainMod .. " + D", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 960, y = 560, relative = false }))
    hl.dispatch(hl.dsp.window.center())
end)

-- Super + SHIFT + F: Alternar flotante normal
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- ==============================================================================
-- Control con el Ratón (Mouse Binds oficiales de Hyprland Lua)
-- ==============================================================================

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- Super + Clic Derecho (mouse:273): Cambiar el tamaño de la ventana con el ratón
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
