---@type string, SeamlessActionBars
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function refresh()
    app.addon:Refresh()
end

local options = app.addon:NewModule("Options")
function options:OnInitialize()
    app.core:RegisterOptions(appName, {
        tooltip = function(path)
            local defaults = app.dbDefaults.profile[path[2]]
            return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
        end,
        title = L["Action Bars"],
        general = {
            range = app.core.FeatureGroup({
                order = 10,
                name = L["Out of range"],
                desc = L["Color the icon of an action that is out of range of your target."],
                settings = function()
                    return app.db.profile.range
                end,
                toggled = refresh,
                changed = refresh,
                options = {
                    color = { type = "color", order = 1, name = L["Out of range color"], hasAlpha = false },
                },
            }),
            mana = app.core.FeatureGroup({
                order = 20,
                name = L["Not enough mana"],
                desc = L["Color the icon of an action you lack the mana, rage or energy for, instead of the game's light blue shade."],
                settings = function()
                    return app.db.profile.mana
                end,
                toggled = refresh,
                changed = refresh,
                options = {
                    color = { type = "color", order = 1, name = L["Not enough mana color"], hasAlpha = false },
                },
            }),
            keybinds = app.core.FeatureGroup({
                order = 30,
                name = L["Short keybind labels"],
                desc = L["Show keybinds as short labels, such as SM4 for Shift and mouse button 4, or N5 for num pad 5."],
                settings = function()
                    return app.db.profile.keybinds
                end,
                toggled = refresh,
            }),
        },
    })
end
