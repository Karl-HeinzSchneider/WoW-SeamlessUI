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

function module:OnInitialize()
    app.core:RegisterOptions(appName, "Unit Frames", function(panel)
        panel:Header("Health bars")
        for _, entry in ipairs(app.unitFrames.list) do
            UnitFrameOptions(panel, entry)
        end
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
