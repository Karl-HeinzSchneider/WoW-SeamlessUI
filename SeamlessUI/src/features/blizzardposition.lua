---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.BlizzardPosition
local position = {}
app.blizzardPosition = position

local anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local anchorLabels = {
    TOPLEFT = L["Top left"],
    TOP = L["Top"],
    TOPRIGHT = L["Top right"],
    LEFT = L["Left"],
    CENTER = L["Center"],
    RIGHT = L["Right"],
    BOTTOMLEFT = L["Bottom left"],
    BOTTOM = L["Bottom"],
    BOTTOMRIGHT = L["Bottom right"],
}
local validAnchors = {}
for _, point in ipairs(anchors) do
    validAnchors[point] = true
end
local keys = { "point", "relativePoint", "relativeTo", "offsetX", "offsetY" }
local labels = { L["Anchor"], L["AnchorParent"], L["AnchorFrame"], L["X"], L["Y"] }
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

---Anchor targets for SeamlessUI's own frames, leaving out any that depend on `frame`.
---@param frame table
---@return { value: string, text: string }[]
function position:GetAnchorFrames(frame)
    local entries = {}
    for _, entry in ipairs(getAnchorFrames()) do
        local target = _G[entry.value]
        if target and not dependsOn(target, frame, {}) then
            entries[#entries + 1] = entry
        end
    end
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
    local info = EditModeManagerFrame:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
    if not info or not info.anchorInfo then
        return nil
    end
    if system.IsInDefaultPosition and system:IsInDefaultPosition() then
        local live = liveAnchor(system)
        if live then
            return live
        end
    end
    return CopyTable(info.anchorInfo)
end

function position:CanEdit(system)
    local selected, spec = app.blizzardEditMode:GetSelectedFrame()
    local override = LibStub("LibEditModeOverride-1.0")
    return selected == system
        and spec
        and app.db.profile.blizzardEditMode.frames[spec.key].addPosition
        and not InCombatLockdown()
        and not system.isLocked
        and not EditModeManagerFrame:IsActiveLayoutPreset()
        and not EditModeManagerFrame.overrideLayoutInfo
        and override:IsReady()
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
    EditModeSystemSettingsDialog:UpdateDialog(system)
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

function position:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    -- Below the panel's title and Position header.
    view:SetPoint("TOPLEFT", 24, -80)
    view:SetPoint("TOPRIGHT", -24, -80)
    view:SetHeight(250)
    view.controls = {}
    view.values = {}

    local message = view:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    message:SetPoint("TOPLEFT", 0, -244)
    message:SetPoint("TOPRIGHT", 0, -244)
    message:SetJustifyH("LEFT")
    message:SetWordWrap(true)
    message:Hide()

    -- Pick an anchor point on this frame, then on another frame, instead of using the dropdowns.
    local pick = CreateFrame("Button", nil, view, "EditModeSystemSettingsDialogButtonTemplate")
    view.AnchorButton = pick
    pick:SetPoint("TOP", 0, -180)
    pick:SetText(L["Quick anchor to frame"])
    pick:SetOnClickHandler(function()
        local system = view.system
        if not position:CanEdit(system) then
            return
        end
        app.core:StartEditModeAnchorPicker({
            frame = system,
            targets = function()
                local targets = {}
                for _, entry in ipairs(getAnchorFrames()) do
                    local target = _G[entry.value]
                    if entry.value ~= "UIParent" and target and not dependsOn(target, system, {}) then
                        targets[#targets + 1] = { frame = target, value = entry.value }
                    end
                end
                return targets
            end,
            apply = function(point, relativeTo, relativePoint, x, y)
                if system ~= view.system or system ~= app.blizzardEditMode:GetSelectedFrame() then
                    return
                end
                local ok, err = position:Apply(system, {
                    point = point,
                    relativeTo = relativeTo,
                    relativePoint = relativePoint,
                    offsetX = x,
                    offsetY = y,
                })
                view.error = not ok and err or nil
                view:Refresh(system)
            end,
        })
    end)

    local revert = CreateFrame("Button", nil, view, "EditModeSystemSettingsDialogButtonTemplate")
    view.RevertButton = revert
    revert:SetPoint("TOP", 0, -212)
    revert:SetText(HUD_EDIT_MODE_REVERT_CHANGES or L["Revert changes"])
    revert:SetOnClickHandler(function()
        local ok, err = position:Revert(view.system)
        view.error = not ok and err or nil
        view:Refresh(view.system)
    end)

    function view:Commit(key, value, system)
        if system ~= self.system or system ~= app.blizzardEditMode:GetSelectedFrame() then
            return
        end
        local values = position:Read(system)
        if not values or tostring(values[key]) == tostring(value) then
            return
        end
        values[key] = value
        local ok, err = position:Apply(system, values)
        self.error = not ok and err or nil
        self:Refresh(system)
    end

    for index, key in ipairs(keys) do
        local row
        if index <= 3 then
            -- Same label font, dimensions and dropdown template as LibEditMode.
            row = CreateFrame("Frame", nil, view)
            row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
            row.Label:SetPoint("LEFT")
            row.Label:SetWidth(100)
            row.Label:SetJustifyH("LEFT")
            row.Dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
            row.Dropdown:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
            row.Dropdown:SetSize(200, 30)
            row.Dropdown:SetupMenu(function(_, root)
                local system = row.system
                if index == 3 then
                    root:SetScrollMode(400)
                    for _, entry in ipairs(getAnchorFrames()) do
                        local item = root:CreateRadio(entry.text, function()
                            return view.values[key] == entry.value
                        end, function()
                            view:Commit(key, entry.value, system)
                        end)
                        local target = _G[entry.value]
                        item:SetEnabled(target ~= nil and not dependsOn(target, system, {}))
                    end
                else
                    for _, anchor in ipairs(anchors) do
                        root:CreateRadio(anchorLabels[anchor], function()
                            return view.values[key] == anchor
                        end, function()
                            view:Commit(key, anchor, system)
                        end)
                    end
                end
            end)
        else
            -- Use the very same slider template as LibEditMode, including its
            -- steppers/right-hand value. Replace callbacks only on our own row.
            row = CreateFrame("Frame", nil, view, "EditModeSettingSliderTemplate")
            row.cbrHandles:Unregister()
            row.cbrHandles:RegisterCallback(
                row.Slider,
                MinimalSliderWithSteppersMixin.Event.OnValueChanged,
                function(_, value)
                    if not row.syncing then
                        view:Commit(key, value, row.system)
                    end
                end,
                row
            )
            row.Slider:SetWidth(200)
            row.Slider.MinText:Hide()
            row.Slider.MaxText:Hide()
            row.Label:SetPoint("LEFT")
            local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.EditBox = edit
            edit:SetAutoFocus(false)
            edit:SetJustifyH("CENTER")
            edit:SetMaxLetters(24)
            local function resetInput(self)
                row.Slider:Show()
                self:SetText("")
                self:ClearAllPoints()
                self:SetPoint("RIGHT", row.Slider.RightText, 5, 0)
                self:SetPoint("TOPLEFT", row.Slider.RightText)
                self:SetPoint("BOTTOMLEFT", row.Slider.RightText)
            end
            resetInput(edit)
            edit:SetScript("OnEditFocusGained", function(self)
                row.Slider:Hide()
                self:ClearAllPoints()
                self:SetPoint("RIGHT", row.Slider.RightText, 5, 0)
                self:SetPoint("TOPLEFT", row.Slider)
                self:SetPoint("BOTTOMLEFT", row.Slider)
                self:SetText(tostring(view.values[key] or 0))
                self:SetCursorPosition(0)
            end)
            edit:SetScript("OnEnterPressed", function(self)
                view:Commit(key, self:GetText(), row.system)
                self:ClearFocus()
                view:Refresh(view.system)
            end)
            edit:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
            end)
            edit:SetScript("OnEditFocusLost", function(self)
                resetInput(self)
                view:Refresh(view.system)
            end)
        end
        row.Label:SetText(labels[index])
        row:SetHeight(32)
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 35)
        row:SetPoint("TOPRIGHT", 0, -(index - 1) * 35)
        row:Show()
        view.controls[key] = row
    end

    function view:Refresh(system)
        local changedSystem = self.system ~= system
        self.system = system
        local values = position:Read(system) or {}
        self.values = values
        local editable = position:CanEdit(system)
        for index, key in ipairs(keys) do
            local row = self.controls[key]
            if changedSystem and row.EditBox then
                row.EditBox:ClearFocus()
            end
            row.system = system
            local enabled = editable and values.point ~= nil
            row.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
            if index <= 3 then
                row.Dropdown:SetEnabled(enabled)
                if changedSystem or row.value ~= values[key] then
                    row.value = values[key]
                    row.Dropdown:SetDefaultText(
                        index == 3 and anchorFrameLabel(values[key]) or anchorLabels[values[key]] or L["Unknown"]
                    )
                    row.Dropdown:GenerateMenu()
                end
            else
                row.Slider:SetEnabled(enabled)
                row.EditBox:SetShown(enabled)
                if not row.EditBox:HasFocus() and (changedSystem or row.value ~= values[key]) then
                    row.value = values[key]
                    -- Screen-sized ranges, expanded for an existing offset so
                    -- large layouts are never clamped merely by opening the UI.
                    local extent = index == 4 and UIParent:GetWidth() or UIParent:GetHeight()
                    extent = math.max(1, math.ceil(extent), math.ceil(math.abs(tonumber(values[key]) or 0)))
                    local formatters = {
                        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                            MinimalSliderWithSteppersMixin.Label.Right,
                            function(value)
                                return tostring(value)
                            end
                        ),
                    }
                    row.syncing = true
                    row.Slider:Init(tonumber(values[key]) or 0, -extent, extent, extent * 2, formatters)
                    row.syncing = false
                end
            end
        end
        if changedSystem then
            self.error = nil
        end
        pick:SetWidth(self:GetWidth() / 2)
        pick:SetEnabled(editable and values.point ~= nil)
        revert:SetWidth(self:GetWidth() / 2)
        revert:SetEnabled(editable and position:HasChanges(system))
        message:SetText(self.error or "")
        message:SetShown(self.error ~= nil)
        self:SetHeight(self.error and 296 or 250)
        self:GetParent():SetHeight(self:GetHeight() + 100)
    end

    -- Native dragging, arrow nudges, scale changes and Revert all update the same
    -- draft. Poll only while shown, preserving any field currently being typed.
    local elapsed = 0
    view:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.15 and self.system then
            elapsed = 0
            self:Refresh(self.system)
        end
    end)
    return view
end
