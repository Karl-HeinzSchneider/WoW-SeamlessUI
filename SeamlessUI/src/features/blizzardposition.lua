---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local base = app.core:GetFramePositionService()
---@class SeamlessUI.BlizzardPosition : SeamlessCore.FramePosition
local position = setmetatable({}, { __index = base })
app.blizzardPosition = position

-- The native percentage setting each system offers as its size; every other system uses "Size"
-- (Enum.EditMode<System>Setting.Size) when it has one. Systems without one show Scale disabled.
local scaleSettings = {
    UnitFrame = "FrameSize",
    ActionBar = "IconSize",
    AuraFrame = "IconSize",
    CastBar = "BarSize",
    SwingTimer = "Scale",
}
-- These objects are created by the default client even when their unit is absent.
-- UIParent stays first; the remaining display names are alphabetical.
local anchorFrames = {
    { value = "UIParent", text = L["UIParent"] },
    { value = "FocusFrame", text = L["Focus frame"] },
    { value = "Minimap", text = L["Minimap"] },
    { value = "PlayerFrame", text = L["Player frame"] },
    { value = "TargetFrame", text = L["Target frame"] },
}

local function sortAnchorFrames(a, b)
    if a.value == "UIParent" then
        return b.value ~= "UIParent"
    end
    if b.value == "UIParent" then
        return false
    end
    if a.text == b.text then
        return a.value < b.value
    end
    return a.text < b.text
end

local function getAnchorFrames()
    local entries, seen = {}, {}
    for _, entry in ipairs(anchorFrames) do
        entries[#entries + 1] = entry
        seen[entry.value] = true
    end
    for _, entry in ipairs(app.blizzardEditMode:GetAnchorTargets()) do
        if not seen[entry.value] then
            entries[#entries + 1] = entry
            seen[entry.value] = true
        end
    end
    table.sort(entries, sortAnchorFrames)
    return entries
end

local function anchorFrameLabel(name)
    for _, entry in ipairs(getAnchorFrames()) do
        if entry.value == name then
            return entry.text
        end
    end
    -- Reflect existing layouts without adding arbitrary frames to the selector.
    return name or L["Unknown"]
end

function position:GetAnchorFrames(frame)
    local entries = {}
    for _, entry in ipairs(getAnchorFrames()) do
        if base:IsValidAnchorTarget(_G[entry.value], frame) then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

function position:CanEdit(system)
    local selected, spec = app.blizzardEditMode:GetSelectedFrame()
    return selected == system
        and spec ~= nil
        and app.db.profile.blizzardEditMode.frames[spec.key].addPosition
        and base:CanEdit(system)
end

---The native setting the Scale row edits for the selected frame, or nil when it has none.
---@return number?
function position:GetScaleSetting(system)
    local selected, spec = app.blizzardEditMode:GetSelectedFrame()
    if selected ~= system or not spec or not spec.system then
        return nil
    end
    local settings = Enum["EditMode" .. spec.system .. "Setting"]
    return settings and settings[scaleSettings[spec.system] or "Size"]
end

---Scale in the custom settings panel's units (1 = 100 %), its range and the setting behind it.
---Without an editable setting it reports the frame's own scale with the panel's default range.
---@return number value, number min, number max, number step, number? setting
function position:ReadScale(system)
    local setting = self:GetScaleSetting(system)
    local value = setting and base:ReadSetting(system, setting)
    local min, max, step
    if value then
        min, max, step = base:GetSettingRange(system, setting)
    end
    if not value or not min or not max then
        return system and system.GetScale and system:GetScale() or 1, 0.5, 2, 0.01, nil
    end
    return value / 100, min / 100, max / 100, (step or 1) / 100, setting
end

function position:ApplyScale(system, value)
    local _, min, max, step, setting = self:ReadScale(system)
    value = tonumber(value)
    if not setting or not value or value ~= value or value < min or value > max then
        return false, L["Invalid value"]
    end
    -- Snap to the native slider's steps, in its whole-percent units.
    local percent = math.floor((min + math.floor((value - min) / step + 0.5) * step) * 100 + 0.5)
    return base:ApplySetting(system, setting, percent)
end

---The Position section for the selected system, drawn by Core's row renderer. The same section is
---returned until the selection changes, so a refusal message stays with its frame.
---@return SeamlessCore.EditModeSection
function position:GetSection(system)
    if self.section and self.sectionSystem == system then
        return self.section
    end
    self.sectionSystem = system
    self.section = app.core:CreateEditModePositionSection("position", {
        frame = system,
        isCurrent = function()
            return system == app.blizzardEditMode:GetSelectedFrame()
        end,
        canEdit = function()
            return position:CanEdit(system)
        end,
        read = function()
            return position:Read(system)
        end,
        apply = function(values)
            return position:Apply(system, values)
        end,
        readScale = function()
            return position:ReadScale(system)
        end,
        applyScale = function(value)
            return position:ApplyScale(system, value)
        end,
        anchorFrames = getAnchorFrames,
        anchorFrameText = anchorFrameLabel,
        isValidTarget = function(target)
            return base:IsValidAnchorTarget(target, system)
        end,
        hasChanges = function()
            return position:HasChanges(system)
        end,
        revert = function()
            return position:Revert(system)
        end,
    })
    return self.section
end
