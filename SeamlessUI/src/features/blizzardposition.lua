---@type string, SeamlessUI
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local base = app.core:GetFramePositionService()
---@class SeamlessUI.BlizzardPosition : SeamlessCore.FramePosition
local position = setmetatable({}, { __index = base })
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
local keys = { "scale", "point", "relativePoint", "relativeTo", "offsetX", "offsetY" }
local labels = { L["Scale"], L["Anchor"], L["AnchorParent"], L["AnchorFrame"], L["X"], L["Y"] }
local dropdowns = { point = true, relativePoint = true, relativeTo = true }
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

local function dependsOn(target, frame)
    return not base:IsValidAnchorTarget(target, frame)
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

function position:Create(parent)
    local view = CreateFrame("Frame", nil, parent)
    -- Below the panel's title and Position header.
    view:SetPoint("TOPLEFT", 24, -80)
    view:SetPoint("TOPRIGHT", -24, -80)
    view:SetHeight(285)
    view.controls = {}
    view.values = {}

    local message = view:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    message:SetPoint("TOPLEFT", 0, -279)
    message:SetPoint("TOPRIGHT", 0, -279)
    message:SetJustifyH("LEFT")
    message:SetWordWrap(true)
    message:Hide()

    -- Pick an anchor point on this frame, then on another frame, instead of using the dropdowns.
    local pick = CreateFrame("Button", nil, view, "EditModeSystemSettingsDialogButtonTemplate")
    view.AnchorButton = pick
    pick:SetPoint("TOP", 0, -215)
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
    revert:SetPoint("TOP", 0, -247)
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
        if key == "scale" then
            local current = position:ReadScale(system)
            if tostring(current) ~= tostring(value) then
                local ok, err = position:ApplyScale(system, value)
                self.error = not ok and err or nil
                self:Refresh(system)
            end
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
        if dropdowns[key] then
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
                if key == "relativeTo" then
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
                self:SetText(tostring(row.value or 0))
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
        local scale, scaleMin, scaleMax, scaleStep, scaleSetting = position:ReadScale(system)
        for _, key in ipairs(keys) do
            local row = self.controls[key]
            if changedSystem and row.EditBox then
                row.EditBox:ClearFocus()
            end
            row.system = system
            local enabled = editable and values.point ~= nil
            local value = values[key]
            if key == "scale" then
                -- Greyed out like the settings panel's Scale when the frame has no size setting.
                enabled, value = editable and scaleSetting ~= nil, scale
            end
            row.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
            if dropdowns[key] then
                row.Dropdown:SetEnabled(enabled)
                if changedSystem or row.value ~= value then
                    row.value = value
                    row.Dropdown:SetDefaultText(
                        key == "relativeTo" and anchorFrameLabel(value) or anchorLabels[value] or L["Unknown"]
                    )
                    row.Dropdown:GenerateMenu()
                end
            else
                row.Slider:SetEnabled(enabled)
                row.EditBox:SetShown(enabled)
                local range = key == "scale" and scaleMin .. ":" .. scaleMax .. ":" .. scaleStep or nil
                if not row.EditBox:HasFocus() and (changedSystem or row.value ~= value or row.range ~= range) then
                    row.value, row.range = value, range
                    local min, max, steps
                    if key == "scale" then
                        min, max = scaleMin, scaleMax
                        steps = math.max(1, math.floor((max - min) / scaleStep + 0.5))
                    else
                        -- Screen-sized ranges, expanded for an existing offset so
                        -- large layouts are never clamped merely by opening the UI.
                        local extent = key == "offsetX" and UIParent:GetWidth() or UIParent:GetHeight()
                        extent = math.max(1, math.ceil(extent), math.ceil(math.abs(tonumber(value) or 0)))
                        min, max, steps = -extent, extent, extent * 2
                    end
                    local formatters = {
                        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                            MinimalSliderWithSteppersMixin.Label.Right,
                            function(current)
                                return string.format("%.12g", current)
                            end
                        ),
                    }
                    row.syncing = true
                    row.Slider:Init(tonumber(value) or 0, min, max, steps, formatters)
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
        local height = self.error and 331 or 285
        local resized = self.layoutHeight ~= height
        self.layoutHeight = height
        self:SetHeight(height)
        local parent = self:GetParent()
        if parent.LayoutContent then
            -- The poll below runs this every 0.15 s; re-stacking the window each time would
            -- interrupt clicks on the sections below, so only do it when the height changes.
            if resized then
                parent:LayoutContent()
            end
        else
            parent:SetHeight(self:GetHeight() + 100)
        end
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
