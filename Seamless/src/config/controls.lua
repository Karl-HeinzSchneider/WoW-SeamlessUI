---@type string, SeamlessCore
local _, app = ...

local config = app.config
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local Registry = LibStub("AceConfigRegistry-3.0")

-- Our row base and control factories own behavior and layout. Reuse SharedXML
-- primitives and the Settings panel's art without inheriting its setting/CVar
-- bindings, pooling, narration or global SettingsPanel lifecycle.
local Row = {}
local creators = {}
config.ControlRow, config.controlCreators = Row, creators

local function text(parent, font)
    local region = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    region:SetJustifyH("LEFT")
    return region
end

local function anchorTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMLEFT", row.Label, "TOPRIGHT", 12, 8)
end

local function tooltip(frame, row)
    if frame.SetMotionScriptsWhileDisabled then
        frame:SetMotionScriptsWhileDisabled(true)
    end
    frame:HookScript("OnEnter", function()
        local desc = row.option:Read("desc")
        local kind = row.option:Read("type")
        local setting = kind ~= "group" and kind ~= "header" and kind ~= "description"
        if setting or (desc and desc ~= "") then
            anchorTooltip(row)
            GameTooltip:SetText(row.option:Read("name") or "", 1, 1, 1)
            if desc and desc ~= "" then
                GameTooltip:AddLine(desc, nil, nil, nil, true)
            end
            if setting then
                local default, perCharacter = row.option:TooltipDetails()
                GameTooltip:AddLine(string.format(L["\n(Default: |cff8080ff%s|r)"], default), nil, nil, nil, true)
                if perCharacter then
                    GameTooltip:AddLine(L["\n\n|cff8080ff[Per-character setting]|r"], nil, nil, nil, true)
                end
            end
            GameTooltip:Show()
        end
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Row:New(page)
    local row = CreateFrame("Frame", nil, page)
    row.featureTagViewport = config.contentScroll
    Mixin(row, self)
    row:SetWidth(page:GetWidth())
    row.Label = text(row)
    row.Label:SetPoint("LEFT", 37, 0)
    row.Label:SetPoint("RIGHT", row, "CENTER", -85, 0)
    row.Label:SetWordWrap(true)
    row:EnableMouse(true)
    row.Hover = row:CreateTexture(nil, "BACKGROUND")
    row.Hover:SetAllPoints()
    row.Hover:SetColorTexture(1, 1, 1, 0.1)
    row.Hover:Hide()
    row:SetScript("OnEnter", function()
        row.Hover:Show()
    end)
    row:SetScript("OnLeave", function()
        row.Hover:Hide()
    end)
    tooltip(row, row)
    return row
end

function Row:Refresh(option)
    self.option = option
    self.enabled = not option:Read("disabled")
    self.Label:SetText(option:Read("name") or "")
    self.Label:SetTextColor(self.enabled and 1 or 0.5, self.enabled and 0.82 or 0.5, self.enabled and 0 or 0.5)
    self.syncing = true
    if self.Update then
        self:Update()
    end
    local tags = { new = option:Read("new"), blizzard = option:Read("blizzard") }
    config:UpdateFeatureTags(self, self.tagAnchor or self.Label, tags)
    if self.Control then
        self.Control:SetEnabled(self.enabled)
    end
    self.syncing = false
    self:SetHeight(math.max(self.rowHeight or 32, self.Label:GetStringHeight() + 12))
end

StaticPopupDialogs.SeamlessConfigConfirm = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, callback)
        callback()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Row:Commit(...)
    if self.syncing or not self.enabled then
        return
    end
    local option, values = self.option, { ... }
    local valid = option:Read("validate", unpack(values))
    if valid == false or type(valid) == "string" then
        anchorTooltip(self)
        GameTooltip:SetText(type(valid) == "string" and valid or L["Invalid value"], 1, 0.2, 0.2)
        GameTooltip:Show()
        return
    end
    local function apply()
        -- Recheck state after confirmation, as a profile may have changed.
        if option:Read("hidden") or option:Read("disabled") then
            return
        end
        option:Read(option:Read("type") == "execute" and "func" or "set", unpack(values))
        Registry:NotifyChange(option.appName)
    end
    local confirm = option:Read("confirm", unpack(values))
    if confirm then
        local message = type(confirm) == "string" and confirm or option:Read("confirmText") or L["Apply this change?"]
        StaticPopup_Show("SeamlessConfigConfirm", message, nil, apply)
    else
        apply()
    end
