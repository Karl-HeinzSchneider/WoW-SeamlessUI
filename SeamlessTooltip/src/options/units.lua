---@type string, SeamlessTooltip
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local media = app.media
local LSM = media.LSM
local creatureFamily = app.features:GetModule("CreatureFamily")
local healthBar = app.features:GetModule("HealthBar")
local hideTitle = app.features:GetModule("HideTitle")
local hideUnits = app.features:GetModule("HideUnits")
local npcText = app.features:GetModule("NpcText")
local playerText = app.features:GetModule("PlayerText")
local raidIcon = app.features:GetModule("RaidIcon")
local statusTags = app.features:GetModule("StatusTags")
local tappedName = app.features:GetModule("TappedName")
local targetedBy = app.features:GetModule("TargetedBy")
local targetLine = app.features:GetModule("TargetLine")
local unitBorder = app.features:GetModule("UnitBorder")
---@type SeamlessCore.SettingsPage
app.optionPages.units = {
    tooltip = function(path)
        if path[2] == "game" then
            return app.core:GetCVarOptionInfo(path[3])
        end
        local defaults = app.dbDefaults.profile.features[path[2]]
        return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
    end,
    defaults = {
        profile = {
            features = {
                CreatureFamily = {
                    enabled = false,
                },
                HealthBar = {
                    enabled = true,
                    inside = true,
                    inset = 6,
                    height = 10,
                    texture = "Blizzard",
                    backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
                    text = "VALUE_MAX",
                },
                HideTitle = {
                    enabled = false,
                },
                HideUnits = {
                    enabled = false,
                    when = "COMBAT",
                    modifier = "SHIFT",
                    unitFrames = false,
                },
                NpcText = {
                    enabled = true,
                    shortLevel = true,
                    faction = "SHOW",
                },
                PlayerText = {
                    enabled = true,
                    classColorName = true,
                    classColorClass = true,
                    raceReactionColor = false,
                    shortLevel = true,
                    hideClass = false,
                    guildLine = true,
                    guildRank = true,
                    guildRankIndex = false,
                    faction = "SHOW",
                },
                RaidIcon = {
                    enabled = true,
                },
                StatusTags = {
                    enabled = true,
                    afk = true,
                    offline = true,
                    dead = true,
                    pvp = false,
                    hidePvpLine = false,
                },
                TappedName = {
                    enabled = true,
                },
                TargetedBy = {
                    enabled = true,
                    names = true,
                    you = true,
                },
                TargetLine = {
                    enabled = true,
                    you = true,
                },
                UnitBorder = {
                    enabled = true,
                    players = true,
                    npcs = true,
                    tapped = true,
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Units"],
        order = 10,
        args = {
            CreatureFamily = {
                type = "group",
                feature = true,
                name = L["Creature family"],
                desc = L["Adds a beast's family (Wolf, Cat, Spider, ...) to its tooltip."],
                order = 27,
                settings = function()
                    return creatureFamily:Settings()
                end,
                toggled = function()
                    creatureFamily:Refresh()
                end,
                changed = function()
                    creatureFamily:SettingsChanged()
                end,
                args = {},
            },
            HealthBar = {
                type = "group",
                feature = true,
                name = L["Health bar"],
                desc = L["Restyles the health bar of unit tooltips and can show it inside the tooltip, with a health text like on unit frames."],
                order = 30,
                settings = function()
                    return healthBar:Settings()
                end,
                toggled = function()
                    healthBar:Refresh()
                end,
                changed = function()
                    healthBar:SettingsChanged()
                end,
                args = {
                    inside = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Inside the tooltip"],
                        desc = L["Shows the bar at the bottom of the tooltip, inside its border, instead of below it."],
                    },
                    inset = {
                        type = "range",
                        order = 20,
                        name = L["Distance from the edge"],
                        desc = L["How far the bar stays inside the tooltip's edge; about the border's width."],
                        min = 0,
                        max = 20,
                        step = 1,
                        disabled = function()
                            local settings = healthBar:Settings()
                            return not settings.enabled or not settings.inside
                        end,
                    },
                    height = {
                        type = "range",
                        order = 30,
                        name = L["Height"],
                        min = 2,
                        max = 30,
                        step = 1,
                    },
                    texture = {
                        type = "select",
                        order = 40,
                        name = L["Texture"],
                        values = media.Values(LSM.MediaType.STATUSBAR),
                    },
                    backgroundColor = {
                        type = "color",
                        order = 50,
                        name = L["Background color"],
                        desc = L["Behind the bar, where health is missing."],
                        hasAlpha = true,
                    },
                    text = {
                        type = "select",
                        order = 60,
                        name = L["Health text"],
                        values = {
                            NONE = L["None"],
                            PERCENT = L["Percent"],
                            VALUE = L["Value"],
                            VALUE_MAX = L["Value / max"],
                            VALUE_PERCENT = L["Value (percent)"],
                        },
                        sorting = { "NONE", "PERCENT", "VALUE", "VALUE_MAX", "VALUE_PERCENT" },
                    },
                },
            },
            HideTitle = {
                type = "group",
                feature = true,
                name = L["Hide titles"],
                desc = L['Leaves player titles ("Private", "the Explorer") out of the name.'],
                order = 21,
                settings = function()
                    return hideTitle:Settings()
                end,
                toggled = function()
                    hideTitle:Refresh()
                end,
                changed = function()
                    hideTitle:SettingsChanged()
                end,
                args = {},
            },
            HideUnits = {
                type = "group",
                feature = true,
                name = L["Hide in combat"],
                desc = L["Hides unit tooltips in combat, so they don't cover what you are fighting. Hold the modifier key to see them anyway."],
                order = 60,
                settings = function()
                    return hideUnits:Settings()
                end,
                toggled = function()
                    hideUnits:Refresh()
                end,
                changed = function()
                    hideUnits:SettingsChanged()
                end,
                args = {
                    when = {
                        type = "select",
                        order = 10,
                        name = L["Hide"],
                        values = {
                            COMBAT = L["In combat"],
                            ALWAYS = L["Always"],
                        },
                        sorting = { "COMBAT", "ALWAYS" },
                    },
                    modifier = {
                        type = "select",
                        order = 20,
                        name = L["Show while holding"],
                        values = {
                            NONE = L["Nothing"],
                            SHIFT = L["Shift"],
                            CTRL = L["Ctrl"],
                            ALT = L["Alt"],
                        },
                        sorting = { "NONE", "SHIFT", "CTRL", "ALT" },
                    },
                    unitFrames = {
                        type = "toggle",
                        order = 30,
                        width = "full",
                        name = L["Unit frames too"],
                        desc = L["Also hides the tooltips of the player, target, party and raid frames; off hides only units in the world."],
                    },
                },
            },
            NpcText = {
                type = "group",
                feature = true,
                name = L["NPC text"],
                desc = L["Changes the text of NPC tooltips."],
                order = 20,
                settings = function()
                    return npcText:Settings()
                end,
                toggled = function()
                    npcText:Refresh()
                end,
                changed = function()
                    npcText:SettingsChanged()
                end,
                args = {
                    shortLevel = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Short level line"],
                        desc = L['Shows "Level 10 (Elite)" and the creature type line ("Beast") as "10 Beast (Elite)", the level in its difficulty color.'],
                    },
                    faction = {
                        type = "select",
                        order = 20,
                        name = L["Faction line"],
                        desc = L['The "Alliance" / "Horde" line.'],
                        values = {
                            SHOW = L["Show"],
                            OWN = L["Hide if it is your own faction"],
                            HIDE = L["Hide"],
                        },
                        sorting = { "SHOW", "OWN", "HIDE" },
                    },
                },
            },
            PlayerText = {
                type = "group",
                feature = true,
                name = L["Player text"],
                desc = L["Changes the text of player tooltips."],
                order = 10,
                settings = function()
                    return playerText:Settings()
                end,
                toggled = function()
                    playerText:Refresh()
                end,
                changed = function()
                    playerText:SettingsChanged()
                end,
                args = {
                    classColorName = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Name in class color"],
                    },
                    classColorClass = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = L["Class in class color"],
                    },
                    raceReactionColor = {
                        type = "toggle",
                        order = 30,
                        width = "full",
                        name = L["Race in reaction color"],
                        desc = L["Colors the race like the game colors hostile and friendly units: players of the other faction you can attack are red."],
                    },
                    shortLevel = {
                        type = "toggle",
                        order = 40,
                        width = "full",
                        name = L["Short level line"],
                        desc = L['Shows "Level 3 Dwarf (Player)" and the class line as "3 Dwarf Priest", the level in its difficulty color (red is much higher than you, grey much lower).'],
                    },
                    hideClass = {
                        type = "toggle",
                        order = 50,
                        width = "full",
                        name = L["Hide the class"],
                        desc = L['Leaves the class out; with the short level line, out of that line ("3 Dwarf").'],
                    },
                    guildLine = {
                        type = "toggle",
                        order = 60,
                        width = "full",
                        name = L["Guild as <Guild>"],
                        desc = L["Shows the guild in brackets, in the player's hostile/friendly color; your own guild in pink."],
                    },
                    guildRank = {
                        type = "toggle",
                        order = 70,
                        width = "full",
                        name = L["Guild rank"],
                        desc = L['Adds the player\'s guild rank behind the guild ("<Guild> Officer").'],
                        disabled = function()
                            local settings = playerText:Settings()
                            return not settings.enabled or not settings.guildLine
                        end,
                    },
                    guildRankIndex = {
                        type = "toggle",
                        order = 80,
                        width = "full",
                        name = L["Guild rank number"],
                        desc = L['Adds the rank\'s number behind the guild, 0 being the guild master ("<Guild> Officer (2)").'],
                        disabled = function()
                            local settings = playerText:Settings()
                            return not settings.enabled or not settings.guildLine
                        end,
                    },
                    faction = {
                        type = "select",
                        order = 90,
                        name = L["Faction line"],
                        desc = L['The "Alliance" / "Horde" line.'],
                        values = {
                            SHOW = L["Show"],
                            OWN = L["Hide if it is your own faction"],
                            HIDE = L["Hide"],
                        },
                        sorting = { "SHOW", "OWN", "HIDE" },
                    },
                },
            },
            RaidIcon = {
                type = "group",
                feature = true,
                name = L["Raid target icon"],
                desc = L["Shows the unit's raid target marker (skull, cross, ...) in front of its name."],
                order = 23,
                settings = function()
                    return raidIcon:Settings()
                end,
                toggled = function()
                    raidIcon:Refresh()
                end,
                changed = function()
                    raidIcon:SettingsChanged()
                end,
                args = {},
            },
            StatusTags = {
                type = "group",
                feature = true,
                name = L["Status tags"],
                desc = L["Adds a player's state behind the name, e.g. <AFK> or <Dead>."],
                order = 22,
                settings = function()
                    return statusTags:Settings()
                end,
                toggled = function()
                    statusTags:Refresh()
                end,
                changed = function()
                    statusTags:SettingsChanged()
                end,
                args = {
                    afk = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["<AFK> and <DND>"],
                    },
                    offline = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = L["<Offline>"],
                    },
                    dead = {
                        type = "toggle",
                        order = 30,
                        width = "full",
                        name = L["<Dead> and <Ghost>"],
                    },
                    pvp = {
                        type = "toggle",
                        order = 40,
                        width = "full",
                        name = L["<PvP>"],
                        desc = L["For players flagged for PvP."],
                    },
                    hidePvpLine = {
                        type = "toggle",
                        order = 50,
                        width = "full",
                        name = L['Hide the "PvP" line'],
                        desc = L["The line the game adds for players flagged for PvP."],
                    },
                },
            },
            TappedName = {
                type = "group",
                feature = true,
                name = L["Tapped mobs"],
                desc = L["Shows the name of a mob another player has tapped (no loot or experience for you) in grey."],
                order = 24,
                settings = function()
                    return tappedName:Settings()
                end,
                toggled = function()
                    tappedName:Refresh()
                end,
                changed = function()
                    tappedName:SettingsChanged()
                end,
                args = {},
            },
            TargetedBy = {
                type = "group",
                feature = true,
                name = L["Targeted by"],
                desc = L["Lists the members of your group or raid that target the unit."],
                order = 26,
                settings = function()
                    return targetedBy:Settings()
                end,
                toggled = function()
                    targetedBy:Refresh()
                end,
                changed = function()
                    targetedBy:SettingsChanged()
                end,
                args = {
                    names = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Names"],
                        desc = L["Lists who targets the unit, in class color; off shows only how many."],
                    },
                    you = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = L["Count yourself"],
                    },
                },
            },
            TargetLine = {
                type = "group",
                feature = true,
                name = L["Target"],
                desc = L['Adds what the unit is targeting as "T: Name" to its tooltip.'],
                order = 25,
                settings = function()
                    return targetLine:Settings()
                end,
                toggled = function()
                    targetLine:Refresh()
                end,
                changed = function()
                    targetLine:SettingsChanged()
                end,
                args = {
                    you = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L[">>YOU<< for you"],
                        desc = L['Shows "T: >>YOU<<" when the unit targets you.'],
                    },
                },
            },
            UnitBorder = {
                type = "group",
                feature = true,
                name = L["Border color"],
                desc = L['Colors the border of unit tooltips by the unit. Works with the game\'s border and with "Border and background".'],
                order = 35,
                settings = function()
                    return unitBorder:Settings()
                end,
                toggled = function()
                    unitBorder:Refresh()
                end,
                changed = function()
                    unitBorder:SettingsChanged()
                end,
                args = {
                    players = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Players in class color"],
                    },
                    npcs = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = L["NPCs in reaction color"],
                        desc = L["Hostile red, neutral yellow, friendly green."],
                    },
                    tapped = {
                        type = "toggle",
                        order = 30,
                        width = "full",
                        name = L["Tapped mobs in grey"],
                        desc = L["Mobs another player has tapped, which give you no loot or experience."],
                    },
                },
            },
        },
    },
}
