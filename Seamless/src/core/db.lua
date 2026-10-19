---@type string, SeamlessCore
local _, app = ...

app.dbDefaults = {
    profile = {
        logLevel = "INFO",
        minimap = { hide = false, minimapPos = 200, showInCompartment = false },
        tweaks = {
            reloadShortcut = true,
            questXPTooltip = true,
            enhancedXPTooltip = true,
            restedXPCap = 150,
            restedXPRate = 5,
        },
    },
}
