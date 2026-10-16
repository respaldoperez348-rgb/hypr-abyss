-- Monitors
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("GTK_THEME", "adw-gtk3-dark")

-- Input config
hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        allow_session_lock_restore = true,
    },
})

-- Modular imports
require("theme")
require("animations")
require("binds")
require("rules")
require("autostart")
require("user")
