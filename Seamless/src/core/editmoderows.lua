---@type string, SeamlessCore
local _, app = ...

-- The shared Edit Mode row renderer: collapsible sections of toggle, select, range, button and
-- text rows, with the same row templates as LibEditMode and Blizzard's settings dialog. Addon-owned Edit Mode windows draw their settings with
-- it, so a row type is written once.

local addon = app.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Header and row heights, the gap between blocks and between rows, and the rows' inset.
local HEADER, ROW, GAP, ROW_GAP, INSET = 28, 32, 8, 3, 24
-- Width of a slider, leaving room for its typed value on the right.
local SLIDER_WIDTH = 175
-- How far a row's hover highlight reaches past the row on each side.
local HOVER_OUTSET = 8

local states = {}

local function evaluate(value)
    if type(value) == "function" then
        return value()
    end
    return value
end

-- Settings show their default; buttons only a description they declare.
local SETTINGS = { toggle = true, select = true, range = true, input = true, color = true }

-- The declared default as the row shows values, like the config window's tooltips: booleans as
-- Enabled/Disabled, choices by their label, numbers through the row's format.
local function defaultText(option)
    if option.option then
        return option.option:TooltipDetails()
    end
    local value = evaluate(option.default)
    if value == nil then
        return L["Not applicable"]
    end
    if type(value) == "boolean" then
        return value and L["Enabled"] or L["Disabled"]
    end
    if option.type == "select" then
        for _, entry in ipairs(evaluate(option.values) or {}) do
            if entry.value == value then
                return entry.text
            end
        end
        local text = option.text and option.text(value)
        if text then
            return text
        end
    elseif option.type == "range" and option.format and type(value) == "number" then
        return option.format(value)
    end
    return value == "" and L["None"] or tostring(value)
end

-- Anchored like the config window's tooltips, not to the cursor: bottom-left corner on the top-right
-- of the row's name (a button row's button), padded 12 pixels right and 8 up, so on a dropdown or
-- slider row it sits above the control.
local function showTooltip(row)
    local option = row.option
    if not option then
        return
    end
    local setting = SETTINGS[option.type]
    local desc = evaluate(option.desc)
    if not setting and not (desc and desc ~= "") then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", row.Label or row.Button or row, "TOPRIGHT", 12, 8)
    GameTooltip:SetText(option.name or "", 1, 1, 1)
    if desc and desc ~= "" then
        GameTooltip:AddLine(desc, nil, nil, nil, true)
    end
    if setting then
        GameTooltip:AddLine(string.format(L["\n(Default: |cff8080ff%s|r)"], defaultText(option)), nil, nil, nil, true)
    end
    GameTooltip:Show()
end

-- The whole row lights up and shows its tooltip while the cursor is over it or any of its
-- controls, like the config window's rows. Moving between the row and a control fires a leave
-- on one and an enter on the other, so a leave only counts once the cursor is off the row.
local function enter(row)
    if row.Hover then
        row.Hover:Show()
    end
    showTooltip(row)
end

local function leave(row)
    if row:IsMouseOver() then
        return
    end
    if row.Hover then
        row.Hover:Hide()
    end
    if GameTooltip:IsOwned(row) then
        GameTooltip:Hide()
    end
end

-- Forward a control's hover to its row, also while the control is disabled.
local function hover(row, ...)
    for index = 1, select("#", ...) do
        local frame = select(index, ...)
        if frame then
            if frame.SetMotionScriptsWhileDisabled then
                frame:SetMotionScriptsWhileDisabled(true)
            end
            frame:HookScript("OnEnter", function()
                enter(row)
            end)
            frame:HookScript("OnLeave", function()
                leave(row)
            end)
        end
    end
end

local function setLabelEnabled(row, enabled)
    row.Label:SetTextColor((enabled and WHITE_FONT_COLOR or DISABLED_FONT_COLOR):GetRGB())
end

local function selectValues(option)
    return evaluate(option.values) or {}
end

local creators = {}

function creators.toggle(parent, changed)
    local row = CreateFrame("Frame", nil, parent, "EditModeSettingCheckboxTemplate")
    row.Button:SetPropagateMouseMotion(true)
    hover(row, row.Button)
    -- The template's button calls this; replace the native handler on our own row only.
    function row:OnCheckButtonClick()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self.option.set(not self.option.get())
        changed()
    end
    function row:Refresh(enabled)
        self.Button:SetChecked(not not self.option.get())
        self.Button:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
    end
    return row
end

