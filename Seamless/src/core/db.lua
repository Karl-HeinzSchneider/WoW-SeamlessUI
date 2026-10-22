---@type string, SeamlessCore
local _, app = ...

app.dbDefaults = {
    profile = {
        logLevel = "INFO",
        minimap = { hide = false, minimapPos = 200, showInCompartment = false },
        tweaks = {
            quickKeybindShortcut = true,
            reloadShortcut = true,
            showFramerateOnStartup = false,
        },
    },
}
