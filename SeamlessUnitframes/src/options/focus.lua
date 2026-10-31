---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local key = "focus"
local entry = app.unitFrames:Get(key)
local function changed()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeSystemOptions()
end
local healthBarColorDesc =
    L["Default: the game's green.\nClass: players in their class color, NPCs keep the default.\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob someone else tagged.\nClass, reaction for NPCs: both."]

local position, size = app.UnitFramePositionOptions(entry)
---@type SeamlessCore.SettingsPage
app.optionPages.focus = {
    tooltip = function(path)
        local name, defaults = path[#path], app.dbDefaults.profile
        if name == "layout" then
            return defaults.layout
        end
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
                focus = {
                    healthBarColor = "classReaction",
                    nameDisplay = "full",
                    classIcon = false,
                    hidePvPIcon = false,
                    hideNameBackground = false,
                    levelDisplay = "default",
                },
            },
        },
    },
    config = {
        editModeFrame = function()
            return FocusFrame
        end,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Focus"],
        order = 50,
        hidden = function()
            return not app.unitFrames:Exists(entry)
        end,
        args = {
            position = position,
            size = size,
            style = {
                type = "group",
                inline = true,
                order = 20,
                name = L["Style"],
                args = {
                    layout = app.UnitFrameLayoutOption(),
                    statusText = app.UnitFrameStatusTextOption(),
                    focus_nameDisplay = {
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
                    focus_hideNameBackground = {
                        order = 15,
                        type = "toggle",
                        name = L["Hide name background"],
                        desc = L["Hides the reaction-colored background behind the name on every skin."],
                        get = function()
                            return app.db.profile.unitFrames[key].hideNameBackground
                        end,
                        set = function(_, value)
                            app.db.profile.unitFrames[key].hideNameBackground = value
                            app.nameBackground:Refresh()
                            changed()
                        end,
                    },
                    focus_classIcon = {
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
                    focus_healthBarColor = {
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
                    focus_levelDisplay = {
                        order = 35,
                        type = "select",
                        name = L["Level display"],
                        desc = L["Sets the size of the level number and its circle background. Smaller uses 70% of the default size. Hidden also hides the high-level skull. Changes made during combat apply when combat ends."],
                        values = { default = L["Default"], smaller = L["Smaller"], hidden = L["Hidden"] },
                        sorting = { "default", "smaller", "hidden" },
                        get = function()
                            return app.db.profile.unitFrames[key].levelDisplay
                        end,
                        set = function(_, value)
                            app.db.profile.unitFrames[key].levelDisplay = value
                            app.levelDisplay:Refresh()
                            changed()
                        end,
                    },
                    focus_hidePvPIcon = {
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
