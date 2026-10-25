-- ==============================================================================
-- Hyprland Window & Layer Rules (Translucent & Frosted Glass)
-- ==============================================================================

-- Ignorar eventos de maximizado forzado
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix para arrastres en XWayland
hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
    },
    no_focus = true,
})

-- Reglas para Gestor de Archivos Thunar
hl.window_rule({
    name = "thunar-translucent",
    match = { class = "thunar|Thunar" },
    opacity = "0.85 0.72",
})

hl.window_rule({
    name = "thunar-dialogs-floating",
    match = {
        class = "thunar|Thunar",
        title = "Confirmación.*|Progreso.*|Propiedades.*|Atención.*|File Operation.*",
    },
    float = true,
})

-- Reglas para Terminal Kitty
hl.window_rule({
    name = "kitty-translucent",
    match = { class = "kitty" },
    opacity = "0.85 0.75",
})

-- Reglas de capa (Layer rules) para desenfoque en la superficie
hl.layer_rule({
    match = "quickshell",
    blur  = true,
})

hl.layer_rule({
    match = "rofi",
    blur  = true,
})
-- Zoom flotante para diálogos y controles de llamada
hl.window_rule({
    name  = "zoom-floating",
    match = { class = "^zoom$" },
    float = true,
})
-- Forzar flotante, centrado y tamaño controlado para diálogos modales y selectores de archivos
hl.window_rule({
    name = "file-pickers-dialogs",
    match = {
        title = ".*(Carga de archivos|Abrir archivo|modificado|guardar|Save|Open|Confirm).*",
    },
    float = true,
    center = true,
    size = "900 600",
})

-- Selector de archivos del portal GTK/Wayland
hl.window_rule({
    name = "gtk-portal-file-picker",
    match = {
        class = "xdg-desktop-portal-gtk",
    },
    float = true,
    center = true,
    size = "900 600",
})


-- Centrar cualquier ventana que esté flotando
hl.window_rule({
    match = { float = true },
    center = true,
})

-- Ventana flotante y centrada para el Actualizador del Sistema
hl.window_rule({
    name = "arch-updater-floating",
    match = { class = "arch-updater" },
    float = true,
    center = true,
    size = "920 620",
})

-- Ventana flotante, centrada y estética para MuseCLI Music Player
hl.window_rule({
    name = "musecli-floating",
    match = { class = "musecli" },
    float = true,
    center = true,
    size = "1060 680",
    opacity = "0.92 0.85",
})

-- Zen Browser como Scratchpad en espacio especial
--hl.window_rule({
    --name = "zen-scratchpad",
    --match = { class = "zen" },
    --workspace = "special:browser",
--})

-- Esfera Holográfica Nativa de B.O.D.Y. (Estilo J.A.R.V.I.S.)
hl.window_rule({
    name = "body-jarvis-floating",
    match = { title = "^B\\.O\\.D\\.Y\\.$" },
    float = true,
    center = true,
    pin = true,
})

-- Android Emulator: forzar flotante para que se adapte exactamente a las dimensiones del teléfono
hl.window_rule({
    name = "android-emulator-floating",
    match = { class = ".*[Ee]mulator.*" },
    float = true,
})


