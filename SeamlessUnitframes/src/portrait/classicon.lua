---@type string, SeamlessUnitframes
local _, app = ...

local addon = app.addon
local unitFrames = app.unitFrames

-- Shows a player character's class icon instead of the portrait, chosen per unit frame
-- (profile.unitFrames[key].classIcon). NPCs keep their portrait. The client can do this for every
-- frame at once (the ReplaceMyPlayerPortrait/ReplaceOtherPlayerPortraits settings); this does it
-- per frame, with the same class atlas.
---@class SeamlessUnitframes.ClassIcon : AceModule
local module = {}
app.classIcon = addon:NewModule("ClassIcon", module) --[[@as SeamlessUnitframes.ClassIcon]]

-- The frames whose portrait shows a class icon we set.
---@type table<Frame, boolean>
local replaced = {}
local previewed = {}

-- False for nil and for a secret value (the client hides a unit's identity in some situations).
local function Readable(value)
    return (not canaccessvalue or canaccessvalue(value)) and value ~= nil
end

---@param unit string
---@return string?
local function ClassAtlas(unit)
    local isPlayer = UnitIsPlayer(unit)
    if not (Readable(isPlayer) and isPlayer) then
        return nil
    end
    local _, class = UnitClass(unit)
    if not Readable(class) then
        return nil
    end
    return GetClassAtlas(class)
end

---@param frame Frame
---@param key string
local function Apply(frame, key)
    local portrait, unit = frame.portrait, frame.unit
    if not (Readable(portrait) and portrait and Readable(unit) and unit) then
        return
    end
    local character = app.previewCharacters and app.previewCharacters:Get(frame, key)
    if character then
        if character.displayTexture and not app.db.profile.unitFrames[key].classIcon then
            portrait:SetTexture(character.displayTexture)
            portrait:SetTexCoord(0, 1, 0, 1)
        elseif character.class then
            portrait:SetAtlas(GetClassAtlas(character.class))
        end
        previewed[frame] = true
        return
    end
    if previewed[frame] then
        previewed[frame] = nil
        replaced[frame] = nil
        portrait:SetTexCoord(0, 1, 0, 1)
        local nativeAtlas = UnitFrame_ShouldReplacePortrait
            and UnitFrame_ShouldReplacePortrait(frame)
            and ClassAtlas(unit)
        if nativeAtlas then
            portrait:SetAtlas(nativeAtlas)
        else
            SetPortraitTexture(portrait, unit, frame.disablePortraitMask)
        end
    end
    local atlas = addon:IsEnabled() and app.db.profile.unitFrames[key].classIcon and ClassAtlas(unit)
    if atlas then
        portrait:SetAtlas(atlas)
        replaced[frame] = true
    elseif replaced[frame] then
        replaced[frame] = nil
        -- Leave the class icon when the client's own setting shows one here.
        if not (UnitFrame_ShouldReplacePortrait and UnitFrame_ShouldReplacePortrait(frame) and ClassAtlas(unit)) then
            SetPortraitTexture(portrait, unit, frame.disablePortraitMask)
        end
    end
end

---@param frame Frame
local function Update(frame)
    local key = unitFrames:KeyOf(frame)
    if key then
        -- The game just set its own portrait.
        replaced[frame] = nil
        previewed[frame] = nil
        Apply(frame, key)
    end
end

function module:OnInitialize()
    -- Every unit frame sets its portrait here: on a unit change and on portrait updates.
    hooksecurefunc("UnitFramePortrait_Update", Update)
end

function module:ApplyPreview(frame, key)
    Apply(frame, key)
end

function module:OnEnable()
    self:Refresh()
end

function module:OnDisable()
    self:Refresh()
end

-- Reapplies every portrait, after a setting changed.
function module:Refresh()
    for _, frame in ipairs(unitFrames:All()) do
        local key = unitFrames:KeyOf(frame)
        if key then
            Apply(frame, key)
        end
    end
end

function module:OnProfileRefresh()
    self:Refresh()
end