end

function creators.toggle(page)
    local row = Row:New(page)
    local button = CreateFrame("CheckButton", nil, row)
    row.Control = button
    button:SetSize(30, 29)
    button:SetPoint("LEFT", row, "CENTER", -80, 0)
    button:SetNormalAtlas("checkbox-minimal")
    button:SetPushedAtlas("checkbox-minimal")
    local checked = button:CreateTexture(nil, "ARTWORK")
    checked:SetAtlas("checkmark-minimal", true)
    checked:SetPoint("CENTER")
    button:SetCheckedTexture(checked)
    local disabled = button:CreateTexture(nil, "ARTWORK")
    disabled:SetAtlas("checkmark-minimal-disabled", true)
    disabled:SetPoint("CENTER")
    button:SetDisabledCheckedTexture(disabled)
    button:SetScript("OnClick", function()
        row:Commit(button:GetChecked())
    end)
    tooltip(button, row)
    function row:Update()
        button:SetChecked(not not self.option:Read("get"))
    end
    return row
end

function creators.select(page)
    local row = Row:New(page)
    local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle2DropdownTemplate")
    row.Control = dropdown
    dropdown:SetPoint("LEFT", row, "CENTER", -80, 0)
    dropdown:SetWidth(220)
    dropdown:SetupMenu(function(_, root)
        if not row.option then
            return
        end
        local option = row.option
        for _, entry in ipairs(option:Choices()) do
            root:CreateRadio(entry.text, function()
                return option:Read("get") == entry.value
            end, function()
                row:Commit(entry.value)
            end)
        end
    end)
    tooltip(dropdown, row)
    function row:Update()
        local value, label = self.option:Read("get"), ""
        for _, entry in ipairs(self.option:Choices()) do
            if entry.value == value then
                label = entry.text
            end
        end
        dropdown:SetDefaultText(label)
        dropdown:GenerateMenu()
    end
    return row
end

function creators.range(page)
    local row = Row:New(page)
    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    row.Control = slider
    row.rowHeight = 46
    slider:SetPoint("LEFT", row, "CENTER", -80, 3)
    slider:SetSize(250, 26)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        row:Commit(value)
    end, row)
    tooltip(slider, row)
    function row:Update()
        local option = self.option
        local min, max, step = option:Read("min"), option:Read("max"), option:Read("step") or 1
        local formatters = {
            [MinimalSliderWithSteppersMixin.Label.Right] = function(value)
                return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
            end,
        }
        slider:Init(option:Read("get") or min, min, max, math.max(1, (max - min) / step), formatters)
    end
    return row
end

function creators.input(page)
    local row = Row:New(page)
    local input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.Control = input
    input:SetAutoFocus(false)
    input:SetPoint("LEFT", row, "CENTER", -74, 0)
    input:SetSize(230, 22)
    local function commit()
        local value = input:GetText()
        row.syncing = true
        input:ClearFocus()
        row.syncing = false
        row:Commit(value)
    end
    input:SetScript("OnEnterPressed", commit)
    input:SetScript("OnEditFocusLost", function()
        if input:IsShown() then
            row:Commit(input:GetText())
        end
    end)
    input:SetScript("OnEscapePressed", function()
        row.syncing = true
        input:ClearFocus()
        row.syncing = false
        row:Update()
    end)
    tooltip(input, row)
    function row:Update()
        if not input:HasFocus() then
            input:SetText(self.option:Read("get") or "")
        end
    end
    return row
end

function creators.execute(page)
    local row = Row:New(page)
    local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Control = button
    row.tagAnchor = button
    button:SetPoint("LEFT", row, "CENTER", -80, 0)
    button:SetSize(220, 22)
    button:SetScript("OnClick", function()
        row:Commit()
    end)
    tooltip(button, row)
    function row:Update()
        self.Label:SetText("")
        button:SetText(self.option:Read("name"))
    end
    return row
end

function creators.color(page)
    local row = Row:New(page)
    local button = CreateFrame("Button", nil, row, "ColorSwatchTemplate")
    row.Control = button
    button:SetPoint("LEFT", row, "CENTER", -73, 0)
    button:SetScript("OnClick", function()
        local option = row.option
        local r, g, b, a = option:Read("get")
        local function apply(red, green, blue, alpha)
            if option:Read("disabled") then
                return
            end
            option:Read("set", red, green, blue, alpha)
            Registry:NotifyChange(option.appName)
        end
        local function changed()
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            apply(red, green, blue, ColorPickerFrame:GetColorAlpha())
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = a or 1,
            hasOpacity = option:Read("hasAlpha"),
            swatchFunc = changed,
            opacityFunc = changed,
            cancelFunc = function()
                apply(r, g, b, a)
            end,
        })
    end)
    tooltip(button, row)
    function row:Update()
        button:SetColorRGB(self.option:Read("get"))
    end
    return row
