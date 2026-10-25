---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local key = "pet"
local entry = app.unitFrames:Get(key)
local function changed()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeSystemOptions()
end
local healthBarColorDesc =
    L["Default: the game's green.\nClass: players in their class color, NPCs keep the default.\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob someone else tagged.\nClass, reaction for NPCs: both."]

---@type SeamlessCore.SettingsPage
app.optionPages.pet = {
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
                pet = { healthBarColor = "class", nameDisplay = "full", classIcon = false, hidePvPIcon = false },
            },
        },
    },
    config = {
        editModeVisibility = function(value)
            local lib = LibStub("LibEditModeOverride-1.0")
            local setting = Enum.EditModeAccountSetting.ShowPetFrame
            if value ~= nil then
                lib:LoadLayouts()
                lib:SetGlobalSetting(setting, value and 1 or 0)
                lib:ApplyChanges()
            end
            return lib:GetGlobalSetting(setting) == 1
        end,
        editModeFrame = function()
            return PetFrame
        end,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Pet"],
        order = 20,
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
                    pet_healthBarColor = {
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
                },
            },
        },
    },
}
