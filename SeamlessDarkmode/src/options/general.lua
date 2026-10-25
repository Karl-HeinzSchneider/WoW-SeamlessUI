---@type string, SeamlessDarkmode
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local groups = {}
for index, group in ipairs(app.groups) do
    local key = group.key
    groups[key] = {
        type = "toggle",
        order = index,
        name = group.name,
        get = function()
            return app.db.profile.groups[key]
        end,
        set = function(_, value)
            app.db.profile.groups[key] = value
            app.addon:Refresh()
        end,
    }
end
---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        return app.core:GetOptionDefault(app.dbDefaults.profile, path, 2)
    end,
    defaults = { profile = { enabled = true, color = { r = 0.22, g = 0.22, b = 0.22 }, groups = { ["*"] = true } } },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
            enabled = {
                type = "toggle",
                order = 1,
                name = L["Enable darkmode"],
                width = "full",
                get = function()
                    return app.db.profile.enabled
                end,
                set = function(_, value)
                    app.db.profile.enabled = value
                    app.addon:Refresh()
                    app.core:RefreshEditModeOptions()
                end,
            },
            color = {
                type = "color",
                order = 2,
                name = L["Darkmode color"],
                hasAlpha = false,
                desc = L["Tint for the frame borders of every group switched on below."],
                disabled = function()
                    return not app.db.profile.enabled
                end,
                get = function()
                    local color = app.db.profile.color
                    return color.r, color.g, color.b
                end,
                set = function(_, r, g, b)
                    app.db.profile.color = { r = r, g = g, b = b }
                    app.addon:Refresh()
                end,
            },
            description = {
                type = "description",
                order = 3,
                name = L["Tint unit frame and minimap borders, action bar slot borders and gryphons, and XP and reputation bar borders. Each group can be switched independently. Icons, portraits, text and bar fills keep their colors."],
            },
            groups = {
                type = "group",
                inline = true,
                order = 10,
                name = L["Frames"],
                disabled = function()
                    return not app.db.profile.enabled
                end,
                args = groups,
            },
        },
    },
}
