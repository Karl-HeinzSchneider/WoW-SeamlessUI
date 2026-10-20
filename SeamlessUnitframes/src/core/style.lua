---@type string, SeamlessUnitframes
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The style settings of each unit frame, in one place: its tab in the options (options.lua) and the
-- Style section of its Edit Mode settings (editmode.lua) are both built from these rows, so they
-- write the same profile. Rows use the shape of Core's Edit Mode system options.

---@class SeamlessUnitframes.StyleGroup
---@field name string  # the inline group's heading in the options tab
---@field rows SeamlessCore.EditModeSystemOption[]

local healthBarColorOrder = { "default", "class", "reaction", "classReaction" }
local healthBarColorNames = {
    default = L["Default"],
    class = L["Class"],
    reaction = L["Reaction"],
    classReaction = L["Class, reaction for NPCs"],
}
local healthBarColors = {}
for _, value in ipairs(healthBarColorOrder) do
    healthBarColors[#healthBarColors + 1] = { text = healthBarColorNames[value], value = value }
end

local healthBarColorDesc =
    L["Default: the game's green.\nClass: players in their class color, NPCs keep the default.\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob someone else tagged.\nClass, reaction for NPCs: both."]

-- Slider steps of 0.1 arrive as 0.30000000000000004.
local function tenths(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function formatTenths(value)
    return ("%.1f"):format(value)
end

-- After any change: redraw the options and the Edit Mode window, whichever is showing.
local function changed()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeSystemOptions()
end

---@param key string
---@return SeamlessCore.EditModeSystemOption
local function HealthBarColor(key)
    return {
        key = key .. ".healthBarColor",
        type = "select",
        name = L["Health bar color"],
        desc = key == "pet" and healthBarColorDesc .. L["\n\nA pet takes its owner's class color."]
            or healthBarColorDesc,
        values = healthBarColors,
        get = function()
            return app.db.profile.unitFrames[key].healthBarColor
        end,
        set = function(value)
            app.db.profile.unitFrames[key].healthBarColor = value
            app.healthColor:Refresh()
            changed()
        end,
    }
end

local nameDisplays = {
    { text = L["Full name"], value = "full" },
    { text = L["First name only"], value = "first" },
    { text = L["Surname only"], value = "last" },
}

---@param key string
---@return SeamlessCore.EditModeSystemOption
local function NameDisplay(key)
    return {
        key = key .. ".nameDisplay",
        type = "select",
        name = L["Name display"],
        desc = L["Full name: the game's name, first name and surname.\nFirst name only: without the surname.\nSurname only: the surname, or the name of a unit without one, such as an NPC."],
        values = nameDisplays,
        get = function()
            return app.db.profile.unitFrames[key].nameDisplay
        end,
        set = function(value)
            app.db.profile.unitFrames[key].nameDisplay = value
            app.nameDisplay:Refresh()
            changed()
        end,
    }
end

---@return SeamlessUnitframes.StyleGroup[]
local function TargetGroups()
    local function questIcon()
        return app.db.profile.targetQuestIcon
    end
    local function questIconOff()
        return not questIcon().enabled
    end
    local function range(name, field, min, max, step)
        return {
            key = "questIcon." .. field,
            type = "range",
            name = name,
            min = min,
            max = max,
            step = step,
            format = step < 1 and formatTenths or nil,
            get = function()
                return questIcon()[field]
            end,
            set = function(value)
                questIcon()[field] = step < 1 and tenths(value) or value
                app.targetQuestIcon:ApplyLayout()
                changed()
            end,
            disabled = questIconOff,
        }
    end
    return {
        {
            name = L["Threat"],
            rows = {
                {
                    key = "threatPercentage",
                    type = "toggle",
                    name = L["Threat percentage"],
                    desc = L["Shows the game's threat percentage badge above the target frame. This client-wide game setting also affects other frames that support it."],
                    get = function()
                        return GetCVarBool("threatShowNumeric")
                    end,
                    set = function(value)
                        SetCVar("threatShowNumeric", value and "1" or "0")
                        changed()
                    end,
                },
            },
        },
        {
            name = L["Quest icon"],
            rows = {
                {
                    key = "questIcon.enabled",
                    type = "toggle",
                    name = L["Quest icon"],
                    desc = L["Shows a slay icon on the target frame for unfinished kill objectives, or a loot icon for other unfinished quest objectives the target's tooltip reports."],
                    get = function()
                        return questIcon().enabled
                    end,
                    set = function(value)
                        questIcon().enabled = value
                        app.targetQuestIcon:OnProfileRefresh()
                        changed()
                    end,
                },
                range(L["Scale"], "scale", 0.5, 3, 0.1),
                range(L["X offset"], "x", -150, 150, 1),
                range(L["Y offset"], "y", -100, 100, 1),
            },
        },
    }
end

-- Frames without an Edit Mode system of their own show their rows in this frame's Style section,
-- under these labels.
local linkedNames = {
    targettarget = {
        nameDisplay = L["Target of Target name display"],
        healthBarColor = L["Target of Target health bar color"],
    },
    focustarget = {
        nameDisplay = L["Target of Focus name display"],
        healthBarColor = L["Target of Focus health bar color"],
    },
}

---The style groups of one unit frame (a key of app.unitFrames.list).
---@param key string
---@return SeamlessUnitframes.StyleGroup[]
function app.StyleGroups(key)
    local groups = {
        { name = L["Name"], rows = { NameDisplay(key) } },
        { name = L["Health bar"], rows = { HealthBarColor(key) } },
    }
    if key == "target" then
        for _, group in ipairs(TargetGroups()) do
            groups[#groups + 1] = group
        end
    end
    return groups
end

---The rows of one frame's Edit Mode Style section: its own rows, then those of the frames linked
---to it (target of target under target), each linked row only while that frame exists.
---@param entry SeamlessUnitframes.UnitFrame
---@return SeamlessCore.EditModeSystemOption[]
function app.StyleOptions(entry)
    local rows = {}
    for _, group in ipairs(app.StyleGroups(entry.key)) do
        for _, row in ipairs(group.rows) do
            rows[#rows + 1] = row
        end
    end
    for _, linked in ipairs(app.unitFrames.list) do
        if linked.linkedTo == entry.key then
            local linkedRows = { NameDisplay(linked.key), HealthBarColor(linked.key) }
            linkedRows[1].name = linkedNames[linked.key].nameDisplay
            linkedRows[2].name = linkedNames[linked.key].healthBarColor
            for _, row in ipairs(linkedRows) do
                row.hidden = function()
                    return not app.unitFrames:Exists(linked)
                end
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end
