---@type string, SeamlessDamageMeter
local _, app = ...

app.windows = {}
app.windowFrames = {}
local HEADER_HEIGHT = 32

local function Label(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
end

local function AtlasButton(button, normal, pressed, highlight)
    button:SetText("")
    button:SetNormalAtlas(normal)
    button:SetPushedAtlas(pressed)
    button:SetHighlightAtlas(highlight)
end

local function Button(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 22)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontNormalSmall")
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Selector(parent, callback, compact)
    local button = Button(parent, "", 100, callback)
    button.text = Label(button, "GameFontNormalMed1")
    button.text:SetPoint("LEFT", compact and 0 or 25, compact and 0 or 3)
    button.text:SetPoint("RIGHT", 0, compact and 0 or 3)
    button.text:SetJustifyH(compact and "CENTER" or "LEFT")
    button.text:SetWordWrap(false)
    if compact then
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetAtlas("common-dropdown-c-button")
        background:SetPoint("TOPLEFT", -7, 7)
        background:SetPoint("BOTTOMRIGHT", 7, -7)
        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetAtlas("common-dropdown-c-button-hover-arrow", true)
        arrow:SetPoint("BOTTOM", 0, -5)
        arrow:Hide()
        button:SetScript("OnEnter", function()
            background:SetAtlas("common-dropdown-c-button-hover-2")
            arrow:Show()
        end)
        button:SetScript("OnLeave", function()
            background:SetAtlas("common-dropdown-c-button")
            arrow:Hide()
        end)
        button:SetScript("OnMouseDown", function()
            background:SetAtlas("common-dropdown-c-button-pressed-2")
        end)
        button:SetScript("OnMouseUp", function()
            background:SetAtlas("common-dropdown-c-button-hover-2")
        end)
    else
        local arrow = button:CreateTexture(nil, "ARTWORK")
        arrow:SetAtlas("common-dropdown-a-button-shadowless", true)
        arrow:SetPoint("CENTER", button, "LEFT", 12.5, 0)
        button:SetScript("OnEnter", function()
            arrow:SetAtlas("common-dropdown-a-button-hover-shadowless", true)
        end)
        button:SetScript("OnLeave", function()
            arrow:SetAtlas("common-dropdown-a-button-shadowless", true)
        end)
        button:SetScript("OnMouseDown", function()
            arrow:SetAtlas("common-dropdown-a-button-pressed-shadowless", true)
        end)
        button:SetScript("OnMouseUp", function()
            arrow:SetAtlas("common-dropdown-a-button-hover-shadowless", true)
        end)
    end
    return button
end

local function AnchorCoordinates(frame, point)
    local x = point:find("LEFT") and frame:GetLeft() or point:find("RIGHT") and frame:GetRight() or frame:GetCenter()
    local _, centerY = frame:GetCenter()
    local y = point:find("TOP") and frame:GetTop() or point:find("BOTTOM") and frame:GetBottom() or centerY
    return x * frame:GetEffectiveScale(), y * frame:GetEffectiveScale()
end

function app:IsWindowCollapsed(config)
    return config.collapsed and not (self.IsEditingWindows and self:IsEditingWindows())
end

local function CollapseOffset(config)
    if not app:IsWindowCollapsed(config) then
        return 0
    end
    local point = app:GetWindowSetting(config, "point")
    local fraction = point:find("TOP") and 0 or point:find("BOTTOM") and 1 or 0.5
    return (app:GetWindowSetting(config, "height") - HEADER_HEIGHT) * fraction
end

function app:PositionWindow(frame)
    local config = frame.config
    frame.positioning = true
    frame:ClearAllPoints()
    frame:SetPoint(
        self:GetWindowSetting(config, "point"),
        frame.anchorTarget or UIParent,
        self:GetWindowSetting(config, "relativePoint"),
        self:GetWindowSetting(config, "x"),
        self:GetWindowSetting(config, "y") + CollapseOffset(config)
    )
    frame.positioning = nil
end

function app:SaveWindowPosition(frame, onlyChanged)
    local config = frame.config
    local x, y = AnchorCoordinates(frame, app:GetWindowSetting(config, "point"))
    local targetX, targetY =
        AnchorCoordinates(frame.anchorTarget or UIParent, app:GetWindowSetting(config, "relativePoint"))
    x, y = (x - targetX) / frame:GetEffectiveScale(), (y - targetY) / frame:GetEffectiveScale() - CollapseOffset(config)
    if not onlyChanged or math.abs(x - app:GetWindowSetting(config, "x")) > 0.001 then
        config.overrides.x = x
    end
    if not onlyChanged or math.abs(y - app:GetWindowSetting(config, "y")) > 0.001 then
        config.overrides.y = y
    end
end

local function SaveGeometry(frame, resizing)
    frame:StopMovingOrSizing()
    if not frame.editing then
        return
    end
    frame.editing = nil
    local config = frame.config
    app:SaveWindowPosition(frame)
    if resizing and not app:IsWindowCollapsed(config) then
        config.overrides.width, config.overrides.height = frame:GetSize()
    end
    frame:SetUserPlaced(false)
    app:RebuildWindows()
end

function app:HideWindows()
    for _, frame in ipairs(self.windows) do
        frame:Hide()
    end
end

function app:AddWindow()
    local profile = self.db.profile
    self:PrepareWindowSettings()
    local id = self:GetUnusedWindowSlot()
    if not id then
        self.core.logger:chat("All " .. self.MAX_WINDOWS .. " meter windows are already active.")
        return
    end
    self:SetWindowEnabled(profile.windows[id], true)
end

function app:SetWindowEnabled(config, enabled)
    config.enabled = enabled
    if enabled then
        config.hidden = false
    end
    self:RebuildWindows()
end

function app:ShowStatisticMenu(frame)
    MenuUtil.CreateContextMenu(frame.statistic, function(_, root)
        local categories = {
            {
                DAMAGE_METER_CATEGORY_DAMAGE or "Damage",
                { "DamageDone", "Dps", "DamageTaken", "AvoidableDamageTaken" },
            },
            { DAMAGE_METER_CATEGORY_HEALING or "Healing", { "HealingDone", "Hps", "Absorbs" } },
            { DAMAGE_METER_CATEGORY_ACTIONS or "Actions", { "Interrupts", "Dispels" } },
        }
        for _, category in ipairs(categories) do
            local menu = root:CreateButton(category[1])
            for _, key in ipairs(category[2]) do
                local statistic = self:GetStatistic(key)
                if self:IsAvailable() and Enum.DamageMeterType[key] ~= nil then
                    menu:CreateRadio(statistic.label, function()
                        return frame.config.statistic == key
                    end, function()
                        frame.config.statistic = key
                        frame.offset = 0
                        self:RefreshWindows()
                    end)
                end
            end
        end
    end)
end

function app:ShowSessionMenu(frame)
    MenuUtil.CreateContextMenu(frame.session, function(_, root)
        root:CreateTitle("Combat session")
        for _, key in ipairs({ "Current", "Overall" }) do
            local label = key == "Current" and (DAMAGE_METER_CURRENT_SESSION or key)
                or (DAMAGE_METER_OVERALL_SESSION or key)
            root:CreateRadio(label, function()
                return not frame.config.sessionID and frame.config.session == key
            end, function()
                frame.config.session, frame.config.sessionID, frame.config.sessionName = key, nil, nil
                frame.offset = 0
                self:RefreshWindows()
            end)
        end
        if self:IsAvailable() and not (self.IsEditingWindows and self:IsEditingWindows()) then
            root:CreateDivider()
            for _, session in ipairs(C_DamageMeter.GetAvailableCombatSessions()) do
                root:CreateRadio(session.name, function()
                    return frame.config.sessionID == session.sessionID
                end, function()
                    frame.config.sessionID, frame.config.sessionName = session.sessionID, session.name
                    frame.offset = 0
                    self:RefreshWindows()
                end)
            end
        end
    end)
end

local function CreateRow(frame, index)
    local entry = CreateFrame("Frame", nil, frame.body)
    entry:SetHeight(app:GetWindowSetting(frame.config, "rowHeight"))
    entry:SetPoint("TOPLEFT", 0, 0)
    entry:SetPoint("RIGHT", 0, 0)
    entry:SetClipsChildren(true)
    local row = CreateFrame("StatusBar", nil, entry)
    row.entry = entry
    row:SetHeight(app:GetWindowSetting(frame.config, "rowHeight") - 2)
    row:SetPoint("TOPLEFT", 24, -1)
    row:SetPoint("RIGHT", -4, 0)
    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetAtlas("UI-HUD-CoolDownManager-Bar")
    row:SetStatusBarTexture(fill)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", -2, 2)
    background:SetPoint("BOTTOMRIGHT", 2, -2)
    background:SetAtlas("ui-damagemeters-bar-shadowbg")
    local edge = row:CreateTexture(nil, "OVERLAY")
    edge:SetPoint("TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", 2, -2)
    edge:SetAtlas("ui-damagemeters-bar-shadowedge")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("RIGHT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.0625, 0.9, 0.0626, 0.9)
    row.name = Label(row, "NumberFontNormal")
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value = Label(row, "NumberFontNormal")
    row.value:SetPoint("RIGHT", -3, 0)
    row.value:SetJustifyH("RIGHT")
    row.name:SetPoint("RIGHT", row.value, "LEFT", -25, 0)
    if index > 0 then
        frame.rows[index] = row
    end
    return row
end

local function UpdateRow(row, source, sourceIndex, session, statistic, config)
    local rowHeight = app:GetWindowSetting(config, "rowHeight")
    row.entry:SetHeight(rowHeight)
    row:SetHeight(rowHeight - 2)
    app:StyleWindowLabel(row.name, config)
    app:StyleWindowLabel(row.value, config)
    row.name:SetFormattedText(DAMAGE_METER_SOURCE_NAME or "%d. %s", sourceIndex, source.name)
    if source.specIconID and source.specIconID ~= 0 then
        row.icon:SetTexture(source.specIconID)
    elseif source.classFilename and source.classFilename ~= "" then
        row.icon:SetAtlas(GetClassAtlas(source.classFilename))
    else
        row.icon:SetTexture(nil)
    end
    local amount = source.totalAmount
    local secondary = source.amountPerSecond
    if statistic.rate then
        amount = source.amountPerSecond
        secondary = source.totalAmount
    end
    local showRate = statistic.key ~= "Interrupts" and statistic.key ~= "Dispels"
    if showRate and issecretvalue and (issecretvalue(amount) or issecretvalue(secondary)) then
        row.value:SetFormattedText(statistic.rate and "%.1f (%.0f)" or "%.0f (%.1f)", amount, secondary)
    elseif showRate then
        row.value:SetFormattedText(
            DAMAGE_METER_ENTRY_FORMAT_COMPACT or "%s (%s)",
            AbbreviateLargeNumbers(amount),
            AbbreviateLargeNumbers(secondary)
        )
    elseif issecretvalue and issecretvalue(amount) then
        row.value:SetFormattedText("%.0f", amount)
    else
        row.value:SetText(AbbreviateLargeNumbers(amount))
    end
    row:SetMinMaxValues(0, session.maxAmount)
    row:SetValue(source.totalAmount)
    local color = RAID_CLASS_COLORS[source.classFilename]
    if color and app:GetWindowSetting(config, "classColors") then
        row:SetStatusBarColor(color.r, color.g, color.b, 1)
    else
        row:SetStatusBarColor(unpack(app:GetWindowSetting(config, "barColor")))
    end
    row:Show()
end

function app:RefreshWindow(frame, session, message)
    local config = frame.config
    local preview = session and session.isPreview
    local collapsed = self:IsWindowCollapsed(config)
    local statistic = self:GetStatistic(config.statistic)
    frame.statistic.text:SetText(statistic.label)
    frame.session.text:SetText(
        preview and "Preview"
            or config.sessionID
            or (
                config.session == "Overall" and DAMAGE_METER_OVERALL_SESSION_SHORT
                or DAMAGE_METER_CURRENT_SESSION_SHORT
            )
    )
    frame.session:SetWidth(preview and 60 or frame.session.normalWidth)
    local duration = session and session.durationSeconds
    if not preview and self:IsAvailable() and not config.sessionID and UnitAffectingCombat("player") then
        duration = C_DamageMeter.GetSessionDurationSeconds(Enum.DamageMeterSessionType[config.session])
    end
    if
        not (issecretvalue and issecretvalue(duration))
        and duration
        and duration > 0
        and (preview or config.sessionID or UnitAffectingCombat("player"))
    then
        frame.timer:SetFormattedText("[%s] ", SecondsToClock(duration))
    else
        frame.timer:SetText("")
    end
    frame.statistic:ClearAllPoints()
    frame.statistic:SetPoint("TOPLEFT", frame.timer, "TOPRIGHT", 0, 6)
    frame.statistic:SetPoint("RIGHT", frame.session, "LEFT", -5, 0)
    local sources = session and session.combatSources or {}
    local localIndex
    for index, source in ipairs(sources) do
        if source.isLocalPlayer then
            localIndex = index
            break
        end
    end
    local rowHeight = self:GetWindowSetting(config, "rowHeight")
    local rowSpacing = self:GetWindowSetting(config, "rowSpacing")
    local capacity = math.max(
        1,
        math.floor(
            (self:GetWindowSetting(config, "height") - HEADER_HEIGHT - 8 + rowSpacing) / (rowHeight + rowSpacing)
        )
    )
    local scrollable = #sources > capacity
    frame.body:SetPoint("BOTTOMRIGHT", scrollable and -16 or -1, 6)
    frame.scrollbar:SetShown(scrollable and not collapsed)
    frame.offset = math.max(0, math.min(frame.offset, #sources - capacity))
    frame.updatingScroll = true
    frame.scrollbar:SetMinMaxValues(0, math.max(0, #sources - capacity))
    frame.scrollbar:SetValue(frame.offset)
    if scrollable then
        frame.thumb:SetHeight(math.max(23, frame.scrollbar:GetHeight() * capacity / #sources))
    end
    frame.updatingScroll = false
    for _, row in ipairs(frame.rows) do
        row:Hide()
    end
    -- Preserve the client's ordering. Never compare, sort or calculate with secret combat values.
    for index = 1, math.min(capacity + 1, #sources - frame.offset) do
        local sourceIndex = index + frame.offset
        local source = sources[sourceIndex]
        local row = frame.rows[index] or CreateRow(frame, index)
        row.entry:ClearAllPoints()
        row.entry:SetPoint("TOPLEFT", 0, -(index - 1) * (rowHeight + rowSpacing))
        row.entry:SetPoint("RIGHT", 0, 0)
        UpdateRow(row, source, sourceIndex, session, statistic, config)
    end
    if frame.localRow then
        frame.localRow:Hide()
    end
    if not collapsed and localIndex and (localIndex <= frame.offset or localIndex > frame.offset + capacity) then
        local row = frame.localRow or CreateRow(frame, 0)
        frame.localRow = row
        local entry = row.entry
        entry:SetParent(frame)
        entry:SetFrameLevel(frame.body:GetFrameLevel() + 10)
        entry:ClearAllPoints()
        entry:SetPoint(
            localIndex <= frame.offset and "TOPLEFT" or "BOTTOMLEFT",
            frame.body,
            localIndex <= frame.offset and "TOPLEFT" or "BOTTOMLEFT",
            0,
            localIndex <= frame.offset and 3 or -3
        )
        entry:SetPoint("RIGHT", frame.body, "RIGHT", 0, 0)
        UpdateRow(row, sources[localIndex], localIndex, session, statistic, config)
    end
    frame.message:SetText(
        message or (config.statistic == "AvoidableDamageTaken" and DAMAGE_METER_AVOIDABLE_DAMAGE_NOT_ACTIVE) or ""
    )
    frame.message:SetShown(#sources == 0)
end

function app:RefreshWindows()
    -- Share API reads between windows showing the same session and statistic.
    local cache = {}
    for _, frame in ipairs(self.windows) do
        if frame:IsShown() then
            local config = frame.config
            local key = config.statistic .. ":" .. (config.sessionID or config.session)
            if not cache[key] then
                cache[key] = { self:GetSession(config) }
            end
            self:RefreshWindow(frame, cache[key][1], cache[key][2])
        end
    end
end

function app:CreateWindow(id)
    local frame = CreateFrame("Frame", "SeamlessDamageMeterWindow" .. id, UIParent)
    frame.windowID = id
    frame:Hide()
    frame.rows, frame.offset = {}, 0
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(200, 120, 800, 900)
    frame:EnableMouse(true)
    frame.background = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.background:SetAtlas("damagemeters-background")
    frame.background:SetAllPoints(frame)
    frame.background:SetAlpha(1)
    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetAtlas("ui-damagemeters-header-bar")
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)
    frame.header = header
    frame.timer = Label(frame, "GameFontNormalMed1")
    frame.timer:SetPoint("TOPLEFT", 1, -9)
    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", 5, -HEADER_HEIGHT - 2)
    frame.body:SetPoint("BOTTOMRIGHT", -1, 6)
    frame.body:SetClipsChildren(true)

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT", -52, 0)
    title:SetHeight(HEADER_HEIGHT)
    -- Dragging also works over either selector in the compact header.
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function()
        if not app.db.profile.locked then
            frame.editing = true
            frame:StartMoving()
        end
    end)
    title:SetScript("OnDragStop", function()
        SaveGeometry(frame)
    end)
    local close = Button(frame, "", 18, function()
        if self.IsEditingWindows and self:IsEditingWindows() then
            return
        end
        frame.config.collapsed = not frame.config.collapsed
        self:ApplyWindowLayout(frame)
        self:RefreshWindows()
    end)
    close:SetSize(18, 19)
    close:SetPoint("TOPRIGHT", -3, -5)
    AtlasButton(
        close,
        "ui-questtrackerbutton-collapse-all",
        "ui-questtrackerbutton-collapse-all-pressed",
        "ui-questtrackerbutton-red-highlight"
    )
    local menu = Button(frame, "", 27, function(button)
        MenuUtil.CreateContextMenu(button, function(_, root)
            root:CreateButton("Activate next window", function()
                self:AddWindow()
            end)
            root:CreateButton("Damage Meter settings", function()
                self.core:OpenOptions("SeamlessDamageMeter", "windows")
            end)
            root:CreateButton("Deactivate this window", function()
                self:SetWindowEnabled(frame.config, false)
            end)
            root:CreateButton("Hide this window", function()
                frame.config.hidden = true
                frame:Hide()
                self:UpdateWindowOptions()
            end)
        end)
    end)
    menu:SetSize(27, 27)
    menu:SetPoint("RIGHT", close, "LEFT", -2, -2)
    AtlasButton(
        menu,
        "common-dropdown-a-button-settings-shadowless",
        "common-dropdown-a-button-settings-pressed-shadowless",
        "common-dropdown-a-button-settings-hover-shadowless"
    )
    frame.statistic = Selector(frame, function()
        self:ShowStatisticMenu(frame)
    end)
    frame.statistic:SetHeight(25)
    frame.session = Selector(frame, function()
        self:ShowSessionMenu(frame)
    end, true)
    frame.session:SetSize(
        math.max(#(DAMAGE_METER_OVERALL_SESSION_SHORT or "O"), #(DAMAGE_METER_CURRENT_SESSION_SHORT or "C")) > 1 and 32
            or 18,
        18
    )
    frame.session:SetPoint("RIGHT", menu, "LEFT", -2, 3)
    frame.session.normalWidth = frame.session:GetWidth()
    frame.statistic:SetPoint("RIGHT", frame.session, "LEFT", -5, 0)
    for _, selector in ipairs({ frame.statistic, frame.session }) do
        selector:RegisterForDrag("LeftButton")
        selector:SetScript("OnDragStart", title:GetScript("OnDragStart"))
        selector:SetScript("OnDragStop", title:GetScript("OnDragStop"))
    end

    frame.message = Label(frame.body, "GameFontNormalMed1")
    frame.message:SetPoint("TOPLEFT", 15, 2)
    frame.message:SetPoint("BOTTOMRIGHT", -20, 0)
    frame.message:SetJustifyH("CENTER")
    local resize = Button(frame, "", 60, function() end)
    resize:SetSize(60, 60)
    resize:SetPoint("BOTTOMRIGHT", 9, -8)
    resize:SetAlpha(0)
    AtlasButton(
        resize,
        "damagemeters-scalehandle",
        "damagemeters-scalehandle-pressed",
        "damagemeters-scalehandle-hover"
    )
    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not self.db.profile.locked then
            frame.editing = true
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function()
        SaveGeometry(frame, true)
        self:RefreshWindows()
    end)
    frame.resize, frame.collapse = resize, close
    local scrollbar = CreateFrame("Slider", nil, frame)
    scrollbar:SetWidth(8)
    scrollbar:SetPoint("TOPLEFT", frame.body, "TOPRIGHT", 0, -19)
    scrollbar:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMRIGHT", 0, 27)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetValueStep(1)
    scrollbar:SetObeyStepOnDrag(true)
    local thumb = scrollbar:CreateTexture(nil, "ARTWORK")
    frame.thumb = thumb
    thumb:SetAtlas("minimal-scrollbar-small-thumb-middle")
    thumb:SetSize(8, 23)
    scrollbar:SetThumbTexture(thumb)
    for _, cap in ipairs({
        { "TOP", "minimal-scrollbar-small-thumb-top" },
        { "BOTTOM", "minimal-scrollbar-small-thumb-bottom" },
    }) do
        local texture = scrollbar:CreateTexture(nil, "OVERLAY")
        texture:SetAtlas(cap[2], true)
        texture:SetPoint(cap[1], thumb, cap[1])
    end
    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetAtlas("!minimal-scrollbar-track-middle")
    track:SetAllPoints()
    for _, direction in ipairs({ { "TOP", "top", -1 }, { "BOTTOM", "bottom", 1 } }) do
        local step = Button(scrollbar, "", 17, function()
            frame.offset = math.max(0, frame.offset + direction[3])
            self:RefreshWindows()
        end)
        step:SetSize(17, 11)
        step:SetPoint(direction[1], scrollbar, direction[1], 0, direction[3] * -19)
        AtlasButton(
            step,
            "minimal-scrollbar-arrow-" .. direction[2],
            "minimal-scrollbar-arrow-" .. direction[2] .. "-down",
            "minimal-scrollbar-arrow-" .. direction[2] .. "-over"
        )
    end
    scrollbar:SetAlpha(0.3)
    scrollbar:SetScript("OnValueChanged", function(_, value)
        local offset = math.floor(value + 0.5)
        if not frame.updatingScroll and frame.offset ~= offset then
            frame.offset = offset
            self:RefreshWindows()
        end
    end)
    frame.scrollbar = scrollbar
    frame:SetScript("OnUpdate", function(_, elapsed)
        local hover = frame:IsMouseOver() and not self:IsWindowCollapsed(frame.config)
        local resizeTarget = hover and not self.db.profile.locked and 1 or 0
        local scrollTarget = hover and 1 or 0.3
        local step = math.min(1, elapsed / 0.25)
        resize:SetAlpha(resize:GetAlpha() + (resizeTarget - resize:GetAlpha()) * step)
        scrollbar:SetAlpha(scrollbar:GetAlpha() + (scrollTarget - scrollbar:GetAlpha()) * step)
    end)
    frame:SetScript("OnSizeChanged", function()
        if frame.config and not self:IsWindowCollapsed(frame.config) and not frame.applyingLayout then
            if frame.editing then
                frame.config.overrides.width, frame.config.overrides.height = frame:GetSize()
            end
            self:RefreshWindows()
        end
    end)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        frame.editing = nil
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = math.max(0, frame.offset - delta * 3)
        self:RefreshWindows()
    end)
    frame.body:EnableMouseWheel(true)
    frame.body:SetScript("OnMouseWheel", frame:GetScript("OnMouseWheel"))
    scrollbar:EnableMouseWheel(true)
    scrollbar:SetScript("OnMouseWheel", frame:GetScript("OnMouseWheel"))
    return frame
end

function app:ApplyWindowLayout(frame)
    local config = frame.config
    local collapsed = self:IsWindowCollapsed(config)
    frame.applyingLayout = true
    frame:SetResizeBounds(200, collapsed and HEADER_HEIGHT or 120, 800, 900)
    frame:SetHeight(collapsed and HEADER_HEIGHT or self:GetWindowSetting(config, "height"))
    self:PositionWindow(frame)
    frame.applyingLayout = false
    frame.body:SetShown(not collapsed)
    frame.background:SetShown(not collapsed)
    frame.resize:SetShown(not collapsed)
    AtlasButton(
        frame.collapse,
        collapsed and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all",
        collapsed and "ui-questtrackerbutton-expand-all-pressed" or "ui-questtrackerbutton-collapse-all-pressed",
        "ui-questtrackerbutton-red-highlight"
    )
    if self.SyncWindowEditMode then
        self:SyncWindowEditMode(frame)
    end
end

function app:RebuildWindows()
    self:PrepareWindowSettings()
    self:HideWindows()
    for index = #self.windows, 1, -1 do
        self.windows[index] = nil
    end
    for index, config in ipairs(self.db.profile.windows) do
        local frame = self.windowFrames[config.id]
        if not frame then
            frame = self:CreateWindow(config.id)
            self.windowFrames[config.id] = frame
        end
        self.windows[index] = frame
        frame.config = nil
        frame.anchorTarget = nil
        frame.offset = 0
        frame:SetResizeBounds(200, 120, 800, 900)
        frame:ClearAllPoints()
        frame:SetScale(self:GetWindowSetting(config, "scale"))
        frame:SetSize(self:GetWindowSetting(config, "width"), self:GetWindowSetting(config, "height"))
        frame.background:SetVertexColor(unpack(self:GetWindowSetting(config, "backgroundColor")))
        frame.header:SetVertexColor(unpack(self:GetWindowSetting(config, "headerColor")))
        self:StyleWindowLabel(frame.statistic.text, config)
        self:StyleWindowLabel(frame.session.text, config)
        self:StyleWindowLabel(frame.message, config)
        self:StyleWindowLabel(frame.timer, config)
        frame.config = config
        self:ApplyWindowLayout(frame)
        frame:SetShown(config.enabled and not config.hidden)
    end
    -- All frames must exist before another window can use one as its anchor.
    for index, config in ipairs(self.db.profile.windows) do
        local frame = self.windows[index]
        local target = UIParent
        if config.anchorTo and self:CanAnchorTo(config, config.anchorTo) then
            for targetIndex, candidate in ipairs(self.db.profile.windows) do
                if candidate.id == config.anchorTo then
                    target = self.windows[targetIndex]
                    break
                end
            end
        else
            config.anchorTo = nil
        end
        frame.anchorTarget = target
        self:PositionWindow(frame)
        if self.SyncWindowEditMode then
            self:SyncWindowEditMode(frame)
            frame:SetShown(self:WindowShouldBeShown(frame))
        end
    end
    self:RefreshWindows()
    self:UpdateWindowOptions()
end

function app:StyleWindowLabel(label, config)
    local media = LibStub("LibSharedMedia-3.0")
    label:SetFont(
        media:Fetch("font", self:GetWindowSetting(config, "font")),
        self:GetWindowSetting(config, "fontSize"),
        self:GetWindowSetting(config, "fontFlags")
    )
    label:SetTextColor(unpack(self:GetWindowSetting(config, "textColor")))
end
