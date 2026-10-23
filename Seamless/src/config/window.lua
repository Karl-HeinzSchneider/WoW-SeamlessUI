---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local config = app.config
local NAVIGATION_PANE_WIDTH, SCROLLBAR_GUTTER = 199, 24
local NAVIGATION_WIDTH = NAVIGATION_PANE_WIDTH - SCROLLBAR_GUTTER
local NAVIGATION_ROW_GAP = 1
local NAVIGATION_PAGE_HEIGHT, NAVIGATION_HEADER_HEIGHT = 20, 30

local function label(parent, font, text, point, relative, relativePoint, x, y)
    local textRegion = parent:CreateFontString(nil, "OVERLAY", font)
    textRegion:SetText(text)
    textRegion:SetPoint(point, relative, relativePoint, x, y)
    textRegion:SetJustifyH("LEFT")
    return textRegion
end

-- Takes up a page row's space without showing anything.
local function spacer(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(NAVIGATION_WIDTH, NAVIGATION_PAGE_HEIGHT)
    return frame
end

local function scroll(parent, x, width)
    local frame = CreateFrame("ScrollFrame", nil, parent)
    frame:SetPoint("TOPLEFT", x, -76)
    frame:SetPoint("BOTTOMLEFT", x, 46)
    frame:SetWidth(width)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(width, 1)
    frame:SetScrollChild(child)
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 2)
    bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -1, 7)
    bar:Init(1, 0.1)
    bar:SetHideIfUnscrollable(false)
    bar:RegisterCallback("OnScroll", function(_, percentage)
        frame:SetVerticalScroll(percentage * math.max(0, child:GetHeight() - frame:GetHeight()))
    end, frame)
    local function update()
        local height = math.max(1, child:GetHeight())
        local range = math.max(0, height - frame:GetHeight())
        if frame:GetVerticalScroll() > range then
            frame:SetVerticalScroll(range)
        end
        bar:SetVisibleExtentPercentage(math.min(1, frame:GetHeight() / height))
        bar:SetScrollAllowed(range > 0)
        bar:SetShown(not (frame == config.navigation and config.minimized))
        bar:DesaturateHierarchy(range > 0 and 0 or 1)
        bar:SetAlpha(range > 0 and 1 or 0.45)
        bar:SetScrollPercentage(range > 0 and math.min(1, frame:GetVerticalScroll() / range) or 0, true)
    end
    child:SetScript("OnSizeChanged", update)
    frame:SetScript("OnSizeChanged", update)
    frame:SetScript("OnVerticalScroll", function(_, offset)
        local range = math.max(0, child:GetHeight() - frame:GetHeight())
        local percentage = range > 0 and offset / range or 0
        if math.abs(bar:GetScrollPercentage() - percentage) > 0.0001 then
            bar:SetScrollPercentage(percentage, true)
        end
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local range = math.max(0, child:GetHeight() - frame:GetHeight())
        frame:SetVerticalScroll(math.max(0, math.min(range, frame:GetVerticalScroll() - delta * 30)))
    end)
    return frame, child, bar
end

