---@type string, SeamlessCore
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@type SeamlessCore.SettingsPage
app.optionPages.tweaks = {
    tooltip = function(path)
        return app.dbDefaults.profile.tweaks[path[#path]]
    end,
    defaults = {
        profile = { tweaks = { quickKeybindShortcut = true, reloadShortcut = true, showFramerateOnStartup = false } },
    },
    config = {
        type = "group",
        name = L["Tweaks"],
        order = 500,
        args = {
            tweaks = {
                type = "group",
                inline = true,
                order = 10,
                name = L["Tweaks"],
                get = function(info)
                    return app.db.profile.tweaks[info[#info]]
                end,
                set = function(info, value)
                    app.db.profile.tweaks[info[#info]] = value
                    app.tweaks:OnProfileRefresh()
                end,
                args = {
                    reloadShortcut = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["/rl reloads the interface"],
                        desc = L["Type /rl in chat to reload the user interface, just like /reload."],
                        descStyle = "inline",
                    },
                    quickKeybindShortcut = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = L["/kb starts Quick Keybind Mode"],
                        desc = L["Type /kb in chat to bind keys by hovering over action buttons, like the Quick Keybind Mode button in the Keybindings settings."],
                        descStyle = "inline",
                    },
                },
            },
        },
    },
}
