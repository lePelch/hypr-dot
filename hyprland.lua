hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

require("keybinds")
require("clipboard")
require("ricing")
require("monitor")
require("autostart")
require("input")
require("gaming")

require("app/cisco")
require("app/sumatra")
require("app/pavucontrol")
require("app/discord")
require("app/pypaper")
require("app/android-studio")
require("app/winapps")

hl.window_rule({
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})
