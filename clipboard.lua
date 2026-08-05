local vars = require("vars")

hl.on("hyprland.start", function()
    hl.exec_cmd("clipse --listen")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
end)

hl.window_rule({ match = { class = "(wofi)" }, float = true })
hl.window_rule({ match = { class = "(clipse)" }, float = true })
hl.window_rule({ match = { class = "(clipse)" }, size = { 622, 652 } })

hl.bind(vars.mainMod .. " + V", hl.dsp.exec_cmd(vars.terminal .. " --class clipse -e 'clipse'"))
