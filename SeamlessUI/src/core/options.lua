---@type string, SeamlessUI
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.Options : AceModule
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessUI.Options]]

function module:OnInitialize()
    app.core:RegisterOptions(appName, {
        tooltip = function(path)
            if path[1] == "general" then
                return app.core:GetOptionDefault(app.dbDefaults.profile, path, 2)
            end
            local defaults = app.dbDefaults.profile.blizzardEditMode
            if defaults[path[2]] ~= nil then
                return defaults[path[2]]
            end
            return app.core:GetOptionDefault(defaults.frames, { path[2], "enabled" })
        end,
        title = L["UI"],
        general = {
            editModeKeyboard = app.editModeKeyboard:Options(),
            xpBarTooltip = app.xpBarTooltip:Options(),
        },
        tabs = {
            blizzardEditMode = app.blizzardEditMode:Options(),
        },
    })
end

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end
