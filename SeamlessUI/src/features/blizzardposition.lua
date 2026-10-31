---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local base = app.core:GetFramePositionService()
---@class SeamlessUI.BlizzardPosition : SeamlessCore.FramePosition
local position = setmetatable({}, { __index = base })
app.blizzardPosition = position

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
        -- The preset position native Reset To Default Position applies.
        default = function(key)
            local values = base:GetDefault(system)
            return values and values[key]
        end,
    })
    return self.section
end
