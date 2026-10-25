-- Target only the patched Pet overlay, never the main ChatGPT window.
-- Positioning applies on open; ChatGPT can subsequently move its overlay.
hl.window_rule({
    name = "chatgpt-pet",
    match = {
        class = "^[Cc]hatgpt$",
        title = [[^ChatGPT Pet Overlay \(local\)$]],
    },
    float = true,
    monitor = "DP-6",
    move = { 20, "monitor_h-window_h-20" },
    no_blur = true,
})
