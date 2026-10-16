---@type string, SeamlessUnitframes
local appName, app = ...

---@class SeamlessUnitframes.Options : AceModule, AceEvent-3.0
local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.Options]]

local healthBarColors = {
    default = "Default",
    class = "Class",
    reaction = "Reaction",
    classReaction = "Class, reaction for NPCs",
}
local healthBarColorOrder = { "default", "class", "reaction", "classReaction" }

local healthBarColorDesc = "Default: the game's green."
    .. "\nClass: players in their class color, NPCs keep the default."
    .. "\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob someone else tagged."
    .. "\nClass, reaction for NPCs: both."

-- One select per unit frame this client has, stored in profile.unitFrames[key].healthBarColor.
local function HealthBarColors()
    local args = {
        info = {
            type = "description",
            order = 0,
            name = "The color of each unit frame's health bar.\n",
        },
    }
    for i, entry in ipairs(app.unitFrames.list) do
        args[entry.key] = {
            type = "select",
            order = i,
            name = entry.name,
            desc = entry.key == "pet" and healthBarColorDesc .. "\n\nA pet takes its owner's class color."
                or healthBarColorDesc,
            values = healthBarColors,
            sorting = healthBarColorOrder,
            hidden = function()
                return not app.unitFrames:Exists(entry)
            end,
        }
    end
    return {
        type = "group",
        inline = true,
        order = 10,
        name = "Health bar colors",
        get = function(info)
            return app.db.profile.unitFrames[info[#info]].healthBarColor
        end,
        set = function(info, value)
            app.db.profile.unitFrames[info[#info]].healthBarColor = value
            app.healthColor:Refresh()
        end,
        args = args,
    }
end

local function TargetTab()
    local function questIconOff()
        return not app.db.profile.targetQuestIcon.enabled
    end
    local function slider(order, name, min, max, step)
        return { type = "range", order = order, name = name, min = min, max = max, step = step, disabled = questIconOff }
    end
    return {
        order = 10,
        name = "Target",
        args = {
            threat = {
                type = "group",
                inline = true,
                order = 10,
                name = "Threat",
                args = {
                    threatPercentage = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = "Threat percentage",
                        desc = "Shows the game's threat percentage badge above the target frame. This client-wide game setting also affects other frames that support it.",
                        descStyle = "inline",
                        get = function()
                            return GetCVarBool("threatShowNumeric")
                        end,
                        set = function(_, value)
                            SetCVar("threatShowNumeric", value and "1" or "0")
                        end,
                    },
                },
            },
            questIcon = {
                type = "group",
                inline = true,
                order = 20,
                name = "Quest icon",
                get = function(info)
                    return app.db.profile.targetQuestIcon[info[#info]]
                end,
                set = function(info, value)
                    local key = info[#info]
                    app.db.profile.targetQuestIcon[key] = value
                    if key == "enabled" then
                        app.targetQuestIcon:OnProfileRefresh()
                    else
                        app.targetQuestIcon:ApplyLayout()
                    end
                end,
                args = {
                    enabled = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = "Enable",
                        desc = "Shows a slay icon on the target frame for unfinished kill objectives, or a loot icon for other unfinished quest objectives the target's tooltip reports.",
                        descStyle = "inline",
                    },
                    scale = slider(20, "Scale", 0.5, 3, 0.1),
                    x = slider(30, "X offset", -150, 150, 1),
                    y = slider(40, "Y offset", -100, 100, 1),
                },
            },
        },
    }
end

function module:OnInitialize()
    app.core:RegisterOptions(appName, {
        title = "Unit Frames",
        general = {
            layout = {
                type = "select",
                order = 1,
                name = "Unit frame layout",
                desc = "Current leaves the game's layout unchanged. Legacy restores the exported pre-70425 artwork and layout. Changes made during combat apply when combat ends.",
                values = { current = "Current (70425)", legacy = "Legacy (before 70425)" },
                sorting = { "current", "legacy" },
                get = function()
                    return app.db.profile.layout
                end,
                set = function(_, value)
                    app.db.profile.layout = value
                    app.legacyLayout:Refresh()
                end,
            },
            healthBarColors = HealthBarColors(),
        },
        tabs = { target = TargetTab() },
        db = app.db,
    })
end

function module:OnEnable()
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        if name:lower() == "threatshownumeric" then
            self:Refresh()
        end
    end)
end

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
end
