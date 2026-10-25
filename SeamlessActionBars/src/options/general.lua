---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function refresh()
    app.addon:Refresh()
end
local showBars = {
    type = "execute",
    order = 5,
    name = L["Show action bars"],
    desc = L["Open the game's Action Bars settings to show or hide action bars 2 to 8. A hidden bar is not shown in Edit Mode either."],
    disabled = function()
        return Settings.ACTION_BAR_CATEGORY_ID == nil
    end,
    func = function()
        Settings.OpenToCategory(Settings.ACTION_BAR_CATEGORY_ID)
    end,
}

---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        local defaults = app.dbDefaults.profile[path[2]]
        return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
    end,
    defaults = {
        profile = {
            range = { enabled = true, color = { r = 0.85, g = 0.4, b = 0.4 } },
            mana = { enabled = true, color = { r = 0.3, g = 0.3, b = 1 } },
            keybinds = { enabled = true },
        },
    },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
            bars = showBars,
            range = {
                type = "group",
                feature = true,
                order = 10,
                name = L["Out of range"],
                desc = L["Color the icon of an action that is out of range of your target."],
                settings = function()
                    return app.db.profile.range
                end,
                toggled = refresh,
                changed = refresh,
                args = {
                    color = { type = "color", order = 1, name = L["Out of range color"], hasAlpha = false },
                },
            },
            mana = {
                type = "group",
                feature = true,
                order = 20,
                name = L["Not enough mana"],
                desc = L["Color the icon of an action you lack the mana, rage or energy for, instead of the game's light blue shade."],
                settings = function()
                    return app.db.profile.mana
                end,
                toggled = refresh,
                changed = refresh,
                args = {
                    color = { type = "color", order = 1, name = L["Not enough mana color"], hasAlpha = false },
                },
            },
            keybinds = {
                type = "group",
                feature = true,
                order = 30,
                name = L["Short keybind labels"],
                desc = L["Show keybinds as short labels, such as SM4 for Shift and mouse button 4, or N5 for num pad 5."],
                settings = function()
                    return app.db.profile.keybinds
                end,
                toggled = refresh,
            },
        },
    },
}