function creators.select(parent, changed)
    -- Same label font, dimensions and dropdown template as LibEditMode.
    local row = CreateFrame("Frame", nil, parent)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    row.Label:SetPoint("LEFT")
    row.Label:SetWidth(100)
    row.Label:SetJustifyH("LEFT")
    row.Dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    row.Dropdown:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
    row.Dropdown:SetSize(200, 30)
    hover(row, row.Dropdown)
    -- SetupMenu builds the menu at once, before Layout assigns the row's option.
    row.Dropdown:SetupMenu(function(_, root)
        if not row.option then
            return
        end
        if row.option.scroll then
            root:SetScrollMode(row.option.scroll)
        end
        for _, entry in ipairs(selectValues(row.option)) do
            local item = root:CreateRadio(entry.text, function()
                return row.option.get() == entry.value
            end, function()
                row.option.set(entry.value)
                changed()
            end)
            if entry.disabled ~= nil then
                item:SetEnabled(not entry.disabled)
            end
        end
    end)
    function row:Refresh(enabled)
        local value = self.option.get()
        self.Dropdown:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
        if self.value ~= value or self.shownOption ~= self.option then
            self.value, self.shownOption = value, self.option
            local text = self.option.text and self.option.text(value)
            if not text then
                text = tostring(value)
                for _, entry in ipairs(selectValues(self.option)) do
                    if entry.value == value then
                        text = entry.text
                    end
                end
            end
            self.Dropdown:SetDefaultText(text)
            self.Dropdown:GenerateMenu()
        end
    end
    return row
end

-- A typed number for a plain slider: inside its range and on its steps, or nil.
local function typedValue(option, text)
    local value = tonumber(text)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    local min, max, step = evaluate(option.min), evaluate(option.max), evaluate(option.step)
    value = math.min(max, math.max(min, value))
    if step and step > 0 then
        value = math.min(max, min + math.floor((value - min) / step + 0.5) * step)
    end
    return value
end

-- Click the value to type one: Enter commits, Escape discards. With `editable`, the typed text goes
-- to set() unchanged, so the option validates it and may accept values outside the slider's range;
-- otherwise only a number is passed, clamped to the range and snapped to the step.
local function addEditBox(row, changed)
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
        self:SetText((row.option and row.option.format or tostring)(row.value or 0))
        self:SetCursorPosition(0)
    end)
    edit:SetScript("OnEnterPressed", function(self)
        local option = row.option
        if option and option.editable then
            option.set(self:GetText())
        elseif option then
            local value = typedValue(option, self:GetText())
            if value then
                option.set(value)
            end
        end
        self:ClearFocus()
        changed()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        resetInput(self)
        -- Show the current value again; a redraw of the whole window is up to the caller.
        if row.option then
            row:Refresh(row.enabled)
        end
    end)
end

function creators.range(parent, changed, option)
    -- The same slider template as LibEditMode. Replace callbacks only on our own row.
    local row = CreateFrame("Frame", nil, parent, "EditModeSettingSliderTemplate")
    row.cbrHandles:Unregister()
    row.cbrHandles:RegisterCallback(row.Slider, MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not row.syncing then
            -- Keep the slider where it is being dragged rather than initializing it again, also
            -- when the setter redraws the window before returning.
            row.value = value
            row.option.set(value)
            row.value = row.option.get()
            changed()
        end
    end, row)
    -- Room for a typed value such as -1234.56 inside the row, right of a shorter slider.
    row.Slider:SetWidth(SLIDER_WIDTH)
    row.Slider.MinText:Hide()
    row.Slider.MaxText:Hide()
    row.Label:SetPoint("LEFT")
    addEditBox(row, changed)
    local slider = row.Slider
    hover(row, slider, slider.Slider, slider.Back, slider.Forward, row.EditBox)
    function row:Refresh(enabled)
        local option, value = self.option, self.option.get()
        if self.shownOption ~= option then
            -- Typed text belongs to the option it was typed for.
            self.EditBox:ClearFocus()
        end
        self.enabled = enabled
        self.Slider:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
        self.EditBox:SetShown(enabled)
        local min, max, step = evaluate(option.min), evaluate(option.max), evaluate(option.step)
        local range = min .. ":" .. max .. ":" .. step
        local typing = self.EditBox:HasFocus()
        if not typing and (self.value ~= value or self.shownOption ~= option or self.range ~= range) then
            self.value, self.shownOption, self.range = value, option, range
            local formatters = {
                [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                    MinimalSliderWithSteppersMixin.Label.Right,
                    option.format or tostring
                ),
            }
            local steps = math.max(1, math.floor((max - min) / step + 0.5))
            self.syncing = true
            self.Slider:Init(tonumber(value) or 0, min, max, steps, formatters)
            self.syncing = false
        end
    end
    return row
end

