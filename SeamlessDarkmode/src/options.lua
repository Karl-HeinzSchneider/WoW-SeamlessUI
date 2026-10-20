---@type string, SeamlessDarkmode
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local options = app.addon:NewModule("Options")
function options:OnInitialize()
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
    app.core:RegisterOptions(appName, {
        title = L["Darkmode"],
        general = {
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
        db = app.db,
    })
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
