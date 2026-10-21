---@type string, SeamlessCore
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local config = app.config

local function label(parent, font, text, point, relative, relativePoint, x, y)
    local textRegion = parent:CreateFontString(nil, "OVERLAY", font)
    textRegion:SetText(text)
    textRegion:SetPoint(point, relative, relativePoint, x, y)
    textRegion:SetJustifyH("LEFT")
    return textRegion
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
    bar:RegisterCallback("OnScroll", function(_, percentage)
        frame:SetVerticalScroll(percentage * math.max(0, child:GetHeight() - frame:GetHeight()))
    end, frame)
    local function update()
        local height = math.max(1, child:GetHeight())
        local range = math.max(0, height - frame:GetHeight())
        bar:SetVisibleExtentPercentage(math.min(1, frame:GetHeight() / height))
        bar:SetScrollAllowed(range > 0)
        bar:SetShown(range > 0)
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
    return frame, child
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
    inner:SetAtlas("Options_InnerFrame", true)
    inner:SetPoint("TOPLEFT", 17, -64)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
    close:SetScript("OnClick", function()
        frame:Hide()
    end)
    local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    done:SetSize(96, 22)
    done:SetPoint("BOTTOMRIGHT", -16, 16)
    done:SetText(L["Close"])
    done:SetScript("OnClick", function()
        frame:Hide()
    end)

    local tab = CreateFrame("Button", nil, frame, "MinimalTabTemplate")
    tab:SetPoint("TOPLEFT", 32, -27)
    tab.Text:SetText(L["Config"])
    tab:SetWidth(tab.Text:GetStringWidth() + 40)
    tab:SetSelected(true)
    tab:SetScript("OnClick", function()
        tab:SetSelected(true)
    end)

    self.navigation, self.list = scroll(frame, 18, 199)
    self.contentScroll, self.content = scroll(frame, 233, 643)
    self.contentScroll:SetPoint("TOPLEFT", 233, -137)
    self.title = label(frame, "GameFontHighlightHuge", "", "TOPLEFT", frame, "TOPLEFT", 240, -98)
    self.title:SetWidth(620)
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", frame, "TOPLEFT", 565.5, -126)
    self.pageHost = CreateFrame("Frame", nil, self.content)
    self.pageHost:SetPoint("TOPLEFT", 8, 0)
    self.pageHost:SetSize(627, 1)
    self.contentScroll:HookScript("OnSizeChanged", function()
        self:UpdateContentHeight()
    end)
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
    row:SetWidth(199)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetPoint("TOPLEFT")
    row.active = row:CreateTexture(nil, "ARTWORK")
    row.active:SetPoint("CENTER")
    row.text = label(row, "GameFontNormal", "", "LEFT", row, "LEFT", 36, 1)
    row.text:SetPoint("RIGHT", -4, 0)
    row.toggle = CreateFrame("Button", nil, row)
    row.toggle:SetSize(22, 22)
    row.toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
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
        local category, depth = entry.category, entry.depth
        local row = self.rows[index] or self:CreateRow(index)
        row.id = category.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetHeight(category.header and 30 or 20)
        row.text:SetText(category.name)
        row.text:SetFontObject(
            category.header and "GameFontHighlightMedium"
                or (category.id == self.selected and "GameFontHighlight" or "GameFontNormal")
        )
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", 36 + depth * 12, category.header and -1 or 1)
        row.text:SetPoint("RIGHT", -4, 0)
        row.background:SetShown(category.header == true)
        if category.header then
            headerIndex = headerIndex + 1
            row.background:SetAtlas("Options_CategoryHeader_" .. ((headerIndex - 1) % 2 + 1), true)
        end
        row.active:SetAtlas("Options_List_Active", true)
        row.active:SetShown(category.id == self.selected)
        local hasChildren = #self:GetChildren(category.id) > 0
        row.toggle:SetShown(hasChildren)
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("LEFT", 9 + depth * 12, 0)
        local texture = self.collapsed[category.id] and "Plus" or "Minus"
        row.toggle:SetNormalTexture("Interface\\Buttons\\UI-" .. texture .. "Button-UP")
        row.toggle:SetPushedTexture("Interface\\Buttons\\UI-" .. texture .. "Button-DOWN")
        row:Show()
        y = y + row:GetHeight()
    end
    for index = #visible + 1, #self.rows do
        self.rows[index]:Hide()
    end
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