function config:CreateWindow()
    if self.frame then
        return
    end
    -- SharedXML primitives are loaded by the client. The SettingsPanel's own
    -- templates/mixins are deliberately not inherited: this window owns its state.
    local frame = CreateFrame("Frame", "SeamlessConfigWindow", UIParent)
    self.frame = frame
    frame:Hide()
    frame:SetSize(920, 724)
    frame:SetScale(math.min(1, (UIParent:GetWidth() - 40) / 920, (UIParent:GetHeight() - 40) / 724))
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "SeamlessConfigWindow")

    local background = CreateFrame("Frame", nil, frame, "FlatPanelBackgroundTemplate")
    background:SetFrameLevel(frame:GetFrameLevel())
    background:SetPoint("TOPLEFT", 7, -18)
    background:SetPoint("BOTTOMRIGHT", -3, 3)
    local border = CreateFrame("Frame", nil, frame, "NineSlicePanelTemplate")
    border:SetAllPoints()
    NineSliceUtil.ApplyLayoutByName(border, "ButtonFrameTemplateNoPortrait")
    label(border, "GameFontNormal", L["Seamless"], "TOP", border, "TOP", 0, -5)
    local inner = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    self.inner = inner
    inner:SetAtlas("Options_InnerFrame", true)
    inner:SetPoint("TOPLEFT", 17, -64)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
    close:SetScript("OnClick", function()
        frame:Hide()
    end)
    -- Match the close button's explicit textures and high frame level so the
    -- title-border artwork cannot cover this control.
    local minimize = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    self.minimize = minimize
    minimize:SetFrameLevel(close:GetFrameLevel())
    minimize:SetSize(28, 28)
    minimize:SetPoint("RIGHT", close, "LEFT", 0, 0)
    minimize:SetNormalAtlas("RedButton-Condense")
    minimize:SetPushedAtlas("RedButton-Condense-Pressed")
    minimize:SetHighlightAtlas("RedButton-Highlight", "ADD")
    minimize:SetScript("OnClick", function()
        self:SetMinimized(not self.minimized)
    end)
    local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    self.done = done
    done:SetSize(96, 22)
    done:SetPoint("BOTTOMRIGHT", -16, 16)
    done:SetText(L["Close"])
    done:SetScript("OnClick", function()
        frame:Hide()
    end)

    local tab = CreateFrame("Button", nil, frame, "MinimalTabTemplate")
    self.tab = tab
    tab:SetPoint("TOPLEFT", 32, -27)
    tab.Text:SetText(L["Config"])
    tab:SetWidth(tab.Text:GetStringWidth() + 40)
    tab:SetSelected(true)
    tab:SetScript("OnClick", function()
        tab:SetSelected(true)
    end)

    self.navigation, self.list, self.navigationBar = scroll(frame, 18, NAVIGATION_WIDTH)
    -- The native inner-frame divider is at the right of the 199-pixel pane.
    -- Center the entire scrollbar (17-pixel arrows, 8-pixel track) in its gutter.
    -- TOP/BOTTOM anchor its center; TOPLEFT would push half the track to the right.
    self.navigationBar:ClearAllPoints()
    self.navigationBar:SetPoint("TOP", self.navigation, "TOPRIGHT", SCROLLBAR_GUTTER / 2, -8)
    self.navigationBar:SetPoint("BOTTOM", self.navigation, "BOTTOMRIGHT", SCROLLBAR_GUTTER / 2, 8)
    self.contentScroll, self.content = scroll(frame, 233, 643)
    self.contentScroll:SetPoint("TOPLEFT", 233, -137)
    self.title = label(frame, "GameFontHighlightHuge", "", "TOPLEFT", frame, "TOPLEFT", 240, -98)
    self.title:SetWidth(620)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    self.divider = divider
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", frame, "TOPLEFT", 565.5, -126)
    self.pageHost = CreateFrame("Frame", nil, self.content)
    self.pageHost:SetPoint("TOPLEFT", 8, 0)
    self.pageHost:SetSize(627, 1)
    self.contentScroll:HookScript("OnSizeChanged", function()
        self:UpdateContentHeight()
    end)
end

function config:SetMinimized(minimized)
    self.minimized = minimized
    local frame = self.frame
    -- Retain the dragged top-left position while changing the window's bounds.
    local left, top = frame:GetLeft(), frame:GetTop()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    frame:SetSize(minimized and 705 or 920, minimized and 600 or 724)
    self.navigation:SetShown(not minimized)
    self.navigationBar:SetShown(not minimized)
    self.tab:SetShown(not minimized)
    self.inner:SetShown(not minimized)
    self.done:SetShown(not minimized)
    local x, topOffset = minimized and 18 or 233, minimized and 81 or 137
    self.contentScroll:ClearAllPoints()
    self.contentScroll:SetPoint("TOPLEFT", x, -topOffset)
    self.contentScroll:SetPoint("BOTTOMLEFT", x, minimized and 18 or 46)
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", frame, "TOPLEFT", x + 7, minimized and -42 or -98)
    self.divider:ClearAllPoints()
    self.divider:SetPoint("TOP", frame, "TOPLEFT", x + 332.5, minimized and -70 or -126)
    local atlas = minimized and "RedButton-Expand" or "RedButton-Condense"
    self.minimize:SetNormalAtlas(atlas)
    self.minimize:SetPushedAtlas(atlas .. "-Pressed")
    self:Refresh()
end

function config:UpdateContentHeight()
    local page = self.pages[self.selected]
    self.content:SetHeight(math.max(self.contentScroll:GetHeight(), page and page:GetHeight() or 1))
end

function config:Select(id)
    self.selected = id
    self.contentScroll:SetVerticalScroll(0)
    self:Refresh()
end

