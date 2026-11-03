---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessCore.FramePosition
local position = {}
app.framePosition = position

function app.addon:GetFramePositionService()
    return position
end

local anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local validAnchors = {}
for _, point in ipairs(anchors) do
    validAnchors[point] = true
end
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

local function finite(value)
    return value and value == value and value > -math.huge and value < math.huge
end

-- Check anchors and ownership: anchoring to a descendant or to a frame whose
-- anchors lead back here would create a layout cycle.
local function dependsOn(frame, target, seen)
    if frame == target then
        return true
    end
    if not frame or seen[frame] then
        return false
    end
    seen[frame] = true
    if dependsOn(frame:GetParent(), target, seen) then
        return true
    end
    for index = 1, frame:GetNumPoints() do
        local _, relativeTo = frame:GetPoint(index)
        if relativeTo and dependsOn(relativeTo, target, seen) then
            return true
        end
    end
    return false
end

---Validate anchor ownership without accepting self, child or anchor cycles.
---@param target table?
---@param frame table
---@return boolean
function position:IsValidAnchorTarget(target, frame)
    return target ~= nil and not dependsOn(target, frame, {})
end

---@param frame table
---@return { value: string, text: string }[]
function position:GetAnchorFrames(frame)
    local entries, seen = {}, {}
    local function add(target, text)
        local name = target and target:GetName()
        if name and not seen[name] and self:IsValidAnchorTarget(target, frame) then
            seen[name] = true
            entries[#entries + 1] = { value = name, text = text or name }
        end
    end
    add(UIParent, L["UIParent"])
    for _, target in ipairs(EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames or {}) do
        add(target, target.GetSystemName and target:GetSystemName())
    end
    for _, entry in ipairs(anchorFrames) do
        add(_G[entry.value], entry.text)
    end
    local current = self:Read(frame)
    if current then
        add(_G[current.relativeTo])
    end
    table.sort(entries, sortAnchorFrames)
    return entries
end

local function pointPosition(frame, point)
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then
        return nil
    end
    local x = point:find("LEFT") and left or point:find("RIGHT") and right or (left + right) / 2
    local y = point:find("TOP") and top or point:find("BOTTOM") and bottom or (top + bottom) / 2
    local scale = frame:GetEffectiveScale()
    return x * scale, y * scale
end

local function round(value)
    return math.floor(value * 100 + 0.5) / 100
end

-- Managed containers and their unnamed layout children are implementation
-- details; report the named frame that places them instead.
local function isLayoutHelper(frame)
    return frame ~= UIParent and (not frame:GetName() or frame.AddManagedFrame ~= nil)
end

-- In default position, managed frames (Pet, cast bar, ...) and default action
-- bars are placed by the client's layout code, and their layout anchorInfo is a
-- placeholder such as CENTER of UIParent. Read the frame's live anchor instead,
-- in the same scale-independent units Edit Mode stores after a drag.
local function liveAnchor(system)
    local point, relativeTo, relativePoint, x, y = system:GetPoint(1)
    if not point then
        return nil
    end
    relativeTo = relativeTo or UIParent
    local target, seen = relativeTo, {}
    while isLayoutHelper(target) and not seen[target] do
        seen[target] = true
        local _, anchor = target:GetPoint(1)
        target = anchor or target:GetParent() or UIParent
    end
    if target ~= relativeTo then
        local fx, fy = pointPosition(system, point)
        local tx, ty = pointPosition(target, relativePoint)
        if not fx or not tx or not target:GetName() then
            return nil
        end
        local scale = system:GetEffectiveScale()
        x, y = (fx - tx) / scale, (fy - ty) / scale
    end
    local frameScale = system:GetScale()
    return {
        point = point,
        relativeTo = target:GetName(),
        relativePoint = relativePoint,
        offsetX = round(x * frameScale),
        offsetY = round(y * frameScale),
    }
end

function position:Read(system)
    if not system or not EditModeManagerFrame then
        return nil
    end
    local info = EditModeManagerFrame:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
    if not info or not info.anchorInfo then
        return nil
    end
    if not InCombatLockdown() and system.IsInDefaultPosition and system:IsInDefaultPosition() then
        local live = liveAnchor(system)
        if live then
            return live
        end
    end
    return CopyTable(info.anchorInfo)
end

-- The anchor the native "Reset To Default Position" button applies: the preset
-- layout's anchor for this system. Nil where the client lacks the preset API.
function position:GetDefault(system)
    local presets = EditModePresetLayoutManager
    if not system or not presets or not presets.GetDefaultSystemAnchorInfo then
        return nil
    end
    local ok, info = pcall(presets.GetDefaultSystemAnchorInfo, presets, system.system, system.systemIndex)
    return ok and type(info) == "table" and CopyTable(info) or nil
end

function position:IsDefault(system)
    return system ~= nil and system.IsInDefaultPosition ~= nil and system:IsInDefaultPosition() or false
end

function position:CanEdit(system)
    local manager = EditModeManagerFrame
    local override = LibStub("LibEditModeOverride-1.0")
    return system ~= nil
        and manager ~= nil
        and not InCombatLockdown()
        and not system.isLocked
        and not manager:IsActiveLayoutPreset()
        and not manager.overrideLayoutInfo
        and override:IsReady()
        and self:Read(system) ~= nil
end

-- Build an isolated save payload. When the player has dragged or changed native
-- frames, retain the current draft's systems instead of overwriting them with
-- the library's last-saved copy. This is an immediate save of the current layout;
-- it never writes back into Blizzard's draft, baseline or dirty flags.
local function layoutForSave(system)
    local layouts = C_EditMode.GetLayouts()
    local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    tAppendAll(presets, layouts.layouts)
    layouts.layouts = presets
    local layout = layouts.layouts[layouts.activeLayout]
    local manager = EditModeManagerFrame
    if manager:IsEditModeActive() and manager:HasActiveChanges() then
        layout.systems = CopyTable(manager:GetActiveLayoutInfo().systems)
    end
    for _, info in ipairs(layout.systems) do
        if info.system == system.system and info.systemIndex == system.systemIndex then
            return layouts, info
        end
    end
    error(L["This frame has no anchor in the active layout."])
end

local function hasPendingEdits()
    return EditModeManagerFrame:IsEditModeActive() and EditModeManagerFrame:HasActiveChanges()
end

function position:Apply(system, values, reset)
    if not self:CanEdit(system) then
        return false, L["Position editing is unavailable. Select an enabled frame in a custom layout."]
    end
    if not validAnchors[values.point] or not validAnchors[values.relativePoint] then
        return false, L["Choose a valid anchor point."]
    end
    local x, y = tonumber(values.offsetX), tonumber(values.offsetY)
    if not finite(x) or not finite(y) then
        return false, L["X and Y must be finite numbers."]
    end
    local relativeTo = type(values.relativeTo) == "string" and _G[values.relativeTo]
    if
        not relativeTo
        or type(relativeTo) ~= "table"
        or not relativeTo.IsObjectType
        or not relativeTo:IsObjectType("Frame")
    then
        return false, L["AnchorFrame must name an existing frame, such as UIParent."]
    end
    if dependsOn(relativeTo, system, {}) then
        return false, L["AnchorFrame would create an anchor cycle."]
    end
    local override = LibStub("LibEditModeOverride-1.0")
    local ok, err = pcall(function()
        -- The library owns a saved-layout copy. Never mirror it into Blizzard's draft,
        -- call native mutators or use ApplyChanges (which closes Edit Mode).
        override:LoadLayouts()
        if hasPendingEdits() or reset or system.systemInfo and system.systemInfo.anchorInfo2 then
            -- The library cannot load a draft or set default/secondary-anchor metadata.
            -- Edit only an isolated C save payload for these cases, like defaultlayout.lua.
            local layouts, info = layoutForSave(system)
            info.anchorInfo = {
                point = values.point,
                relativeTo = relativeTo:GetName(),
                relativePoint = values.relativePoint,
                offsetX = x,
                offsetY = y,
            }
            info.anchorInfo2 = nil
            info.isInDefaultPosition = reset == true
            C_EditMode.SaveLayouts(layouts)
        else
            override:ReanchorFrame(system, values.point, relativeTo, values.relativePoint, x, y)
            override:SaveOnly()
        end
    end)
    if not ok then
        return false, string.format(L["Could not set the anchor: %s"], tostring(err))
    end
    return true
end

-- Same result as the native button: the preset anchor, flagged as default
-- position so the client's layout code places managed frames again.
function position:ResetToDefault(system)
    local default = self:GetDefault(system)
    if not default then
        return false, L["This frame has no default position."]
    end
    return self:Apply(system, default, true)
end

local function settingDisplayInfo(system, setting)
    local map = system.settingDisplayInfoMap
    local manager = EditModeSettingDisplayInfoManager
    if not map and manager and manager.GetSystemSettingDisplayInfoMap then
        map = manager:GetSystemSettingDisplayInfoMap(system.system)
    end
    return map and map[setting]
end

-- An Edit Mode setting in its display units (Frame Size: 100 to 200), or nil
-- while the frame lacks it or Edit Mode hides it (Focus without Larger Frame).
function position:ReadSetting(system, setting)
    if not system or not system.HasSetting or not system:HasSetting(setting) then
        return nil
    end
    if system.ShouldShowSetting and not system:ShouldShowSetting(setting) then
        return nil
    end
    return system:GetSettingValue(setting)
end

---@return number? min, number? max, number? step In display units.
function position:GetSettingRange(system, setting)
    local info = system and settingDisplayInfo(system, setting)
    if info then
        return info.minValue, info.maxValue, info.stepSize
    end
end

function position:GetDefaultSetting(system, setting)
    local presets = EditModePresetLayoutManager
    if not system or not presets or not presets.GetDefaultSettingForSystem then
        return nil
    end
    local ok, raw = pcall(presets.GetDefaultSettingForSystem, presets, system.system, system.systemIndex, setting)
    if not ok or raw == nil then
        return nil
    end
    local info = settingDisplayInfo(system, setting)
    return info and info.ConvertValueForDisplay and info:ConvertValueForDisplay(raw) or raw
end

-- Save through the library; Blizzard refreshes from its native layout event.
function position:ApplySetting(system, setting, value)
    if not self:CanEdit(system) or self:ReadSetting(system, setting) == nil then
        return false, L["Position editing is unavailable. Select an enabled frame in a custom layout."]
    end
    local override = LibStub("LibEditModeOverride-1.0")
    local ok, err = pcall(function()
        local raw = system:ConvertSettingDisplayValueToRawValue(setting, value)
        override:LoadLayouts()
        override:SetFrameSetting(system, setting, raw)
        if hasPendingEdits() then
            local layouts, info = layoutForSave(system)
            local found
            for _, entry in ipairs(info.settings) do
                if entry.setting == setting then
                    entry.value = override:GetFrameSetting(system, setting)
                    found = true
                    break
                end
            end
            assert(found, L["Position editing is unavailable. Select an enabled frame in a custom layout."])
            C_EditMode.SaveLayouts(layouts)
        else
            override:SaveOnly()
        end
    end)
    if not ok then
        return false, string.format(L["Could not save the Edit Mode setting: %s"], tostring(err))
    end
    return true
end
