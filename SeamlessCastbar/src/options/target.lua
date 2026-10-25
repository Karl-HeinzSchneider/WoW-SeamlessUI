---@type string, SeamlessCastbar
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function refresh()
    app.addon:Refresh()
end
local position = app.position:GetOptions("target")
if position then
    position.order = 5
end
---@type SeamlessCore.SettingsPage
app.optionPages.target = {
    tooltip = function(path)
        local value = app.core:GetOptionDefault(app.dbDefaults.profile, path)
        if type(value) == "table" then
            return value.enabled
        end
        return value
    end,
    defaults = {
        profile = {
            target = {
                enabled = true,
                castTime = { enabled = true, format = "ELAPSED_TOTAL", decimals = 1 },
                rank = { enabled = true },
                ticks = { enabled = true },
                hold = { enabled = false, success = 0.2, interrupt = 1 },
            },
        },
    },
    config = {
        editModeVisibility = app.core:GetCustomEditModeVisibility("SeamlessCastbar.target", function()
            return app.PreviewVisibility("target")
        end, function(value)
            app.PreviewVisibility("target", value)
        end),
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Target"],
        order = 20,
        args = {
            position = position,

            enabled = {
                type = "toggle",
                order = 1,
                width = "full",
                name = L["Enable"],
                desc = L["Apply the Seamless options to this cast bar."],
                descStyle = "inline",
                get = function()
                    return app.db.profile["target"].enabled
                end,
                set = function(_, value)
                    app.db.profile["target"].enabled = value
                    refresh()
                end,
            },
            castTime = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.target.castTime
                end,
                toggled = refresh,
                changed = refresh,
                disabled = function(info)
                    return not app.db.profile.target.enabled
                        or (info[#info] ~= "enabled" and not app.db.profile.target.castTime.enabled)
                end,

                order = 10,
                name = L["Cast time"],
                desc = L["Show the cast time to the right of the cast bar."],
                args = {
                    format = {
                        type = "select",
                        order = 1,
                        name = L["Cast time format"],
                        values = app.castTimeFormats,
                        sorting = app.castTimeFormatOrder,
                    },
                    decimals = { type = "range", order = 2, name = L["Decimals"], min = 0, max = 2, step = 1 },
                },
            },
            rank = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.target.rank
                end,
                toggled = refresh,
                changed = refresh,
                disabled = function(info)
                    return not app.db.profile.target.enabled
                end,

                order = 20,
                name = L["Spell rank"],
                desc = L["Add the spell's rank to its name on the cast bar, such as Frostbolt (Rank 3)."],
            },
            ticks = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.target.ticks
                end,
                toggled = refresh,
                changed = refresh,
                disabled = function(info)
                    return not app.db.profile.target.enabled
                end,

                order = 30,
                name = L["Channel ticks"],
                desc = L["Mark where each tick of a channeled spell lands, such as Drain Life, Arcane Missiles or Blizzard."],
            },
            hold = {
                type = "group",
                feature = true,
                settings = function()
                    return app.db.profile.target.hold
                end,
                toggled = refresh,
                changed = refresh,
                disabled = function(info)
                    return not app.db.profile.target.enabled
                        or (info[#info] ~= "enabled" and not app.db.profile.target.hold.enabled)
                end,

                order = 50,
                name = L["Hold time"],
                desc = L["How long a cast bar stays before it fades out."],
                args = {
                    success = {
                        type = "range",
                        order = 1,
                        name = L["After a finished cast"],
                        desc = L["Seconds. The game uses 0.2."],
                        min = 0,
                        max = 3,
                        step = 0.1,
                    },
                    interrupt = {
                        type = "range",
                        order = 2,
                        name = L["After an interrupt"],
                        desc = L["Seconds. The game uses 1."],
                        min = 0.1,
                        max = 5,
                        step = 0.1,
                    },
                },
            },
        },
    },
}