function creators.button(parent, changed)
    -- Centered; half the row's width unless the option sets one, like Blizzard's dialog buttons.
    local row = CreateFrame("Frame", nil, parent)
    row.Button = CreateFrame("Button", nil, row, "EditModeSystemSettingsDialogButtonTemplate")
    row.Button:SetPoint("TOP")
    hover(row, row.Button)
    row.Button:SetOnClickHandler(function()
        if row.option then
            row.option.click()
            changed()
        end
    end)
    local function fit(self, width)
        self.Button:SetWidth(self.option.width or width / 2)
    end
    function row:Refresh(enabled)
        self.Button:SetText(self.option.name)
        fit(self, self:GetWidth())
        self.Button:SetEnabled(enabled)
    end
    -- A new row has no width until the client lays it out (the first window after a reload), so
    -- size the button again once it has one.
    row:SetScript("OnSizeChanged", function(self, width)
        if self.option then
            fit(self, width)
        end
    end)
    return row
end

function creators.divider(parent)
    -- The line LibEditMode's dialog draws between its settings and its buttons.
    local row = CreateFrame("Frame", nil, parent)
    row.Line = row:CreateTexture(nil, "ARTWORK")
    row.Line:SetSize(330, 16)
    row.Line:SetPoint("CENTER")
    row.Line:SetTexture([[Interface\FriendsFrame\UI-FriendsFrame-OnlineDivider]])
    row.rowHeight = 16
    function row:Refresh()
        self:SetHeight(self.rowHeight)
    end
    return row
end

function creators.text(parent)
    -- A wrapped message, such as why the last change was refused; as tall as its text.
    local row = CreateFrame("Frame", nil, parent)
    row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Text:SetPoint("TOPLEFT")
    row.Text:SetPoint("TOPRIGHT")
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(true)
    function row:Refresh()
        self.Text:SetText(self.option.get() or "")
        self.rowHeight = math.max(ROW, math.ceil(self.Text:GetStringHeight()))
        self:SetHeight(self.rowHeight)
    end
    return row
end

-- Additional declaration kinds use the details panel's existing label/control alignment.
local function labeledRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    row.Label:SetPoint("LEFT")
    row.Label:SetWidth(100)
    row.Label:SetJustifyH("LEFT")
    return row
end

function creators.input(parent, changed)
    local row = labeledRow(parent)
    local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.EditBox = edit
    edit:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
    edit:SetSize(200, 22)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEnterPressed", function(self)
        if row.option.set(self:GetText()) then
            self:ClearFocus()
            changed()
        end
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText(row.option.get() or "")
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        self:SetText(row.option.get() or "")
    end)
    hover(row, edit)
    function row:Refresh(enabled)
        edit:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
        if not edit:HasFocus() then
            edit:SetText(self.option.get() or "")
        end
    end
    return row
end

function creators.color(parent, changed)
    local row = labeledRow(parent)
    local swatch = CreateFrame("Button", nil, row, "ColorSwatchTemplate")
    swatch:SetPoint("LEFT", row.Label, "RIGHT", 5, 0)
    hover(row, swatch)
    swatch:SetScript("OnClick", function()
        local option = row.option
        local r, g, b, a = option.get()
        local function apply(red, green, blue, alpha)
            if option.set(red, green, blue, alpha) then
                changed()
            end
        end
        local function picked()
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            apply(red, green, blue, ColorPickerFrame:GetColorAlpha())
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = a or 1,
            hasOpacity = option.hasAlpha,
            swatchFunc = picked,
            opacityFunc = picked,
            cancelFunc = function()
                apply(r, g, b, a)
            end,
        })
    end)
    function row:Refresh(enabled)
        swatch:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
        swatch:SetColorRGB(self.option.get())
    end
    return row
end

local function state(parent)
    local current = states[parent]
    if not current then
        current = { headers = {}, rows = {} }
        states[parent] = current
    end
    return current
end

-- A section without a shown header (no name, or a hidden one) never collapses its rows.
local function isHidden(option)
    return option.hideInEditmode == true or evaluate(option.hidden)
end

local function hasHeader(section)
    return section.name ~= nil and section.hideInEditmode ~= true and not evaluate(section.hidden)
end

local function isCollapsed(section)
    return hasHeader(section) and addon:IsEditModeSectionCollapsed(section.key)
end

