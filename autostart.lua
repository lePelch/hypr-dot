hl.on("hyprland.start", function()
	hl.exec_cmd("swaync")
	hl.exec_cmd("/home/ced/.config/hypr/xdph.sh")
	--hl.exec_cmd("quickshell --path /home/ced/.config/quickshell")
	hl.exec_cmd("waybar")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	-- Keep hyprpaper as a fallback until Waypaper and gslapper are installed.
	hl.exec_cmd([[
		if command -v waypaper >/dev/null 2>&1 && command -v gslapper >/dev/null 2>&1; then
			waypaper --restore
		else
			hyprpaper
		fi
	]])
	hl.exec_cmd("hyprlauncher -d")
end)
