---@type string, SeamlessUI
local appName, app = ...

---@class SeamlessUI.Options : AceModule
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessUI.Options]]

function module:OnInitialize()
    app.core:RegisterOptions(appName, {
        title = "UI",
        general = {
            framerate = {
                type = "group",
                inline = true,
                order = 10,
                name = "Framerate",
                get = function(info)
                    return app.db.profile.framerate[info[#info]]
                end,
                set = function(info, value)
                    app.framerate:Set(info[#info], value)
                end,
                args = {
                    movable = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = "Move the framerate display in Edit Mode",
                        desc = "Select the FPS counter in Edit Mode to drag it anywhere. Turning this off returns it to the bottom-right corner.",
                        descStyle = "inline",
                    },
                    showOnStartup = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = "Show the framerate on startup",
                        desc = "Shows the FPS counter at login and after a reload. Takes effect at the next login or reload; Ctrl+R still toggles it.",
                        descStyle = "inline",
                    },
                },
            },
        },
        db = app.db,
    })
end

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end
