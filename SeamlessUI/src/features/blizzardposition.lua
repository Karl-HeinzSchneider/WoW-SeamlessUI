---@type string, SeamlessUI
local _, app = ...

---@class SeamlessUI.BlizzardPosition
local position = {}
app.blizzardPosition = position

local anchors = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local validAnchors = {}
for _, point in ipairs(anchors) do
    validAnchors[point] = true
end
local keys = { "point", "relativePoint", "relativeTo", "offsetX", "offsetY" }
local labels = { "Anchor", "AnchorParent", "AnchorFrame", "X", "Y" }
-- These objects are created by the default client even when their unit is absent.
-- UIParent stays first; the remaining display names are alphabetical.
local anchorFrames = {
    { value = "UIParent", text = "UIParent" },
    { value = "FocusFrame", text = "Focus frame" },
    { value = "Minimap", text = "Minimap" },
    { value = "PlayerFrame", text = "Player frame" },
    { value = "TargetFrame", text = "Target frame" },
}

local function anchorFrameLabel(name)
    for _, entry in ipairs(anchorFrames) do
        if entry.value == name then
            return entry.text
        end
    end
    -- Reflect existing layouts without adding arbitrary frames to the selector.
    return name or "Unknown"
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

function position:Read(system)
    local info = EditModeManagerFrame:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
    return info and info.anchorInfo and CopyTable(info.anchorInfo)
end

function position:CanEdit(system)
    local selected, spec = app.blizzardEditMode:GetSelectedFrame()
    local override = LibStub("LibEditModeOverride-1.0")
    return selected == system
        and spec
        and app.db.profile.blizzardEditMode.frames[spec.key].addPosition
        and not InCombatLockdown()
        and not EditModeManagerFrame:IsActiveLayoutPreset()
        and not EditModeManagerFrame.overrideLayoutInfo
        and override:IsReady()
end

function position:Apply(system, values)
    if not self:CanEdit(system) then
        return false, "Position editing is unavailable. Select an enabled frame in a custom layout."
    end
    if not validAnchors[values.point] or not validAnchors[values.relativePoint] then
        return false, "Choose a valid anchor point."
    end
    local x, y = tonumber(values.offsetX), tonumber(values.offsetY)
    if not finite(x) or not finite(y) then
        return false, "X and Y must be finite numbers."
    end
    local relativeTo = type(values.relativeTo) == "string" and _G[values.relativeTo]
    if
        not relativeTo
        or type(relativeTo) ~= "table"
        or not relativeTo.IsObjectType
        or not relativeTo:IsObjectType("Frame")
    then
        return false, "AnchorFrame must name an existing frame, such as UIParent."
    end
    if dependsOn(relativeTo, system, {}) then
        return false, "AnchorFrame would create an anchor cycle."
    end
    local manager = EditModeManagerFrame
    local info = manager:GetActiveLayoutSystemInfo(system.system, system.systemIndex)
    if not info or not info.anchorInfo then
        return false, "This frame has no anchor in the active layout."
    end
    local override = LibStub("LibEditModeOverride-1.0")
    local ok, err = pcall(function()
        -- Reload before every edit: another addon or a layout switch can change
        -- the override's shared cache. Never save that cache over the live draft.
        override:LoadLayouts()
        override:ReanchorFrame(system, values.point, relativeTo, values.relativePoint, x, y)
    end)
    if not ok then
        return false, "Could not set the anchor: " .. tostring(err)
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
    info.anchorInfo2 = nil
    info.isInDefaultPosition = false
    system:ClearFrameSnap()
    system.systemInfo = info
    system:ApplySystemAnchor()
    system:SetHasActiveChanges(true)
    manager:SetHasActiveChanges(true)
    EditModeSystemSettingsDialog:UpdateDialog(system)
    return true
end

function position:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    view:SetPoint("TOPLEFT", 24, -48)
    view:SetPoint("TOPRIGHT", -24, -48)
    view:SetHeight(226)
    view.controls = {}
    view.values = {}

    local message = view:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    message:SetPoint("TOPLEFT", 0, -180)
    message:SetPoint("TOPRIGHT", 0, -180)
    message:SetJustifyH("LEFT")
    message:SetWordWrap(true)

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
                    for _, entry in ipairs(anchorFrames) do
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
                        root:CreateRadio(anchor, function()
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
                        index == 3 and anchorFrameLabel(values[key]) or values[key] or "Unknown"
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
        message:SetText(
            self.error
                or (
                    editable
                        and "Click a value to type; Enter applies, Escape cancels. Use Edit Mode Save or Revert to finish."
                    or "Select a custom Edit Mode layout to edit position."
                )
        )
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
