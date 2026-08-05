local officeApps = "^(Microsoft (Word|Excel|PowerPoint|Publisher|Powershell|Visual Studio))$"

hl.window_rule({
    name = "suppress-office-maximize",
    match = { class = officeApps },
    suppress_event = "maximize",
})
