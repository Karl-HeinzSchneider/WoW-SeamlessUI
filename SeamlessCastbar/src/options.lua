---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function refresh()
    app.addon:Refresh()
end

local function barToggle(order, key, name)
    return {
        type = "toggle",
        order = order,
        name = name,
        get = function()
            return app.db.profile.bars[key]
        end,
        set = function(_, value)
            app.db.profile.bars[key] = value
            refresh()
        end,
    }
end

local options = app.addon:NewModule("Options")
function options:OnInitialize()
    app.core:RegisterOptions(appName, {
        title = L["Castbar"],
        general = {
            bars = {
                type = "group",
                inline = true,
                order = 5,
                name = L["Cast bars"],
                args = {
                    desc = {
                        type = "description",
                        order = 1,
                        name = L["Choose which of the game's cast bars the options below change."],
                    },
                    player = barToggle(10, "player", L["Player"]),
                    target = barToggle(20, "target", L["Target"]),
                    focus = barToggle(30, "focus", L["Focus"]),
                },
            },
            castTime = app.core.FeatureGroup({
                order = 10,
                name = L["Cast time"],
                desc = L["Show the cast time on the target and focus cast bars. The player cast bar shows it when Show Cast Time is on in its Edit Mode settings; this changes how it reads."],
                settings = function()
                    return app.db.profile.castTime
                end,
                toggled = refresh,
                changed = refresh,
                options = {
                    format = {
                        type = "select",
                        order = 1,
                        name = L["Cast time format"],
                        values = {
                            REMAINING = L["Remaining (1.3)"],
                            REMAINING_TOTAL = L["Remaining / total (1.3 / 2.5)"],
                            ELAPSED_TOTAL = L["Elapsed / total (1.2 / 2.5)"],
                        },
                        sorting = { "REMAINING", "REMAINING_TOTAL", "ELAPSED_TOTAL" },
                    },
                    decimals = { type = "range", order = 2, name = L["Decimals"], min = 0, max = 2, step = 1 },
                },
            }),
            rank = app.core.FeatureGroup({
                order = 20,
                name = L["Spell rank"],
                desc = L["Add the spell's rank to its name on the cast bar, such as Frostbolt (Rank 3)."],
                settings = function()
                    return app.db.profile.rank
                end,
                toggled = refresh,
            }),
            ticks = app.core.FeatureGroup({
                order = 30,
                name = L["Channel ticks"],
                desc = L["Mark where each tick of a channeled spell lands, such as Drain Life, Arcane Missiles or Blizzard."],
                settings = function()
                    return app.db.profile.ticks
                end,
                toggled = refresh,
            }),
            icon = app.core.FeatureGroup({
                order = 40,
                name = L["Player spell icon"],
                desc = L["Show the spell icon beside the player cast bar when it is not locked to the player frame. Target and focus bars always show it."],
                settings = function()
                    return app.db.profile.icon
                end,
                toggled = refresh,
            }),
            hold = app.core.FeatureGroup({
                order = 50,
                name = L["Hold time"],
                desc = L["How long a cast bar stays before it fades out."],
                settings = function()
                    return app.db.profile.hold
                end,
                toggled = refresh,
                changed = refresh,
                options = {
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
            }),
        },
        db = app.db,
    })
end