-- Which headers are collapsed and which rows are shown: when it changes, the layout does too.
local function layoutKey(sections)
    local parts = {}
    for _, section in ipairs(sections) do
        local collapsed = isCollapsed(section)
        parts[#parts + 1] = section.id .. (collapsed and "-" or "+")
        if not collapsed then
            for _, option in ipairs(section.options) do
                parts[#parts + 1] = isHidden(option) and "0" or "1"
            end
        end
    end
    return table.concat(parts, ",")
end

local function place(frame, inset, y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", inset, -y)
    frame:SetPoint("TOPRIGHT", -inset, -y)
    frame:Show()
end

---@class SeamlessCore.EditModeSection
---@field id string Unique among the sections drawn in one parent; rows are reused by id and key.
---@field name string? Header text; without one the rows have no header and never collapse.
---@field key string? Collapse key, see IsEditModeSectionCollapsed.
---@field hidden (boolean|fun(): boolean)? Hides the header only; its rows show uncollapsed.
---@field options table[] Rows: key, type, name, desc?, get, set, hidden?, disabled? (see Seamless/CLAUDE.md).

---Lay out sections in parent from y down, each under a collapsible header; returns the bottom.
---Rows are created once per parent and reused; only rows this pass leaves out are hidden.
---@param parent table An addon-owned frame.
---@param sections SeamlessCore.EditModeSection[]
---@param y number Top offset of the first section.
---@param spaced boolean Whether something sits above, so the first header needs a gap.
---@param changed fun() Redraws the window after a click or a collapse.
---@return number bottom
function addon:LayoutEditModeSections(parent, sections, y, spaced, changed)
    local current = state(parent)
    -- The latest callback wins: one window can show different owners' sections.
    current.changed = changed
    -- Only hide what this pass leaves out: hiding a shown header or row, even for a moment,
    -- cancels a click or drag in progress on it.
    local used, shown = {}, {}
    for _, section in ipairs(sections) do
        local key = section.key
        local collapsed = isCollapsed(section)
        if hasHeader(section) then
            local header = current.headers[section.id]
            if not header then
                header = addon:CreateEditModeHeader(parent, function()
                    if InCombatLockdown() then
                        return
                    end
                    addon:SetEditModeSectionCollapsed(key, not addon:IsEditModeSectionCollapsed(key))
                    current.changed()
                end)
                current.headers[section.id] = header
            end
            header:SetHeaderText(section.name)
            header:UpdateCollapsedState(collapsed)
            if spaced then
                y = y + GAP
            end
            place(header, 16, y)
            used[header] = true
            y = y + HEADER
            spaced = true
        end
        if not collapsed then
            local gap = GAP
            for _, option in ipairs(section.options) do
                if not isHidden(option) then
                    -- With the type, so another owner's row of the same key is never reused.
                    local id = section.id .. ":" .. option.type .. ":" .. option.key
                    local row = current.rows[id]
                    if not row then
                        row = creators[option.type](parent, function()
                            current.changed()
                        end, option)
                        row:SetHeight(ROW)
                        if SETTINGS[option.type] then
                            -- The config window's row hover, reaching a little past the row.
                            row.Hover = row:CreateTexture(nil, "BACKGROUND")
                            row.Hover:SetPoint("TOPLEFT", -HOVER_OUTSET, 0)
                            row.Hover:SetPoint("BOTTOMRIGHT", HOVER_OUTSET, 0)
                            row.Hover:SetColorTexture(1, 1, 1, 0.1)
                            row.Hover:Hide()
                        end
                        if row.EnableMouseMotion then
                            row:EnableMouseMotion(true)
                        end
                        row:SetScript("OnEnter", enter)
                        row:SetScript("OnLeave", leave)
                        current.rows[id] = row
                    end
                    row.option = option
                    if option.option then
                        option.owner = row
                    end
                    if row.Label then
                        row.Label:SetText(option.name)
                    end
                    y = y + gap
                    place(row, INSET, y)
                    used[row] = true
                    row:Refresh(not evaluate(option.disabled))
                    shown[#shown + 1] = row
                    y = y + (row.rowHeight or ROW)
                    gap = ROW_GAP
                    spaced = true
                end
            end
        end
    end
    for _, frames in ipairs({ current.headers, current.rows }) do
        for _, frame in pairs(frames) do
            if not used[frame] then
                frame:Hide()
            end
        end
    end
    current.sections, current.shown, current.layout = sections, shown, layoutKey(sections)
    return y
end

---Refresh the values of the rows the last LayoutEditModeSections drew in parent, in place, for
---polling native state without moving anything. Returns true when that is not enough (a row was
---hidden or shown, a section collapsed, a row's height changed): lay the sections out again then.
---@param parent table
---@return boolean relayout
function addon:RefreshEditModeSections(parent)
    local current = states[parent]
    if not current or not current.sections then
        return false
    end
    if layoutKey(current.sections) ~= current.layout then
        return true
    end
    for _, row in ipairs(current.shown) do
        local height = row.rowHeight
        row:Refresh(not evaluate(row.option.disabled))
        if row.rowHeight ~= height then
            return true
        end
    end
    return false
end
