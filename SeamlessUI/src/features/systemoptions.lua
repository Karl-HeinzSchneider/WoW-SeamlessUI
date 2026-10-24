---@type string, SeamlessUI
local _, app = ...

-- Draws the sections other addons register with Core's RegisterEditModeSystemOptions in the
-- extended window, each under a collapsible header, with the same row templates as LibEditMode.

---@class SeamlessUI.SystemOptions
local systemOptions = {}
app.systemOptions = systemOptions

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
        for _, entry in ipairs(row.option.values) do
            root:CreateRadio(entry.text, function()
                return row.option.get() == entry.value
            end, function()
                row.option.set(entry.value)
                changed()
            end)
        end
    end)
    function row:Refresh(enabled)
        local value = self.option.get()
        self.Dropdown:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
        if self.value ~= value or self.shownOption ~= self.option then
            self.value, self.shownOption = value, self.option
            local text = tostring(value)
            for _, entry in ipairs(self.option.values) do
                if entry.value == value then
                    text = entry.text
                end
            end
            self.Dropdown:SetDefaultText(text)
            self.Dropdown:GenerateMenu()
        end
    end
    return row
end

function creators.range(parent, changed)
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
    function row:Refresh(enabled)
        local option, value = self.option, self.option.get()
        self.Slider:SetEnabled(enabled)
        setLabelEnabled(self, enabled)
        if self.value ~= value or self.shownOption ~= option then
            self.value, self.shownOption = value, option
            local formatters = {
                [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                    MinimalSliderWithSteppersMixin.Label.Right,
                    option.format or tostring
                ),
            }
            local steps = math.floor((option.max - option.min) / option.step + 0.5)
            self.syncing = true
            self.Slider:Init(value, option.min, option.max, steps, formatters)
            self.syncing = false
        end
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

local function place(frame, inset, y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", inset, -y)
    frame:SetPoint("TOPRIGHT", -inset, -y)
    frame:Show()
end

---Lay out the selected system's sections in parent from y down; returns the bottom.
---@param parent table The extended window.
---@param system table The selected system frame.
---@param y number Top offset of the first section.
---@param spaced boolean Whether something sits above, so the first header needs a gap.
---@param changed fun() Redraws the window after a click.
---@return number bottom
function systemOptions:Layout(parent, system, y, spaced, changed)
    local current = state(parent, changed)
    -- Only hide what this pass leaves out: hiding a shown header or row, even for a moment,
    -- cancels a click or drag in progress on it.
    local used = {}
    for _, spec in ipairs(app.core:GetEditModeSystemOptions(system)) do
        local key = "settings:" .. (spec.key or spec.name)
        local header = current.headers[spec.id]
        if not header then
            header = app.core:CreateEditModeHeader(parent, function()
                if InCombatLockdown() then
                    return
                end
                app.core:SetEditModeSectionCollapsed(key, not app.core:IsEditModeSectionCollapsed(key))
                current.changed()
            end)
            current.headers[spec.id] = header
        end
        header:SetHeaderText(spec.name)
        local collapsed = app.core:IsEditModeSectionCollapsed(key)
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
            for _, option in ipairs(spec.options) do
                if not evaluate(option.hidden) then
                    local id = spec.id .. ":" .. option.key
                    local row = current.rows[id]
                    if not row then
                        row = creators[option.type](parent, function()
                            current.changed()
                        end)
                        row:SetHeight(ROW)
                        row:SetScript("OnEnter", showTooltip)
                        row:SetScript("OnLeave", hideTooltip)
                        current.rows[id] = row
                    end
                    row.option = option
                    row.Label:SetText(option.name)
                    y = y + gap
                    place(row, INSET, y)
                    used[row] = true
                    row:Refresh(not evaluate(option.disabled))
                    y = y + ROW
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
    return y
end
