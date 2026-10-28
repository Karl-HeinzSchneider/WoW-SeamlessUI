---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local key = "player"
local entry = app.unitFrames:Get(key)
local function changed()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeSystemOptions()
end
local healthBarColorDesc =
    L["Default: the game's green.\nClass: players in their class color, NPCs keep the default.\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob someone else tagged.\nClass, reaction for NPCs: both."]

---@type SeamlessCore.SettingsPage
app.optionPages.player = {
    tooltip = function(path)
        local name, defaults = path[#path], app.dbDefaults.profile
        if name == "threatPercentage" then
            return app.core:GetCVarOptionInfo("threatShowNumeric")
        end
        local questKey = name:match("^questIcon_(.+)$")
        if questKey then
            return defaults.targetQuestIcon[questKey]
        end
        local field = name:match("^[^_]+_(.+)$")
        return defaults.unitFrames[path[1]][field]
    end,
    defaults = {
        profile = {
            unitFrames = {
                player = {
                    healthBarColor = "class",
                    nameDisplay = "full",
                    classIcon = false,
                    hidePvPIcon = false,
                    portraitDragon = "none",
                },
            },
        },
    },
    config = {
        editModeFrame = function()
            return PlayerFrame
        end,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Player"],
        order = 10,
        hidden = function()
            return not app.unitFrames:Exists(entry)
        end,
        args = {
            position = app.UnitFramePositionOptions(entry),
            style = {
                type = "group",
                inline = true,
                order = 20,
                name = L["Style"],
                args = {
                    player_portraitDragon = {
                        order = 25,
                        type = "select",
                        name = L["Portrait dragon"],
                        values = { none = L["None"], elite = L["Elite"], rare = L["Rare"], boss = L["Boss"] },
                        sorting = { "none", "elite", "rare", "boss" },
                        get = function()
                            return app.db.profile.unitFrames[key].portraitDragon
                        end,
                        set = function(_, value)
                            app.db.profile.unitFrames[key].portraitDragon = value
                            app.portraitDragon:Refresh()
                            changed()
                        end,
                    },
                    player_nameDisplay = {
                        order = 10,
                        type = "select",
                        name = L["Name display"],
                        desc = L["Shortens the names of player characters. NPCs keep their name.\nFull name: the game's name, first name and surname.\nFirst name only: without the surname.\nSurname only: the surname, or the first name of a character without one."],
                        values = { full = L["Full name"], first = L["First name only"], last = L["Surname only"] },
                        sorting = { "full", "first", "last" },
                        get = function()
                            return app.db.profile.unitFrames[key].nameDisplay
                        end,
                        set = function(_, value)
                            app.db.profile.unitFrames[key].nameDisplay = value
                            app.nameDisplay:Refresh()
                            changed()
                        end,
                    },
                    player_classIcon = {
                        order = 20,
                        type = "toggle",
                        name = L["Class icon"],
                        desc = L["Shows a player character's class icon instead of the portrait. NPCs keep their portrait."],
                        get = function()
                            return app.db.profile.unitFrames[key].classIcon
                        end,
                        set = function(_, value)
                            app.db.profile.unitFrames[key].classIcon = value
                            app.classIcon:Refresh()
                            changed()
                        end,
                    },
                    player_healthBarColor = {
                        order = 30,
                        type = "select",
                        name = L["Health bar color"],
                        desc = key == "pet" and healthBarColorDesc .. L["\n\nA pet takes its owner's class color."]
                            or healthBarColorDesc,
                        values = {
                            default = L["Default"],
                            class = L["Class"],
                            reaction = L["Reaction"],
                            classReaction = L["Class, reaction for NPCs"],
                        },
                        sorting = { "default", "class", "reaction", "classReaction" },
                        get = function()
                            return app.db.profile.unitFrames[key].healthBarColor
                        end,
                        set = function(_, value)
                            app.db.profile.unitFrames[key].healthBarColor = value
                            app.healthColor:Refresh()
                            changed()
                        end,
                    },
                    player_hidePvPIcon = {
                        order = 40,
                        type = "toggle",
                        name = L["Hide PvP icon"],
                        desc = L["Hides the faction or free-for-all PvP icon on the frame."],
                        get = function()
                            return app.db.profile.unitFrames[key].hidePvPIcon
                        end,
                        set = function(_, value)
                            app.db.profile.unitFrames[key].hidePvPIcon = value
                            app.pvpIcon:Refresh()
                            changed()
                        end,
                    },
                },
            },
        },
    },
}
