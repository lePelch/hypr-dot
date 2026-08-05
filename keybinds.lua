local vars = require("vars")

hl.bind(vars.mainMod .. " + S", hl.dsp.exec_cmd("grimblast copy area"))

hl.bind(vars.mainMod .. " + Q", hl.dsp.exec_cmd(vars.terminal))
hl.bind(vars.mainMod .. " + N", hl.dsp.exec_cmd(vars.calc))
hl.bind(vars.mainMod .. " + C", hl.dsp.window.close())
hl.bind(vars.mainMod .. " + M", hl.dsp.exit())
hl.bind(vars.mainMod .. " + E", hl.dsp.exec_cmd("XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental && " .. vars.fileManager))
hl.bind(vars.mainMod .. " + P", hl.dsp.window.float({ action = "toggle" }))
hl.bind(vars.mainMod .. " + R", hl.dsp.exec_cmd(vars.menu))
hl.bind(vars.mainMod .. " + Z", hl.dsp.window.pseudo())
hl.bind(vars.mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(vars.mainMod .. " + F", hl.dsp.window.fullscreen())

hl.bind(vars.mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(vars.mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(vars.mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(vars.mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

for workspace = 1, 10 do
    local key = workspace % 10

    hl.bind(vars.mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(vars.mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(vars.mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(vars.mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(vars.mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(vars.mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
