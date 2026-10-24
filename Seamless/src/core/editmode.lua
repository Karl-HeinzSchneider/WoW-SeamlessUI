---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local addon = app.addon
local lib = app.LibEditMode
local registrations = {}
local panel, scroll, content, restore
local framesHeader
local refreshing = false
local PADDING, HEADER, BOTTOM, GAP = 24, 44, 16, 6
-- Frames checkboxes sit in two columns, filled row by row, like the native Edit Mode window.
local COLUMNS, COLUMN_GAP = 2, 10
-- Minimum gap to the screen bottom and smallest list height before the panel scrolls.
local SCREEN_MARGIN, MIN_VISIBLE = 8, 96
-- Collapse key of the Frames header; editmodelib.lua starts it collapsed.
local FRAMES_SECTION = "panel:frames"
-- The minimized window is remembered account-wide with the collapsed sections, under this key.
local MINIMIZED_KEY = "panel:minimized"

local function Evaluate(value)
    if type(value) == "function" then
        return value()
    end
    return value
end

local function IsEnabled(spec)
    return spec.enabled == nil or not not Evaluate(spec.enabled)
end

-- Anchors/font measurements may settle after the first Show. Coalesce that work
-- on our own frame; never require another click or another Edit Mode entry.
local function QueueRefresh()
    if not panel then
        return
    end
    panel:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        addon:RefreshEditModeOptions()
    end)
end

local function EnsurePanel()
    if panel then
        return
    end
    -- Anchor to native Edit Mode, but never join or dirty its layout hierarchy. Public name for
    -- other addons, macros and /fstack.
    panel = CreateFrame("Frame", "SeamlessEditModeWindow", UIParent)
    panel:Hide()
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetPoint("TOPLEFT", EditModeManagerFrame, "BOTTOMLEFT", 0, -8)
    panel:SetPoint("TOPRIGHT", EditModeManagerFrame, "BOTTOMRIGHT", 0, -8)
    local border = CreateFrame("Frame", nil, panel, "DialogBorderTranslucentTemplate")
    border:SetAllPoints()
    border:SetFrameLevel(panel:GetFrameLevel()) -- Keep its background below control labels.
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText(L["SeamlessUI"])
    -- Minimize sits where native windows put their close button. It swaps the window for a small
    -- restore button under the main Edit Mode window; both are ours, nothing native is touched.
    local minimize = CreateFrame("Button", nil, panel, "UIPanelCloseButtonNoScripts")
    minimize:SetPoint("TOPRIGHT")
    minimize:SetNormalAtlas("RedButton-Condense")
    minimize:SetPushedAtlas("RedButton-Condense-Pressed")
    minimize:SetHighlightAtlas("RedButton-Highlight", "ADD")
    minimize:SetScript("OnClick", function()
        app.SetEditModeSectionCollapsed(MINIMIZED_KEY, true)
        addon:RefreshEditModeOptions()
    end)
    restore = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    restore:Hide()
    restore:SetFrameStrata("DIALOG")
    restore:SetPoint("TOP", EditModeManagerFrame, "BOTTOM", 0, -8)
    restore:SetText(L["SeamlessUI"])
    restore:SetSize(restore:GetTextWidth() + 40, 26)
    restore:SetScript("OnClick", function()
        app.SetEditModeSectionCollapsed(MINIMIZED_KEY, false)
        addon:RefreshEditModeOptions()
    end)
    -- Rows live in a scroll child, like Blizzard's own Edit Mode settings container.
    scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PADDING, -HEADER)
    scroll:SetPoint("TOPRIGHT", -PADDING, -HEADER)
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    scroll:EnableMouseWheel(true)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    -- Collapsible like the Position header of the frame settings window, across the full width.
    framesHeader = app.CreateEditModeHeader(content, function()
        if lib:IsInEditMode() then
            app.SetEditModeSectionCollapsed(FRAMES_SECTION, not app.IsEditModeSectionCollapsed(FRAMES_SECTION))
        end
        addon:RefreshEditModeOptions()
    end)
    framesHeader:SetHeaderText(L["Frames"])
    framesHeader:Hide()
    panel:SetScript("OnShow", QueueRefresh)
    panel:SetScript("OnSizeChanged", QueueRefresh)
