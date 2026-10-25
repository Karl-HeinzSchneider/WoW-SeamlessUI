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

local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local function positionState(info)
    return info
        and {
            anchorInfo = info.anchorInfo and CopyTable(info.anchorInfo),
            anchorInfo2 = info.anchorInfo2 and CopyTable(info.anchorInfo2),
            isInDefaultPosition = info.isInDefaultPosition,
        }
end

function position:HasChanges(system)
    local info = EditModeManagerFrame:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
    return info ~= nil
        and system.savedSystemInfo ~= nil
        and not equal(positionState(info), positionState(system.savedSystemInfo))
end

-- Compare the actual draft as native dirty flags can miss addon-driven edits.
function position:HasSystemChanges(system)
    local info = EditModeManagerFrame:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
    return info ~= nil and system.savedSystemInfo ~= nil and not equal(info, system.savedSystemInfo)
end

function position:RevertSystem(system)
    if not self:CanEdit(system) or not self:HasSystemChanges(system) then
        return false
    end
    -- Reuse position validation before restoring native settings and dirty flags.
    if self:HasChanges(system) and not self:Revert(system) then
        return false
    end
    EditModeManagerFrame:RevertSystemChanges(system)
    if EditModeSystemSettingsDialog then
        EditModeSystemSettingsDialog:UpdateDialog(system)
    end
    return true
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

function position:Apply(system, values, restoreState)
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
    if restoreState and restoreState.anchorInfo2 then
        local second = restoreState.anchorInfo2
        local target = _G[second.relativeTo]
        if not target or dependsOn(target, system, {}) then
            return false, L["The previous secondary anchor is unavailable or would create a cycle."]
        end
    end
    local manager = EditModeManagerFrame
    local info = manager:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
    if not info or not info.anchorInfo then
        return false, L["This frame has no anchor in the active layout."]
    end
    local override = LibStub("LibEditModeOverride-1.0")
    local ok, err = pcall(function()
        -- Reload before every edit: another addon or a layout switch can change
        -- the override's shared cache. Never save that cache over the live draft.
        override:LoadLayouts()
        override:ReanchorFrame(system, values.point, relativeTo, values.relativePoint, x, y)
    end)
    if not ok then
        return false, string.format(L["Could not set the anchor: %s"], tostring(err))
    end
    -- ReanchorFrame operates on the library's saved-layout copy. Mirror the same
    -- anchor into the live draft so native Save/Revert include all pending edits.
    -- ApplySystemAnchor handles the frame's scale; UpdateSystem would replace its
    -- savedSystemInfo and break the native per-frame Revert button.
    info.anchorInfo = {
        point = values.point,
        relativeTo = relativeTo:GetName(),
        relativePoint = values.relativePoint,
        offsetX = x,
        offsetY = y,
    }
    info.anchorInfo2 = restoreState and restoreState.anchorInfo2 and CopyTable(restoreState.anchorInfo2) or nil
    info.isInDefaultPosition = false
    if restoreState then
        info.isInDefaultPosition = restoreState.isInDefaultPosition
    end
    system:ClearFrameSnap()
    system.systemInfo = info
    system:ApplySystemAnchor()
    -- Only clear the native dirty flag if the whole frame matches its baseline.
    -- Other settings on this frame and other frames must remain pending.
    system:SetHasActiveChanges(not equal(info, system.savedSystemInfo))
    manager:CheckForSystemActiveChanges()
    if manager:IsEditModeActive() then
        if EditModeSystemSettingsDialog then
            EditModeSystemSettingsDialog:UpdateDialog(system)
        end
    else
        -- Save the current live layout, never the override library's separate cache.
        manager:SaveLayouts()
        system.savedSystemInfo = CopyTable(info)
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
    return self:Apply(system, default, { isInDefaultPosition = true })
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

-- Change a setting like the native settings dialog does: inside Edit Mode it
-- stays in the draft for native Save/Revert, outside it is saved at once.
function position:ApplySetting(system, setting, value)
    if not self:CanEdit(system) or self:ReadSetting(system, setting) == nil then
        return false, L["Position editing is unavailable. Select an enabled frame in a custom layout."]
    end
    local manager = EditModeManagerFrame
    manager:OnSystemSettingChange(system, setting, value)
    if not manager:IsEditModeActive() then
        manager:SaveLayouts()
        local info = manager:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
        system.savedSystemInfo = info and CopyTable(info)
    end
    return true
end

function position:Revert(system)
    if not self:CanEdit(system) or not self:HasChanges(system) then
        return false
    end
    local before = positionState(system.savedSystemInfo)
    if not before or not before.anchorInfo then
        return false
    end
    return self:Apply(system, before.anchorInfo, before)
end
