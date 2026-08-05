local vars = require("vars")

hl.workspace_rule({ workspace = "1", monitor = vars.monitor_1 })
hl.workspace_rule({ workspace = "2", monitor = vars.monitor_1 })
hl.workspace_rule({ workspace = "3", monitor = vars.monitor_1 })
hl.workspace_rule({ workspace = "4", monitor = vars.monitor_2 })
hl.workspace_rule({ workspace = "5", monitor = vars.monitor_2 })
hl.workspace_rule({ workspace = "6", monitor = vars.monitor_2 })
hl.workspace_rule({ workspace = "7", monitor = vars.monitor_3 })
hl.workspace_rule({ workspace = "8", monitor = vars.monitor_3 })
hl.workspace_rule({ workspace = "9", monitor = vars.monitor_3 })
hl.workspace_rule({ workspace = "10", monitor = vars.monitor_2 })

hl.monitor({ output = vars.monitor_1, mode = "1920x1200@60", position = "0x0", scale = 1 })
hl.monitor({ output = vars.monitor_2, mode = "1920x1080@60", position = "1920x0", scale = 1 })
hl.monitor({ output = vars.monitor_3, mode = "1920x1080@60", position = "3840x0", scale = 1 })

-- hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "0x-1080", scale = 1 })