end

local function CanInteract(spec, option)
    return lib:IsInEditMode()
        and not InCombatLockdown()
        and IsEnabled(spec)
        and not Evaluate(option.hidden)
        and not Evaluate(option.disabled)
end

local function SectionKey(id, option)
    return "panel:" .. id .. ":" .. option.key
end

local function CreateRow(option, spec, id)
    local row
    if option.type == "custom" then
        row = option.create(content)
        assert(
            row and row.GetHeight and row.GetParent and row:GetParent() == content,
            "Custom Edit Mode rows must return a frame parented to the supplied panel"
        )
    else
        if option.type == "header" then
            -- Collapsible section header, the same one the frame settings window uses.
            row = app.CreateEditModeHeader(content, function()
                if lib:IsInEditMode() and not InCombatLockdown() then
                    local key = SectionKey(id, row.option)
                    app.SetEditModeSectionCollapsed(key, not app.IsEditModeSectionCollapsed(key))
                end
                addon:RefreshEditModeOptions()
            end)
        else
            row = CreateFrame("Frame", nil, content)
        end
        if option.type == "toggle" then
            row.Button = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.Button:SetSize(28, 28)
            row.Button:SetPoint("TOPLEFT", 0, -2)
            -- Use the checkbox's own text region so it shares the control's draw level.
            row.Label = row.Button.Text
            row.Label:SetFontObject(GameFontHighlightMedium)
            row.Label:ClearAllPoints()
            row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", 32, -8)
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
        if refreshing then
            QueueRefresh()
        else
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
            panel:SetScript("OnUpdate", nil)
            panel:Hide()
            restore:Hide()
        end
        return
    end
    refreshing = true
    local groups = {}
    for id, registration in pairs(registrations) do
        groups[#groups + 1] = { id = id, registration = registration }
    end
    table.sort(groups, function(a, b)
        local leftSection = a.registration.spec.section == "frames" and 2 or 1
        local rightSection = b.registration.spec.section == "frames" and 2 or 1
        if leftSection ~= rightSection then
            return leftSection < rightSection
        end
        local left, right = a.registration.spec.order or 100, b.registration.spec.order or 100
        if left == right then
            return a.id < b.id
        end
        return left < right
    end)
    if #groups > 0 then
        EnsurePanel()
    end
    local panelWidth = panel and panel:GetWidth() or 0
    if panel and panelWidth <= 0 then
        panelWidth = EditModeManagerFrame:GetWidth()
    end
    local width = math.max(1, panelWidth - PADDING * 2)
    local y, count = 0, 0
    local framesStarted = false
    local framesCollapsed = app.IsEditModeSectionCollapsed(FRAMES_SECTION)
    local columnWidth = math.max(1, math.floor((width - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS))
    -- Next free column of the current Frames grid line, its top and its tallest cell so far.
    local column, lineTop, lineHeight = 0, 0, 0
    local function EndLine()
        if column > 0 then
            y = lineTop + lineHeight + GAP
            column, lineHeight = 0, 0
        end
    end
    if framesHeader then
        framesHeader:Hide()
    end
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
            EndLine()
        end
        if hasRows and spec.section == "frames" and not framesStarted then
            framesStarted = true
            if count > 0 then
                y = y + GAP
            end
            framesHeader:ClearAllPoints()
            framesHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            framesHeader:SetWidth(width)
            framesHeader:UpdateCollapsedState(framesCollapsed)
            framesHeader:Show()
            y = y + framesHeader:GetHeight() + GAP
            count = count + 1
        end
        -- A collapsed Frames header hides every frames group, titles included.
        if spec.section == "frames" and framesCollapsed then
            visible, hasRows = false, false
        end
        if hasRows and spec.name then
            if not registration.title then
                registration.title = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                registration.title:SetJustifyH("LEFT")
                registration.title:SetWordWrap(true)
            end
            local title = registration.title
            title:ClearAllPoints()
            title:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            title:SetWidth(width)
            title:SetText(spec.name)
            title:Show()
            y = y + title:GetStringHeight() + GAP
        end
        local collapsed = false
        for _, entry in ipairs(options) do
            local option = entry.option
            local row = registration.rows[option.key]
            local shown = visible and not Evaluate(option.hidden)
            if option.type == "header" then
                collapsed = shown and app.IsEditModeSectionCollapsed(SectionKey(group.id, option))
            elseif collapsed then
                shown = false
            end
            if shown then
                if not row then
                    row = CreateRow(option, spec, group.id)
                    registration.rows[option.key] = row
                end
                local cell = spec.section == "frames" and option.type == "toggle"
                local rowWidth = cell and columnWidth or width
                if not cell then
                    EndLine()
                elseif column == 0 then
                    lineTop = y
                end
                row:ClearAllPoints()
                if cell then
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", column * (columnWidth + COLUMN_GAP), -lineTop)
                else
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                end
                row:SetWidth(rowWidth)
                local disabled = InCombatLockdown() or not not Evaluate(option.disabled)
                local height
                if option.type == "header" then
                    row:SetHeaderText(option.name)
                    row:UpdateCollapsedState(collapsed)
                    height = 28
                elseif option.type == "toggle" then
                    row.Label:SetWidth(math.max(1, rowWidth - 32))
                    row.Label:SetText(option.name)
                    row.Label:Show()
                    row.Label:SetTextColor((disabled and DISABLED_FONT_COLOR or WHITE_FONT_COLOR):GetRGB())
                    row.Button:SetChecked(not not option.get())
                    row.Button:SetEnabled(not disabled)
                    height = math.max(32, row.Label:GetStringHeight() + 16)
                elseif option.type == "button" then
                    row.Button:SetWidth(rowWidth)
                    row.Button:SetText(option.name)
                    row.Button:SetEnabled(not disabled)
                    height = 32
                else
                    -- Custom rows own their widgets; layout may return a measured height.
                    height = option.layout and option.layout(row, rowWidth, disabled) or row:GetHeight()
                end
                height = math.max(1, height)
                row:SetHeight(height)
                row:Show()
                if cell then
                    lineHeight = math.max(lineHeight, height)
                    column = column + 1
                    if column == COLUMNS then
                        EndLine()
                    end
                else
                    y = y + height + GAP
                end
                count = count + 1
            elseif row then
                row:Hide()
            end
        end
    end
    EndLine()
    if panel then
        local contentHeight = math.max(1, y - (count > 0 and GAP or 0))
        content:SetSize(width, contentHeight)
        -- Cap the panel at the screen bottom; the rest scrolls.
        local visible = contentHeight
        local top = panel:GetTop()
        if top then
            visible = math.min(visible, math.max(MIN_VISIBLE, top - SCREEN_MARGIN - HEADER - BOTTOM))
        end
        scroll:SetHeight(visible)
        panel:SetHeight(HEADER + visible + BOTTOM)
        local minimized = app.IsEditModeSectionCollapsed(MINIMIZED_KEY)
        panel:SetShown(count > 0 and not minimized)
        restore:SetShown(count > 0 and minimized)
    end
    refreshing = false
end

---Register a feature's ordered rows. Register once; use RefreshEditModeOptions for state changes.
---@param id string Unique feature identifier.
---@param spec SeamlessCore.EditModeOptions
function addon:RegisterEditModeOptions(id, spec)
    assert(type(id) == "string" and id ~= "" and not registrations[id], "Edit Mode option id must be unique")
    assert(type(spec) == "table" and type(spec.options) == "table", "Edit Mode options are required")
    assert(spec.section == nil or spec.section == "options" or spec.section == "frames", "Unknown Edit Mode section")
    local keys = {}
    for _, option in ipairs(spec.options) do
        assert(type(option.key) == "string" and not keys[option.key], "Edit Mode row keys must be unique")
        keys[option.key] = true
        assert(
            option.type == "toggle" or option.type == "button" or option.type == "custom" or option.type == "header",
            "Unknown Edit Mode row type"
        )
        if option.type == "toggle" then
            assert(type(option.get) == "function" and type(option.set) == "function", "Toggle needs get/set")
        elseif option.type == "button" then
            assert(type(option.click) == "function", "Button needs click")
        elseif option.type == "custom" then
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
