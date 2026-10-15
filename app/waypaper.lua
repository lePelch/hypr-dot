local vars = require("vars")

hl.window_rule({ match = { title = "^Waypaper$" }, no_blur = false })
hl.window_rule({ match = { title = "^Waypaper$" }, float = true })
hl.window_rule({ match = { title = "^Waypaper$" }, size = { 1000, 700 } })
hl.window_rule({ match = { title = "^Waypaper$" }, animation = "popin" })

hl.bind(vars.mainMod .. " + W", hl.dsp.exec_cmd("waypaper"))