function config:CreateRow(index)
    local row = CreateFrame("Button", nil, self.list)
    self.rows[index] = row
    row:SetWidth(NAVIGATION_WIDTH)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetPoint("TOPLEFT")
    row.active = row:CreateTexture(nil, "ARTWORK")
    row.active:SetPoint("CENTER")
    row.text = label(row, "GameFontNormal", "", "LEFT", row, "LEFT", 36, 1)
    row.text:SetPoint("RIGHT", -4, 0)
    row.toggle = CreateFrame("Button", nil, row)
    row.toggle:SetSize(20, 20)
    row.toggle.icon = row.toggle:CreateTexture(nil, "ARTWORK")
    row.toggle.icon:SetPoint("CENTER")
    row.toggle:SetScript("OnMouseDown", function()
        row.toggle.icon:SetPoint("CENTER", 1, -1)
    end)
    row.toggle:SetScript("OnMouseUp", function()
        row.toggle.icon:SetPoint("CENTER", 0, 0)
    end)
    row.toggle:SetScript("OnClick", function()
        self.collapsed[row.id] = not self.collapsed[row.id]
        self:Refresh()
    end)
    row:SetScript("OnClick", function()
        if self.categories[row.id].header then
            self.collapsed[row.id] = not self.collapsed[row.id]
            self:Refresh()
        else
            self:Select(row.id)
        end
    end)
    row:SetScript("OnEnter", function()
        if row.id ~= self.selected then
            row.active:SetAtlas("Options_List_Hover", true)
            row.active:SetWidth(NAVIGATION_WIDTH)
            row.active:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        row.active:SetShown(row.id == self.selected)
    end)
    return row
end

function config:Refresh()
    local y, headerIndex = 0, 0
    local visible = self:GetVisibleCategories()
    for index, entry in ipairs(visible) do
        if index > 1 then
            y = y + NAVIGATION_ROW_GAP
        end
        local category, depth = entry.category, entry.depth
        local row = self.rows[index] or self:CreateRow(index)
        row.id = category.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetHeight(category.header and NAVIGATION_HEADER_HEIGHT or NAVIGATION_PAGE_HEIGHT)
        row.text:SetText(category.name)
        row.text:SetFontObject(
            category.header and "GameFontHighlightMedium"
                or (category.id == self.selected and "GameFontHighlight" or "GameFontNormal")
        )
        row.text:ClearAllPoints()
        -- Pages start at 36 below their header (depth 1), like Blizzard's list; deeper levels indent 12 more.
        row.text:SetPoint("LEFT", (category.header and 20 or 24) + depth * 12, category.header and -1 or 1)
        row.text:SetPoint("RIGHT", category.header and -30 or -4, 0)
        self:UpdateFeatureTags(row, row.text, category)
        row.background:SetShown(category.header == true)
        if category.header then
            headerIndex = headerIndex + 1
            row.background:SetAtlas("Options_CategoryHeader_" .. ((headerIndex - 1) % 2 + 1), true)
            row.background:SetWidth(NAVIGATION_WIDTH)
        end
        row.active:SetAtlas("Options_List_Active", true)
        row.active:SetWidth(NAVIGATION_WIDTH)
        row.active:SetShown(category.id == self.selected)
        local hasChildren = #self:GetChildren(category.id) > 0
        row.toggle:SetShown(hasChildren)
        row.toggle:ClearAllPoints()
        if category.header then
            row.toggle:SetPoint("RIGHT", -6, 0)
        else
            row.toggle:SetPoint("LEFT", -3 + depth * 12, 0)
        end
        local atlas = self.collapsed[category.id] and "common-button-list-plus" or "common-button-list-minus"
        row.toggle.icon:SetAtlas(atlas, true)
        row.toggle:SetHighlightAtlas(atlas, "ADD")
        row.toggle:GetHighlightTexture():SetAlpha(0.4)
        row.toggle:GetHighlightTexture():SetAllPoints(row.toggle.icon)
        row:Show()
        y = y + row:GetHeight()
    end
    for index = #visible + 1, #self.rows do
        self.rows[index]:Hide()
    end
    self.listEnd = self.listEnd or spacer(self.list)
    self.listEnd:SetPoint("TOPLEFT", 0, -(y + NAVIGATION_ROW_GAP))
    y = y + NAVIGATION_ROW_GAP + self.listEnd:GetHeight()
    self.list:SetHeight(math.max(1, y))
    self.navigation:SetVerticalScroll(
        math.min(self.navigation:GetVerticalScroll(), math.max(0, y - self.navigation:GetHeight()))
    )
    for _, page in pairs(self.pages) do
        page:Hide()
    end
    local category = self.categories[self.selected]
    self.title:SetText(category and category.name or "")
    if category then
        local page = self.pages[category.id]
        if not page then
            page = CreateFrame("Frame", nil, self.pageHost)
            page:SetPoint("TOPLEFT")
            page:SetSize(self.pageHost:GetWidth(), 1)
            self.pages[category.id] = page
            page:SetScript("OnSizeChanged", function()
                self:UpdateContentHeight()
            end)
            if category.create then
                category.create(page)
            end
        end
        page:Show()
        if category.refresh then
            category.refresh(page)
        end
    end
    self:UpdateContentHeight()
end
