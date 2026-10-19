---@type string, SeamlessDarkmode
local appName, app = ...

local options = app.addon:NewModule("Options")
function options:OnInitialize()
    local categories = {}
    for index, category in ipairs(app.categories) do
        local key = category.key
        categories[key] = {
            type = "toggle",
            order = index,
            name = category.name,
            get = function()
                return app.db.profile.categories[key]
            end,
            set = function(_, value)
                app.db.profile.categories[key] = value
                app.addon:Refresh()
            end,
        }
    end
    app.core:RegisterOptions(appName, {
        title = "Darkmode",
        general = {
            enabled = {
                type = "toggle",
                order = 1,
                name = "Enable darkmode",
                width = "full",
                get = function()
                    return app.db.profile.enabled
                end,
                set = function(_, value)
                    app.db.profile.enabled = value
                    app.addon:Refresh()
                end,
            },
            color = {
                type = "color",
                order = 2,
                name = "Darkmode color",
                hasAlpha = false,
                desc = "Shared tint for supported UI borders and decoration. Changes made in combat apply after combat.",
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
                name = "Tints decorative UI art while preserving icons, text, health/power bars and status indicators. Disabling a category restores its colors. New frames in supported categories and pooled buttons are discovered automatically; changes in combat wait until combat ends.",
            },
            categories = {
                type = "group",
                inline = true,
                order = 10,
                name = "Categories",
                disabled = function()
                    return not app.db.profile.enabled
                end,
                args = categories,
            },
        },
        db = app.db,
    })
end
