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
        local label = view:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 0, -(index - 1) * 35 - 8)
        label:SetText(labels[index])
        local control
        if index <= 2 then
            control = CreateFrame("DropdownButton", nil, view, "WowStyle1DropdownTemplate")
            control:SetHeight(30)
            control:SetupMenu(function(_, root)
                for _, anchor in ipairs(anchors) do
                    root:CreateRadio(anchor, function()
                        return view.values[key] == anchor
                    end, function()
                        view:Commit(key, anchor, control.system)
                    end)
                end
            end)
        else
            control = CreateFrame("EditBox", nil, view, "InputBoxTemplate")
            control:SetHeight(26)
            control:SetAutoFocus(false)
            control:SetMaxLetters(index == 3 and 128 or 24)
            control:SetScript("OnEnterPressed", function(self)
                self:ClearFocus()
            end)
            control:SetScript("OnEscapePressed", function(self)
                self:SetText(tostring(view.values[key] or ""))
                self:ClearFocus()
            end)
            control:SetScript("OnEditFocusLost", function(self)
                view:Commit(key, self:GetText():match("^%s*(.-)%s*$"), self.system)
            end)
            control:SetScript("OnTabPressed", function(self)
                self:ClearFocus()
                local nextControl = view.controls[keys[index == 5 and 3 or index + 1]]
                nextControl:SetFocus()
            end)
        end
        control:SetPoint("TOPLEFT", 110, -(index - 1) * 35)
        control:SetPoint("TOPRIGHT", 0, -(index - 1) * 35)
        view.controls[key] = control
    end

    function view:Refresh(system)
        local changedSystem = self.system ~= system
        self.system = system
        local values = position:Read(system) or {}
        self.values = values
        local editable = position:CanEdit(system)
        for index, key in ipairs(keys) do
            local control = self.controls[key]
            if changedSystem and index > 2 then
                control:ClearFocus()
            end
            control.system = system
            control:SetEnabled(editable and values.point ~= nil)
            if index <= 2 then
                if changedSystem or control.value ~= values[key] then
                    control.value = values[key]
                    control:SetDefaultText(values[key] or "Unknown")
                    control:GenerateMenu()
                end
            elseif not control:HasFocus() then
                control:SetText(tostring(values[key] or ""))
            end
        end
        if changedSystem then
            self.error = nil
        end
        message:SetText(
            self.error
                or (
                    editable and "Press Enter or leave a field to apply. Use Edit Mode Save or Revert to finish."
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
