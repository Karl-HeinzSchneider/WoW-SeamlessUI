---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        return app.dbDefaults.profile[path[#path]]
    end,
    defaults = { profile = { layout = "current" } },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
            layout = {
                type = "select",
                order = 1,
                name = L["Unit frame layout"],
                desc = L["Current leaves the game's layout unchanged. Legacy restores the exported pre-70425 artwork and layout. Changes made during combat apply when combat ends."],
                values = { current = L["Current (70425)"], legacy = L["Legacy (before 70425)"] },
                sorting = { "current", "legacy" },
                get = function()
                    return app.db.profile.layout
                end,
                set = function(_, value)
                    app.db.profile.layout = value
                    app.legacyLayout:Refresh()
                end,
            },
        },
    },
}
