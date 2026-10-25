---@type string, SeamlessDamageMeter
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

app.positionDefaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 1,
}
---@type SeamlessCore.SettingsPage
app.optionPages.windows = {
    tooltip = function(path)
        local key = path[#path]
        if key == "override" or key == "hidden" then
            return false
        end
        if key == "skin" then
            return "default"
        end
        if key == "enabled" then
            return path[1] == "window1"
        end
        if key == "default" or key == "value" then
            return app.db.profile.windowDefaults[path[#path - 1]]
        end
        return app.windowDefaults[key]
    end,
    defaults = {
        profile = {
            windowDefaults = {
                width = 400,
                height = 200,
                fixedHeight = true,
                visibleLines = 7,
                showResizeHandle = true,
                lockSize = false,
                lockPosition = false,
                numbers = "complete",
            },
        },
    },
    config = {
        type = "group",
        name = L["Window defaults"],
        order = 10,
        args = app.WindowAppearanceOptions(),
    },
}

app.windowDefaults = app.optionPages.windows.defaults.profile.windowDefaults
