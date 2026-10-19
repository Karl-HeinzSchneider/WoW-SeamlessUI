---@type string, SeamlessDarkmode
local appName, app = ...

local options = app.addon:NewModule("Options")
function options:OnInitialize()
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
                desc = "Tint for the unit frame borders.",
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
                name = "Tints the frame borders and level circles of the player, target, focus, pet, party and boss frames. Portraits, text and bars keep their colors.",
            },
        },
        db = app.db,
    })
end
