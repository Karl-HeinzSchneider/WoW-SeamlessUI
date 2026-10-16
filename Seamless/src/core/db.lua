---@type string, SeamlessCore
local _, app = ...

app.dbDefaults = {
    profile = {
        logLevel = "INFO",
        minimap = { hide = false, minimapPos = 200 },
        tweaks = { reloadShortcut = true, showFramerateOnStartup = false, questXPTooltip = true },
    },
}