end

function creators.description(page)
    local row = Row:New(page)
    row.Label:ClearAllPoints()
    row.Label:SetPoint("TOPLEFT", 37, -8)
    row.Label:SetWidth(page:GetWidth() - 52)
    function row:Update()
        self.Label:SetTextColor(1, 1, 1)
    end
    return row
end

function creators.group(page)
    local row = Row:New(page)
    row.rowHeight = 45
    row.Label:ClearAllPoints()
    row.Label:SetPoint("TOPLEFT", 7, -16)
    row.Label:SetWidth(page:GetWidth() - 50)
    row.Label:SetFontObject("GameFontHighlightLarge")
    row.HeaderButton = CreateFrame("Button", nil, row)
    row.HeaderButton:SetAllPoints()
    row.Toggle = CreateFrame("Button", nil, row.HeaderButton)
    row.Toggle:SetSize(20, 20)
    row.Toggle:SetPoint("RIGHT", -6, 0)
    row.Toggle.Icon = row.Toggle:CreateTexture(nil, "ARTWORK")
    row.Toggle.Icon:SetPoint("CENTER")
    -- These buttons cover the row, so forward hover to its background as well.
    for _, button in ipairs({ row.HeaderButton, row.Toggle }) do
        button:HookScript("OnEnter", function()
            row.Hover:Show()
        end)
        button:HookScript("OnLeave", function()
            row.Hover:Hide()
        end)
    end
    row.Toggle:SetScript("OnMouseDown", function()
        row.Toggle.Icon:SetPoint("CENTER", 1, -1)
    end)
    row.Toggle:SetScript("OnMouseUp", function()
        row.Toggle.Icon:SetPoint("CENTER", 0, 0)
    end)
    local function toggle()
        page.collapsedSections[row.sectionKey] = not page.collapsedSections[row.sectionKey]
        config:RefreshOptionsPage(page)
    end
    row.HeaderButton:SetScript("OnClick", toggle)
    row.Toggle:SetScript("OnClick", toggle)
    function row:Update()
        self.Label:SetTextColor(1, 1, 1)
        local key = ""
        for _, part in ipairs(self.option.path) do
            key = key .. #part .. ":" .. part
        end
        self.sectionKey = key
        self.collapsed = page.collapsedSections[key]
        local atlas = self.collapsed and "common-button-list-plus" or "common-button-list-minus"
        self.Toggle.Icon:SetAtlas(atlas, true)
        self.Toggle:SetHighlightAtlas(atlas, "ADD")
        self.Toggle:GetHighlightTexture():SetAlpha(0.4)
        self.Toggle:GetHighlightTexture():SetAllPoints(self.Toggle.Icon)
    end
    return row
end
creators.header = creators.group

function config:CreateOptionsPage(page, root, key, name)
    page.option = self.Option:New(root, { key }, name)
    page.controlPools = {}
    page.collapsedSections = {}
end

function config:RefreshOptionsPage(page)
    for _, pool in pairs(page.controlPools) do
        pool.used = 0
    end
    local y = 0
    local renderChildren
    local function render(option)
        local kind = option:Read("type")
        local create = assert(creators[kind], "Unsupported config control: " .. tostring(kind))
        local pool = page.controlPools[kind] or { used = 0 }
        page.controlPools[kind] = pool
        pool.used = pool.used + 1
        local row = pool[pool.used] or create(page)
        pool[pool.used] = row
        row:Refresh(option)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        y = y + row:GetHeight()
        if kind == "group" and not row.collapsed then
            renderChildren(option)
        end
        return row.collapsed
    end
    renderChildren = function(parent)
        local hiddenByHeader = false
        for _, child in ipairs(parent:Children()) do
            if child:Read("type") == "header" then
                hiddenByHeader = render(child)
            elseif not hiddenByHeader then
                render(child)
            end
        end
    end
    renderChildren(page.option)
    for _, pool in pairs(page.controlPools) do
        for index = pool.used + 1, #pool do
            pool[index]:Hide()
        end
    end
    page:SetHeight(math.max(1, y + 12))
end
