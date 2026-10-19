---@type string, SeamlessCore
local _, app = ...

local addon = app.addon
local lib = app.LibEditMode
local registrations = {}
local panel
local refreshing = false
local PADDING, HEADER, BOTTOM, GAP = 24, 44, 16, 6

local function Evaluate(value)
    if type(value) == "function" then
        return value()
    end
    return value
end

local function IsEnabled(spec)
    return spec.enabled == nil or not not Evaluate(spec.enabled)
end

local function EnsurePanel()
    if panel then
        return
    end
    -- Anchor to native Edit Mode, but never join or dirty its layout hierarchy.
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetPoint("TOPLEFT", EditModeManagerFrame, "BOTTOMLEFT", 0, -8)
    panel:SetPoint("TOPRIGHT", EditModeManagerFrame, "BOTTOMRIGHT", 0, -8)
    local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("SeamlessUI")
    panel:SetScript("OnSizeChanged", function()
        if not refreshing then
            addon:RefreshEditModeOptions()
        end
    end)
end

local function CanInteract(spec, option)
    return lib:IsInEditMode()
        and not InCombatLockdown()
        and IsEnabled(spec)
        and not Evaluate(option.hidden)
        and not Evaluate(option.disabled)
end

local function CreateRow(option, spec)
    local row
    if option.type == "custom" then
        row = option.create(panel)
        assert(
            row and row.GetHeight and row.GetParent and row:GetParent() == panel,
            "Custom Edit Mode rows must return a frame parented to the supplied panel"
        )
    else
        row = CreateFrame("Frame", nil, panel)
        if option.type == "toggle" then
            row.Button = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.Button:SetSize(28, 28)
            row.Button:SetPoint("TOPLEFT", 0, -2)
            row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
            row.Label:SetPoint("TOPLEFT", 32, -8)
            row.Label:SetJustifyH("LEFT")
            row.Label:SetWordWrap(true)
            row.Button:SetScript("OnClick", function(button)
                local data = row.option
                if CanInteract(spec, data) then
                    data.set(not not button:GetChecked())
                end
                addon:RefreshEditModeOptions()
            end)
        else
            row.Button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.Button:SetPoint("TOPLEFT")
            row.Button:SetHeight(28)
            row.Button:SetScript("OnClick", function()
                local data = row.option
                if CanInteract(spec, data) then
                    data.click()
                end
                addon:RefreshEditModeOptions()
            end)
        end
    end
    row.option = option
    row:HookScript("OnSizeChanged", function()
        if not refreshing then
            addon:RefreshEditModeOptions()
        end
    end)
    return row
end

---Refresh values, visibility, wrapping and panel height after an addon/profile change.
function addon:RefreshEditModeOptions()
    if refreshing then
        return
    end
    if not lib:IsInEditMode() then
        if panel then
            panel:Hide()
        end
        return
    end
    refreshing = true
    local groups = {}
    for id, registration in pairs(registrations) do
        groups[#groups + 1] = { id = id, registration = registration }
    end
    table.sort(groups, function(a, b)
        local left, right = a.registration.spec.order or 100, b.registration.spec.order or 100
        if left == right then
            return a.id < b.id
        end
        return left < right
    end)
    if #groups > 0 then
        EnsurePanel()
    end
    local width = panel and math.max(1, panel:GetWidth() - PADDING * 2) or 1
    local y, count = HEADER, 0
    for _, group in ipairs(groups) do
        local registration = group.registration
        local spec = registration.spec
        local visible = IsEnabled(spec)
        local options = {}
        for index, option in ipairs(spec.options) do
            options[#options + 1] = { index = index, option = option }
        end
        table.sort(options, function(a, b)
            local left, right = a.option.order or a.index, b.option.order or b.index
            return left == right and a.index < b.index or left < right
        end)
        local hasRows = false
        for _, entry in ipairs(options) do
            if visible and not Evaluate(entry.option.hidden) then
                hasRows = true
            end
        end
        if registration.title then
            registration.title:Hide()
        end
        if hasRows and spec.name then
            if not registration.title then
                registration.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                registration.title:SetJustifyH("LEFT")
                registration.title:SetWordWrap(true)
            end
            local title = registration.title
            title:ClearAllPoints()
            title:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -y)
            title:SetWidth(width)
            title:SetText(spec.name)
            title:Show()
            y = y + title:GetStringHeight() + GAP
        end
        for _, entry in ipairs(options) do
            local option = entry.option
            local row = registration.rows[option.key]
            if visible and not Evaluate(option.hidden) then
                if not row then
                    row = CreateRow(option, spec)
                    registration.rows[option.key] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -y)
                row:SetWidth(width)
                local disabled = InCombatLockdown() or not not Evaluate(option.disabled)
                local height
                if option.type == "toggle" then
                    row.Label:SetWidth(math.max(1, width - 32))
                    row.Label:SetText(option.name)
                    row.Label:SetTextColor((disabled and DISABLED_FONT_COLOR or WHITE_FONT_COLOR):GetRGB())
                    row.Button:SetChecked(not not option.get())
                    row.Button:SetEnabled(not disabled)
                    height = math.max(32, row.Label:GetStringHeight() + 16)
                elseif option.type == "button" then
                    row.Button:SetWidth(width)
                    row.Button:SetText(option.name)
                    row.Button:SetEnabled(not disabled)
                    height = 32
                else
                    -- Custom rows own their widgets; layout may return a measured height.
                    height = option.layout and option.layout(row, width, disabled) or row:GetHeight()
                end
                height = math.max(1, height)
                row:SetHeight(height)
                row:Show()
                y = y + height + GAP
                count = count + 1
            elseif row then
                row:Hide()
            end
        end
    end
    if panel then
        panel:SetHeight(y - (count > 0 and GAP or 0) + BOTTOM)
        panel:SetShown(count > 0)
    end
    refreshing = false
end

---Register a feature's ordered rows. Register once; use RefreshEditModeOptions for state changes.
---@param id string Unique feature identifier.
---@param spec SeamlessCore.EditModeOptions
function addon:RegisterEditModeOptions(id, spec)
    assert(type(id) == "string" and id ~= "" and not registrations[id], "Edit Mode option id must be unique")
    assert(type(spec) == "table" and type(spec.options) == "table", "Edit Mode options are required")
    local keys = {}
    for _, option in ipairs(spec.options) do
        assert(type(option.key) == "string" and not keys[option.key], "Edit Mode row keys must be unique")
        keys[option.key] = true
        assert(
            option.type == "toggle" or option.type == "button" or option.type == "custom",
            "Unknown Edit Mode row type"
        )
        if option.type == "toggle" then
            assert(type(option.get) == "function" and type(option.set) == "function", "Toggle needs get/set")
        elseif option.type == "button" then
            assert(type(option.click) == "function", "Button needs click")
        else
            assert(type(option.create) == "function", "Custom row needs create")
        end
        if option.type ~= "custom" then
            assert(type(option.name) == "string", "Row label is required")
        end
    end
    registrations[id] = { spec = spec, rows = {} }
    self:RefreshEditModeOptions()
end

lib:RegisterCallback("enter", function()
    addon:RefreshEditModeOptions()
end)
lib:RegisterCallback("exit", function()
    addon:RefreshEditModeOptions()
end)
lib:RegisterCallback("layout", function()
    addon:RefreshEditModeOptions()
end)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    addon:RefreshEditModeOptions()
end)
