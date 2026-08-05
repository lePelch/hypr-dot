hl.window_rule({ match = { class = [[^steam_app\d+$]] }, fullscreen = true })
hl.window_rule({ match = { class = [[^steam_app_\d+$]] }, monitor = "1" })
hl.window_rule({ match = { class = [[^steam_app_\d+$]] }, workspace = "10" })

hl.workspace_rule({ workspace = "10", no_border = true, no_rounding = true })
hl.workspace_rule({ workspace = "10", gaps_in = 0, gaps_out = 0 })
