---@type string, SeamlessUI
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@type SeamlessCore.SettingsPage
app.optionPages.fpsDisplay = {
    defaults = {
        profile = { fpsDisplay = { layouts = {}, showLatency = false, whiteLatency = false, roundFramerate = false } },
    },
    config = {
        type = "group",
        name = L["FPS display"],
        order = 20,
        args = {
            startup = {
                type = "toggle",
                order = 1,
                name = L["Show FPS on startup"],
                default = false,
                get = function()
                    return app.core.db.profile.tweaks.showFramerateOnStartup
                end,
                set = function(_, value)
                    app.fpsDisplay:SetOption("startup", value)
                end,
            },
            showLatency = {
                type = "toggle",
                order = 2,
                name = L["Show latency"],
                default = false,
                get = function()
                    return app.db.profile.fpsDisplay.showLatency
                end,
                set = function(_, value)
                    app.fpsDisplay:SetOption("showLatency", value)
                end,
            },
            whiteLatency = {
                type = "toggle",
                order = 3,
                name = L["White latency text"],
                default = false,
                get = function()
                    return app.db.profile.fpsDisplay.whiteLatency
                end,
                set = function(_, value)
                    app.fpsDisplay:SetOption("whiteLatency", value)
                end,
            },
            roundFramerate = {
                type = "toggle",
                order = 4,
                name = L["Round FPS"],
                default = false,
                get = function()
                    return app.db.profile.fpsDisplay.roundFramerate
                end,
                set = function(_, value)
                    app.fpsDisplay:SetOption("roundFramerate", value)
                end,
            },
            position = app.core:GetPositionOptions(app.fpsDisplay:GetPositionBinding()),
        },
    },
}
