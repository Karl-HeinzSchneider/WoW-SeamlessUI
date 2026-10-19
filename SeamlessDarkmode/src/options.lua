---@type string, SeamlessDarkmode
local appName, app = ...

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
                desc = "Tint for the frame borders of every group switched on below.",
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
                name = "Unit frames: the borders and level circles of the player, target, focus, pet, party and boss frames. Minimap: the ring around the map, the zone header and the borders of addon minimap buttons. Icons, portraits, text and bars keep their colors.",
            },
            groups = {
                type = "group",
                inline = true,
                order = 10,
                name = "Frames",
                disabled = function()
                    return not app.db.profile.enabled
                end,
                args = groups,
            },
        },
        db = app.db,
    })
end
