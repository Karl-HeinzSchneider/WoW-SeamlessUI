---@type string, SeamlessUnitframes
local appName, app = ...

---@class SeamlessUnitframes.Options : AceModule, AceEvent-3.0
local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.Options]]

local healthBarColors = {
    { "default", "Default" },
    { "class", "Class" },
    { "reaction", "Reaction" },
    { "classReaction", "Class, reaction for NPCs" },
}

---@param panel SeamlessCore.SettingsPanel
---@param entry SeamlessUnitframes.UnitFrame
local function UnitFrameOptions(panel, entry)
    local function visible()
        return app.unitFrames:Exists(entry)
    end
    local description = "Default: the game's green."
        .. "\nClass: players in their class color, NPCs keep the default."
        .. "\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob someone else tagged."
        .. "\nClass, reaction for NPCs: both."
    if entry.key == "pet" then
        description = description .. "\n\nA pet takes its owner's class color."
    end
    local defaults = app.dbDefaults.profile.unitFrames
    local default = (defaults[entry.key] or defaults["**"]).healthBarColor
    panel:Dropdown({
        id = entry.key .. ".healthBarColor",
        name = entry.name .. " health bar color",
        tooltip = description,
        default = default,
        get = function()
            return app.db.profile.unitFrames[entry.key].healthBarColor
        end,
        set = function(value)
            app.db.profile.unitFrames[entry.key].healthBarColor = value
            app.healthColor:Refresh()
        end,
        options = healthBarColors,
        shown = visible,
        tags = { entry.name, "class", "reaction", "health" },
    })
    if entry.key == "target" then
        panel:Checkbox({
            id = "target.threatPercentage",
            name = "Target threat percentage",
            tooltip = "Show the game's threat percentage badge above the target frame. This client-wide setting also affects other stock frames that support it.",
            default = GetCVarDefault("threatShowNumeric") == "1",
            get = function()
                return GetCVarBool("threatShowNumeric")
            end,
            set = function(value)
                SetCVar("threatShowNumeric", value and "1" or "0")
            end,
            shown = visible,
            tags = { "target", "threat", "numeric" },
        })
    end
end

---@param panel SeamlessCore.SettingsPanel
local function TargetQuestIconOptions(panel)
    local defaults = app.dbDefaults.profile.targetQuestIcon
    local function enabled()
        return app.db.profile.targetQuestIcon.enabled
    end
    panel:Header("Target quest icon")
    panel:Checkbox({
        id = "targetQuestIcon.enabled",
        name = "Quest icon on target frame",
        tooltip = "Show a slay icon for unfinished kill objectives or a loot icon for other unfinished quest objectives reported by the target's tooltip.",
        default = defaults.enabled,
        get = enabled,
        set = function(value)
            app.db.profile.targetQuestIcon.enabled = value
            app.targetQuestIcon:OnProfileRefresh()
        end,
    })
    for _, spec in ipairs({
        { key = "scale", name = "Target quest icon scale", min = 0.5, max = 3, step = 0.1 },
        { key = "x", name = "Target quest icon X offset", min = -150, max = 150, step = 1 },
        { key = "y", name = "Target quest icon Y offset", min = -100, max = 100, step = 1 },
    }) do
        local key = spec.key
        panel:Slider({
            id = "targetQuestIcon." .. key,
            name = spec.name,
            min = spec.min,
            max = spec.max,
            step = spec.step,
            default = defaults[key],
            get = function()
                return app.db.profile.targetQuestIcon[key]
            end,
            set = function(value)
                app.db.profile.targetQuestIcon[key] = value
                app.targetQuestIcon:ApplyLayout()
            end,
            enabled = enabled,
            dependencies = { "targetQuestIcon.enabled" },
        })
    end
end

function module:OnInitialize()
    app.core:RegisterOptions(appName, "Unit Frames", function(panel)
        panel:Header("Health bars")
        for _, entry in ipairs(app.unitFrames.list) do
            UnitFrameOptions(panel, entry)
        end
        TargetQuestIconOptions(panel)
        panel:Profiles(app.db)
    end)
end

function module:OnEnable()
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        if name:lower() == "threatshownumeric" then
            self:Refresh()
        end
    end)
end

function module:Open()
    app.core:OpenOptions(appName)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
end

function module:OnProfileRefresh()
    self:Refresh()
end
