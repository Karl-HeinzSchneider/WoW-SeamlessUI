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

local TAP_DENIED_COLOR = CreateColor(0.5, 0.5, 0.5)
local reactionColor = CreateColor(0, 0, 0)
local known, colored = {}, {}
local settingAtlas = false

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
    local isPlayer = UnitIsPlayer(unit)
    if not Readable(isPlayer) or not isPlayer then
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
    local controlled, denied = UnitPlayerControlled(unit), UnitIsTapDenied(unit)
    if Readable(controlled) and not controlled and Readable(denied) and denied then
        return TAP_DENIED_COLOR
    end
    local r, g, b = UnitSelectionColor(unit)
    if not Readable(r) or not Readable(g) or not Readable(b) then
        return nil
    end
    reactionColor:SetRGB(r, g, b)
    return reactionColor
end

-- The color the game gives a health bar (see UnitFrameHealthBar_Update).
---@param bar SeamlessUnitframes.HealthColor.HealthBar
local function DefaultColor(bar)
    if Readable(bar.lockColor) and bar.lockColor then
        return 1, 1, 1
    end
    if Readable(bar.unit) then
        local connected = UnitIsConnected(bar.unit)
        if Readable(connected) and not connected then
            return 0.5, 0.5, 0.5
        end
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
    if mode == "default" or not Readable(unit) then
        return nil
    end
    local exists, connected = UnitExists(unit), UnitIsConnected(unit)
    if not Readable(exists) or not exists or not Readable(connected) or not connected then
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
    if settingAtlas then
        return
    end
    local atlas, texture = app.legacyLayout:HealthAtlas(bar, key)
    if not atlas then
        return
    end
    local color = BarColor(bar, key)
    if color and app.legacyLayout:HasHealthStatus(atlas) then
        -- Reassert on native updates even if our own logical name is unchanged:
        -- the client may have just reset the underlying fill to green.
        if not SetAtlas(texture, atlas .. "-Status") then
            return
        end
        bar:SetStatusBarColor(color:GetRGB())
        colored[bar] = true
    elseif colored[bar] then
        if not SetAtlas(texture, atlas) then
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
    if not app.legacyLayout:CheckRegion(bar, "health update", { "GetStatusBarTexture", "SetStatusBarColor" }) then
        return
    end
    if not Readable(bar.unitFrame) then
        return
    end
    local key = unitFrames:KeyOf(bar.unitFrame)
    if not key then
        return
    end
    ---@cast bar SeamlessUnitframes.HealthColor.HealthBar
    if not known[bar] then
        known[bar] = key
        -- The game swaps the fill atlas on its own (target classification, vehicles, party art);
        -- put the white one back each time.
        local texture = bar:GetStatusBarTexture()
        if not app.legacyLayout:CheckRegion(texture, "health color hook", { "SetAtlas" }) then
            return
        end
        hooksecurefunc(texture, "SetAtlas", function()
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
        if Readable(frame.healthbar) and frame.healthbar then
            Update(frame.healthbar)
        end
    end
    -- Party frames are pooled and may have been swapped; recolor every bar ever seen as well.
    ApplyAll()
    log:debug("Health bar colors refreshed")
end

function module:OnProfileRefresh()
    self:Refresh()
end
