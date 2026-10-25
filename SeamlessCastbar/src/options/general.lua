---@type string, SeamlessCastbar
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    defaults = {},
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
            bars = {
                type = "group",
                inline = true,
                order = 5,
                name = L["Cast bars"],
                args = {
                    desc = {
                        type = "description",
                        order = 1,
                        name = L["Each cast bar has its own tab. The player cast bar's options are also under Style in SeamlessUI's extended Edit Mode window."],
                    },
                },
            },
        },
    },
}
