---@type string, SeamlessUnitframes
local _, app = ...

local log = app.logger
local addon = app.addon
local unitFrames = app.unitFrames

-- Colors the health bars of the game's unit frames by class or by reaction, chosen per unit frame
-- (profile.unitFrames[key].healthBarColor). The bar's green fill atlas is swapped for its white
-- "-Status" variant (the one the game tints for heal prediction), and the bar color tints that.
---@class SeamlessUnitframes.HealthColor : AceModule, AceEvent-3.0
local module = {}
app.healthColor = addon:NewModule("HealthColor", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.HealthColor]]

-- The choices of profile.unitFrames[key].healthBarColor; the labels are in options.lua.
---@alias SeamlessUnitframes.HealthBarColor "default"|"class"|"reaction"|"classReaction"

-- The fields UnitFrame_Initialize puts on a unit frame's health bar.
---@class SeamlessUnitframes.HealthColor.HealthBar : StatusBar
---@field unit string?
---@field unitFrame Frame?
---@field lockColor boolean?  # the game never recolors the bar; its atlas carries the color

local STATUS_SUFFIX = "-Status"
local STATUS_SUFFIX_LOWER = STATUS_SUFFIX:lower()
-- What the target frame shows for a mob someone else tagged.
local TAP_DENIED_COLOR = CreateColor(0.5, 0.5, 0.5)
-- Reused for every UnitSelectionColor result; read right away by Apply.
local reactionColor = CreateColor(0, 0, 0)

-- Every health bar seen (its texture is hooked once) with its unit frame key, and the ones
-- showing our color now.
---@type table<SeamlessUnitframes.HealthColor.HealthBar, string>
local known = {}
---@type table<SeamlessUnitframes.HealthColor.HealthBar, true>
local colored = {}
-- Health bar atlas -> its white variant, or false when there is none.
---@type table<string, string|false>
local statusAtlases = {}
local settingAtlas = false

---@param atlas string
local function IsStatusAtlas(atlas)
    return atlas:lower():sub(-#STATUS_SUFFIX) == STATUS_SUFFIX_LOWER
end

-- The white variant of a health bar atlas, or nil when the game has none (e.g. the minus-mob bar).
---@param atlas string
---@return string?
local function StatusAtlas(atlas)
    if IsStatusAtlas(atlas) then
        return atlas
    end
    local status = statusAtlases[atlas]
    if status == nil then
        local candidate = atlas .. STATUS_SUFFIX
        status = C_Texture.GetAtlasInfo(candidate) and candidate or false
        statusAtlases[atlas] = status
    end
    return status or nil
end

---@param texture Texture
---@param atlas string
local function SetAtlas(texture, atlas)
    settingAtlas = true
    local applied = app.legacyLayout:SetHealthAtlas(texture, atlas)
    settingAtlas = false
    return applied
end

-- False for nil and for a secret value (the client hides a unit's identity in some situations).
local function Readable(value)
    return (not canaccessvalue or canaccessvalue(value)) and value ~= nil
end

---@param unit string
---@return ColorMixin?
local function ClassColor(unit)
    if not UnitIsPlayer(unit) then
        return nil
    end
    local _, class = UnitClass(unit)
    return Readable(class) and RAID_CLASS_COLORS[class] or nil
end

-- The reaction color the game uses for units (the target frame's name background, nameplates):
-- red hostile, yellow neutral, green friendly. Not FACTION_BAR_COLORS: those are the muted
-- reputation bar colors.
---@param unit string
---@return ColorMixin?
local function ReactionColor(unit)
    if not UnitPlayerControlled(unit) and UnitIsTapDenied(unit) then
        return TAP_DENIED_COLOR
    end
    local r, g, b = UnitSelectionColor(unit)
    if not Readable(r) then
        return nil
    end
    reactionColor:SetRGB(r, g, b)
    return reactionColor
end

-- The color the game gives a health bar (see UnitFrameHealthBar_Update).
---@param bar SeamlessUnitframes.HealthColor.HealthBar
local function DefaultColor(bar)
    if bar.lockColor then
        return 1, 1, 1
    elseif bar.unit and not UnitIsConnected(bar.unit) then
        return 0.5, 0.5, 0.5
    end
    return 0, 1, 0
end

-- Our color for the bar, or nil to leave it to the game.
---@param bar SeamlessUnitframes.HealthColor.HealthBar
---@param key string
---@return ColorMixin?
local function BarColor(bar, key)
    local mode = app.db.profile.unitFrames[key].healthBarColor
    local unit = bar.unit
    if mode == "default" or not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
        return nil
    end
    -- A pet has no class; it takes its owner's. In a vehicle the pet frame shows the player.
    local classUnit = key == "pet" and "player" or unit
    if mode == "class" then
        return ClassColor(classUnit)
    elseif mode == "reaction" then
        return ReactionColor(unit)
    end
    return ClassColor(classUnit) or ReactionColor(unit)
end

---@param bar SeamlessUnitframes.HealthColor.HealthBar
---@param key string
local function Apply(bar, key)
    local texture = bar:GetStatusBarTexture()
    local atlas = texture and app.legacyLayout:GetAtlas(texture)
    if not atlas or atlas == "" then
        return
    end

    local color = BarColor(bar, key)
    local statusAtlas = color and StatusAtlas(atlas)
    if color and statusAtlas then
        if atlas ~= statusAtlas and not SetAtlas(texture, statusAtlas) then
            return
        end
        bar:SetStatusBarColor(color:GetRGB())
        colored[bar] = true
    elseif colored[bar] then
        -- Only undo what this module did, so a bar it never colored is left alone.
        if IsStatusAtlas(atlas) and not SetAtlas(texture, atlas:sub(1, -#STATUS_SUFFIX - 1)) then
            return
        end
        colored[bar] = nil
        bar:SetStatusBarColor(DefaultColor(bar))
    end
end

-- Colors one health bar if it belongs to a unit frame in app.unitFrames.
---@param bar StatusBar?
local function Update(bar)
    ---@cast bar SeamlessUnitframes.HealthColor.HealthBar?
    local key = bar and unitFrames:KeyOf(bar.unitFrame)
    if not key then
        return
    end
    ---@cast bar SeamlessUnitframes.HealthColor.HealthBar
    if not known[bar] then
        known[bar] = key
        -- The game swaps the fill atlas on its own (target classification, vehicles, party art);
        -- put the white one back each time.
        hooksecurefunc(bar:GetStatusBarTexture(), "SetAtlas", function()
            if not settingAtlas then
                Apply(bar, key)
            end
        end)
    end
    Apply(bar, key)
end

local function ApplyAll()
    for bar, key in pairs(known) do
        Apply(bar, key)
    end
end

function module:OnInitialize()
    -- Every unit frame runs this on a unit change and on max health changes.
    hooksecurefunc("UnitFrameHealthBar_Update", Update)
end

function module:OnEnable()
    -- A reaction changes without a health update: PvP flags, a mob turning hostile, tapping.
    self:RegisterEvent("UNIT_FACTION", ApplyAll)
    self:Refresh()
end

-- Recolors every health bar, after a setting changed.
function module:Refresh()
    for _, frame in ipairs(unitFrames:All()) do
        Update(frame.healthbar)
    end
    -- Party frames are pooled and may have been swapped; recolor every bar ever seen as well.
    ApplyAll()
    log:debug("Health bar colors refreshed")
end

function module:OnProfileRefresh()
    self:Refresh()
end
