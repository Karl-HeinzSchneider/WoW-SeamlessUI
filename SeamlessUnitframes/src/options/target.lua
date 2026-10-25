---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local key = "target"
local entry = app.unitFrames:Get(key)
local function changed()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeSystemOptions()
end
local healthBarColorDesc =
    L["Default: the game's green.\nClass: players in their class color, NPCs keep the default.\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob someone else tagged.\nClass, reaction for NPCs: both."]

local function questIcon()
    return app.db.profile.targetQuestIcon
end
---@type SeamlessCore.SettingsPage
app.optionPages.target = {
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
                target = {
                    healthBarColor = "classReaction",
                    nameDisplay = "full",
                    classIcon = false,
                    hidePvPIcon = false,
                },
            },
            targetQuestIcon = { enabled = false, scale = 1.7, x = -30, y = 25 },
        },
    },
    config = {
        editModeFrame = function()
            return TargetFrame
        end,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Target"],
        order = 30,
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
                    target_nameDisplay = {
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
                    target_classIcon = {
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
                    target_healthBarColor = {
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
                    target_hidePvPIcon = {
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
                    threatPercentage = {
                        type = "toggle",
                        order = 50,
                        name = L["Threat percentage"],
                        desc = L["Shows the game's threat percentage badge above the target frame. This client-wide game setting also affects other frames that support it."],
                        get = function()
                            return GetCVarBool("threatShowNumeric")
                        end,
                        set = function(_, value)
                            SetCVar("threatShowNumeric", value and "1" or "0")
                            changed()
                        end,
                    },
                    questIcon = {
                        type = "group",
                        inline = true,
                        order = 60,
                        name = L["Quest icon"],
                        args = {
                            questIcon_enabled = {
                                type = "toggle",
                                order = 10,
                                name = L["Quest icon"],
                                desc = L["Shows a slay icon on the target frame for unfinished kill objectives, or a loot icon for other unfinished quest objectives the target's tooltip reports."],
                                get = function()
                                    return questIcon().enabled
                                end,
                                set = function(_, value)
                                    questIcon().enabled = value
                                    app.targetQuestIcon:OnProfileRefresh()
                                    changed()
                                end,
                            },
                            questIcon_scale = {
                                type = "range",
                                order = 20,
                                name = L["Scale"],
                                min = 0.5,
                                max = 3,
                                step = 0.1,
                                disabled = function()
                                    return not questIcon().enabled
                                end,
                                get = function()
                                    return questIcon().scale
                                end,
                                set = function(_, value)
                                    questIcon().scale = math.floor(value * 10 + 0.5) / 10
                                    app.targetQuestIcon:ApplyLayout()
                                    changed()
                                end,
                            },
                            questIcon_x = {
                                type = "range",
                                order = 30,
                                name = L["X offset"],
                                min = -150,
                                max = 150,
                                step = 1,
                                disabled = function()
                                    return not questIcon().enabled
                                end,
                                get = function()
                                    return questIcon().x
                                end,
                                set = function(_, value)
                                    questIcon().x = value
                                    app.targetQuestIcon:ApplyLayout()
                                    changed()
                                end,
                            },
                            questIcon_y = {
                                type = "range",
                                order = 40,
                                name = L["Y offset"],
                                min = -100,
                                max = 100,
                                step = 1,
                                disabled = function()
                                    return not questIcon().enabled
                                end,
                                get = function()
                                    return questIcon().y
                                end,
                                set = function(_, value)
                                    questIcon().y = value
                                    app.targetQuestIcon:ApplyLayout()
                                    changed()
                                end,
                            },
                        },
                    },
                },
            },
        },
    },
}
