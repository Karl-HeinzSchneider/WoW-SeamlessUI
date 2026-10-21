---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function refresh()
    app.addon:Refresh()
end

-- The cast bars in tab order, with their tab name and how their cast time is shown.
local bars = {
    {
        key = "player",
        name = L["Player"],
        castTimeDesc = L["Change how the player cast bar's cast time reads. Show it with Show Cast Time in the cast bar's Edit Mode settings."],
    },
    { key = "target", name = L["Target"], castTimeDesc = L["Show the cast time to the right of the cast bar."] },
    { key = "focus", name = L["Focus"], castTimeDesc = L["Show the cast time to the right of the cast bar."] },
}

-- One feature group of a bar's tab, greyed out while the bar itself is switched off.
local function feature(bar, key, spec)
    spec.settings = function()
        return app.db.profile[bar.key][key]
    end
    spec.toggled = refresh
    spec.changed = refresh
    local group = app.core.FeatureGroup(spec)
    local disabled = group.disabled
    group.disabled = function(info)
        return not app.db.profile[bar.key].enabled or disabled(info)
    end
    return group
end

local function barTab(order, bar)
    local args = {
        enabled = {
            type = "toggle",
            order = 1,
            width = "full",
            name = L["Enable"],
            desc = L["Apply the Seamless options to this cast bar."],
            descStyle = "inline",
            get = function()
                return app.db.profile[bar.key].enabled
            end,
            set = function(_, value)
                app.db.profile[bar.key].enabled = value
                refresh()
            end,
        },
        castTime = feature(bar, "castTime", {
            order = 10,
            name = L["Cast time"],
            desc = bar.castTimeDesc,
            options = {
                format = {
                    type = "select",
                    order = 1,
                    name = L["Cast time format"],
                    values = app.castTimeFormats,
                    sorting = app.castTimeFormatOrder,
                },
                decimals = { type = "range", order = 2, name = L["Decimals"], min = 0, max = 2, step = 1 },
            },
        }),
        rank = feature(bar, "rank", {
            order = 20,
            name = L["Spell rank"],
            desc = L["Add the spell's rank to its name on the cast bar, such as Frostbolt (Rank 3)."],
        }),
        ticks = feature(bar, "ticks", {
            order = 30,
            name = L["Channel ticks"],
            desc = L["Mark where each tick of a channeled spell lands, such as Drain Life, Arcane Missiles or Blizzard."],
        }),
        hold = feature(bar, "hold", {
            order = 50,
            name = L["Hold time"],
            desc = L["How long a cast bar stays before it fades out."],
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
    }
    if bar.key == "player" then
        args.icon = feature(bar, "icon", {
            order = 40,
            name = L["Spell icon"],
            desc = L["Show the spell icon beside the player cast bar when it is not locked to the player frame."],
        })
    end
    return { order = order, name = bar.name, args = args }
end

local options = app.addon:NewModule("Options")
function options:OnInitialize()
    local tabs = {}
    for index, bar in ipairs(bars) do
        tabs[bar.key] = barTab(index * 10, bar)
    end
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
                        name = L["Each cast bar has its own tab. The player cast bar's options are also under Style in SeamlessUI's extended Edit Mode window."],
                    },
                },
            },
        },
        tabs = tabs,
    })
end
