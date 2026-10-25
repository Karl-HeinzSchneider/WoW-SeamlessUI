---@type string, SeamlessDarkmode
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local options = app.addon:NewModule("Options")
function options:OnInitialize()
    app.core:RegisterOptions(appName, { title = L["Darkmode"], pages = app.optionPages })
end
-- Global option in the shared Edit Mode window, the same master switch as the options panel.
app.core:RegisterEditModeOptions(appName, {
    enabled = function()
        return app.db and app.addon:IsEnabled()
    end,
    options = {
        {
            key = "enabled",
            type = "toggle",
            name = L["Enable darkmode"],
            get = function()
                return app.db.profile.enabled
            end,
            set = function(value)
                app.db.profile.enabled = value
                app.addon:Refresh()
            end,
        },
    },
})
