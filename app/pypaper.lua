local vars = require("vars")

hl.window_rule({ match = { title = "pypaper" }, no_blur = false })
hl.window_rule({ match = { title = "pypaper" }, float = true })
hl.window_rule({ match = { title = "pypaper" }, size = { 850, 652 } })

hl.window_rule({
    name = "center-pypaper",
    match = { title = "pypaper" },
    move = { 700, 300 },
    animation = "popin",
})

hl.bind(vars.mainMod .. " + W", hl.dsp.exec_cmd("pypaper"))
