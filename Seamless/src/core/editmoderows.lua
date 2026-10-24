---@type string, SeamlessCore
local _, app = ...

-- The shared Edit Mode row renderer: collapsible sections of toggle, select, range, button and
-- text rows, with the same row templates as LibEditMode and Blizzard's settings dialog. Addon-owned Edit Mode windows draw their settings with
-- it, so a row type is written once.

local addon = app.addon

-- Header and row heights, the gap between blocks and between rows, and the rows' inset.
local HEADER, ROW, GAP, ROW_GAP, INSET = 28, 32, 8, 3, 24

local states = {}

local function evaluate(value)
    if type(value) == "function" then
        return value()
    end
    return value
end

local function showTooltip(self)
    local option = self.option
    if option and option.desc then
        SettingsTooltip:SetOwner(self, "ANCHOR_NONE")
        SettingsTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT")
        SettingsTooltip:SetText(option.name, 1, 1, 1)
        SettingsTooltip:AddLine(option.desc)
        SettingsTooltip:Show()
    end
end

local function hideTooltip()
    SettingsTooltip:Hide()
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

-- Click the value to type one: Enter commits, Escape discards. The typed text goes to set()
-- unchanged, so the option validates it and may accept values outside the slider's range.
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
        self:SetText(tostring(row.value or 0))
        self:SetCursorPosition(0)
    end)
    edit:SetScript("OnEnterPressed", function(self)
        if row.option then
            row.option.set(self:GetText())
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
            row.option.set(value)
            -- Keep the slider where it is being dragged rather than initializing it again.
            row.value = row.option.get()
            changed()
        end
    end, row)
    row.Slider:SetWidth(200)
    row.Slider.MinText:Hide()
    row.Slider.MaxText:Hide()
    row.Label:SetPoint("LEFT")
    if option.editable then
        addEditBox(row, changed)
    end
    function row:Refresh(enabled)
        local option, value = self.option, self.option.get()
        if self.EditBox and self.shownOption ~= option then
            -- Typed text belongs to the option it was typed for.
            self.EditBox:ClearFocus()
        end
        self.enabled = enabled
        self.Slider:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
        if self.EditBox then
            self.EditBox:SetShown(enabled)
        end
        local min, max, step = evaluate(option.min), evaluate(option.max), evaluate(option.step)
        local range = min .. ":" .. max .. ":" .. step
        local typing = self.EditBox and self.EditBox:HasFocus()
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
    -- Half the row's width and centered, like the buttons of Blizzard's settings dialog.
    local row = CreateFrame("Frame", nil, parent)
    row.Button = CreateFrame("Button", nil, row, "EditModeSystemSettingsDialogButtonTemplate")
    row.Button:SetPoint("TOP")
    row.Button:SetOnClickHandler(function()
        if row.option then
            row.option.click()
            changed()
        end
    end)
    function row:Refresh(enabled)
        self.Button:SetText(self.option.name)
        self.Button:SetWidth(self:GetWidth() / 2)
        self.Button:SetEnabled(enabled)
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

local function state(parent, changed)
    local current = states[parent]
    if not current then
        current = { headers = {}, rows = {}, changed = changed }
        states[parent] = current
    end
    return current
end

-- Which headers are collapsed and which rows are shown: when it changes, the layout does too.
local function layoutKey(sections)
    local parts = {}
    for _, section in ipairs(sections) do
        local collapsed = addon:IsEditModeSectionCollapsed(section.key)
        parts[#parts + 1] = section.id .. (collapsed and "-" or "+")
        if not collapsed then
            for _, option in ipairs(section.options) do
                parts[#parts + 1] = evaluate(option.hidden) and "0" or "1"
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
---@field name string Header text.
---@field key string Collapse key, see IsEditModeSectionCollapsed.
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
    local current = state(parent, changed)
    -- Only hide what this pass leaves out: hiding a shown header or row, even for a moment,
    -- cancels a click or drag in progress on it.
    local used, shown = {}, {}
    for _, section in ipairs(sections) do
        local key = section.key
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
        local collapsed = addon:IsEditModeSectionCollapsed(key)
        header:UpdateCollapsedState(collapsed)
        if spaced then
            y = y + GAP
        end
        place(header, 16, y)
        used[header] = true
        y = y + HEADER
        spaced = true
        if not collapsed then
            local gap = GAP
            for _, option in ipairs(section.options) do
                if not evaluate(option.hidden) then
                    local id = section.id .. ":" .. option.key
                    local row = current.rows[id]
                    if not row then
                        row = creators[option.type](parent, function()
                            current.changed()
                        end, option)
                        row:SetHeight(ROW)
                        row:SetScript("OnEnter", showTooltip)
                        row:SetScript("OnLeave", hideTooltip)
                        current.rows[id] = row
                    end
                    row.option = option
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
