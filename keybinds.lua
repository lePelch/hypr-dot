local vars = require("vars")
local workspace_store = require("workspace_store")

hl.bind(vars.mainMod .. " + S", hl.dsp.exec_cmd("grimblast copy area"))
hl.bind(
	vars.mainMod .. " + T",
	hl.dsp.exec_cmd([=[bash -o pipefail -c '
	geometry=$(slurp) || exit 0
	# A sentinel prevents command substitution from stripping trailing newlines.
	text=$(grim -g "$geometry" - | tesseract stdin stdout -l fra+eng --psm 6 -c preserve_interword_spaces=1 && printf ".") || exit 1
	text=${text%.}
	[[ "$text" =~ [^[:space:]] ]] || exit 0
	printf "%s" "$text" | wl-copy --type text/plain
']=])
)

hl.bind(vars.mainMod .. " + Q", hl.dsp.exec_cmd(vars.terminal))
hl.bind(vars.mainMod .. " + N", hl.dsp.exec_cmd(vars.calc))
hl.bind(vars.mainMod .. " + C", hl.dsp.window.close())
hl.bind(vars.mainMod .. " + M", hl.dsp.exit())
hl.bind(
	vars.mainMod .. " + E",
	hl.dsp.exec_cmd("XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental && " .. vars.fileManager)
)
hl.bind(vars.mainMod .. " + P", hl.dsp.window.float({ action = "toggle" }))
hl.bind(vars.mainMod .. " + G", hl.dsp.exec_cmd(vars.color_picker))
hl.bind(vars.mainMod .. " + R", hl.dsp.exec_cmd(vars.menu))
hl.bind(vars.mainMod .. " + Z", hl.dsp.window.pseudo())
hl.bind(vars.mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(vars.mainMod .. " + F", hl.dsp.window.fullscreen())

hl.bind(vars.mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(vars.mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(vars.mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(vars.mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

hl.bind(vars.mainMod .. " + A", function()
	workspace_store.push()
end)
hl.bind(vars.mainMod .. " + D", function()
	workspace_store.pop()
end)

for workspace = 1, 10 do
	local key = workspace % 10

	hl.bind(vars.mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }), { dont_inhibit = true })
	hl.bind(vars.mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
	hl.bind(vars.mainMod .. " + CTRL + " .. key, function()
		workspace_store.pop(key)
	end)
end

hl.bind(vars.mainMod .. " + mouse_down", function()
	workspace_store.cycle(1)
end)
hl.bind(vars.mainMod .. " + mouse_up", function()
	workspace_store.cycle(-1)
end)

hl.bind(vars.mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(vars.mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
