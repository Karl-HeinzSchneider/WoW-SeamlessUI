---@type string, SeamlessDamageMeter
local _, app = ...

app.windows = {}
local ROW_HEIGHT = 25
local ROW_SPACING = 4
local HEADER_HEIGHT = 32
local ICON_SIZE = 24
-- The list starts just below the header bar, like the client's own meter.
local LIST_LEFT, LIST_TOP, LIST_BOTTOM = 5, HEADER_HEIGHT + 2, 6
local SOURCE_NAME_FORMAT = DAMAGE_METER_SOURCE_NAME or "%d. %s"
local VALUE_FORMAT_COMPACT = DAMAGE_METER_ENTRY_FORMAT_COMPACT or "%s (%s)"
local VALUE_FORMAT_MINIMAL = DAMAGE_METER_ENTRY_FORMAT_MINIMAL or "%s"
-- Default edit mode layout of the client's meter: background at 50% transparency.
local BACKGROUND_ALPHA = 0.5
local SESSION_NAMES = {
    Current = DAMAGE_METER_CURRENT_SESSION or "Current Combat",
    Overall = DAMAGE_METER_OVERALL_SESSION or "Overall",
}
local SESSION_SHORT = {
    Current = DAMAGE_METER_CURRENT_SESSION_SHORT or "C",
    Overall = DAMAGE_METER_OVERALL_SESSION_SHORT or "O",
}

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

-- Arrow button followed by the statistic name, as in the client's meter header.
local function StatisticSelector(parent, callback)
    local button = Button(parent, "", 100, callback)
    button:SetHeight(25)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("common-dropdown-a-button-shadowless", true)
    arrow:SetPoint("CENTER", button, "LEFT", 12, -2)
    button.text = Label(button, "GameFontNormalMed1")
    button.text:SetPoint("LEFT", 25, 1)
    button.text:SetPoint("RIGHT", -2, 1)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local function UpdateArrow()
        local suffix = ""
        if button:IsMouseOver() then
            suffix = button.pressed and "-pressedhover" or "-hover"
        elseif button.pressed then
            suffix = "-pressed"
        end
        arrow:SetAtlas("common-dropdown-a-button" .. suffix .. "-shadowless", true)
    end
    button:SetScript("OnEnter", UpdateArrow)
    button:SetScript("OnLeave", UpdateArrow)
    -- Open on mouse down, as the client's dropdowns do; a drag over the header never clicks.
    button:SetScript("OnClick", nil)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        button.pressed = true
        UpdateArrow()
        if mouseButton == "LeftButton" then
            callback(button)
        end
    end)
    button:SetScript("OnMouseUp", function()
        button.pressed = false
        UpdateArrow()
    end)
    return button
end

-- Small framed button holding the session's short name (C, O or a fight number).
local function SessionSelector(parent, callback)
    local button = Button(parent, "", 18, callback)
    button:SetHeight(18)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", -7, 7)
    background:SetPoint("BOTTOMRIGHT", 7, -7)
    background:SetAtlas("common-dropdown-c-button")
    button.text = Label(button, "GameFontNormalMed1")
    button.text:SetAllPoints()
    button.text:SetJustifyH("CENTER")
    local function UpdateBackground()
        local over = button:IsMouseOver()
        if over and button.pressed then
            background:SetAtlas("common-dropdown-c-button-pressedhover-1")
        elseif over then
            background:SetAtlas("common-dropdown-c-button-hover-1")
        elseif button.pressed then
            background:SetAtlas("common-dropdown-c-button-pressed-1")
        else
            background:SetAtlas("common-dropdown-c-button")
        end
    end
    button:SetScript("OnEnter", UpdateBackground)
    button:SetScript("OnLeave", UpdateBackground)
    -- Open on mouse down, as the client's dropdowns do; a drag over the header never clicks.
    button:SetScript("OnClick", nil)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        button.pressed = true
        UpdateBackground()
        if mouseButton == "LeftButton" then
            callback(button)
        end
    end)
    button:SetScript("OnMouseUp", function()
        button.pressed = false
        UpdateBackground()
    end)
    return button
end

local function SaveGeometry(frame)
    frame:StopMovingOrSizing()
    local x, y = frame:GetCenter()
    local centerX, centerY = UIParent:GetCenter()
    frame.config.x, frame.config.y = x - centerX, y - centerY
    frame.config.width, frame.config.height = frame:GetSize()
    frame:SetUserPlaced(false)
end

function app:HideWindows()
    for _, frame in ipairs(self.windows) do
        frame:Hide()
    end
end

function app:AddWindow()
    local profile = self.db.profile
    local offset = (#profile.windows % 6) * 28
    local config = {
        id = profile.nextID,
        statistic = "DamageDone",
        session = "Current",
        width = 400,
        height = 200,
        x = offset,
        y = -offset,
    }
    profile.nextID = profile.nextID + 1
    profile.initialized = true
    table.insert(profile.windows, config)
    self:RebuildWindows()
end

function app:RemoveWindow(config)
    for index, candidate in ipairs(self.db.profile.windows) do
        if candidate == config then
            table.remove(self.db.profile.windows, index)
            break
        end
    end
    self:RebuildWindows()
end

local function SelectStatistic(self, frame, key)
    frame.config.statistic = key
    frame.offset = 0
    self:RefreshWindows()
end

local function SelectSession(self, frame, session, sessionID, sessionName)
    frame.config.session, frame.config.sessionID, frame.config.sessionName = session, sessionID, sessionName
    frame.offset = 0
    self:RefreshWindows()
end

-- One submenu per category (Damage, Healing, Actions), like the client's meter.
function app:ShowStatisticMenu(frame)
    MenuUtil.CreateContextMenu(frame.statistic, function(_, root)
        for _, category in ipairs(self.categories) do
            local submenu
            for _, statistic in ipairs(self.statistics) do
                if statistic.category == category.key and self:IsStatisticAvailable(statistic) then
                    submenu = submenu or root:CreateButton(category.label)
                    submenu:CreateRadio(statistic.label, function()
                        return frame.config.statistic == statistic.key
                    end, function()
                        SelectStatistic(self, frame, statistic.key)
                    end)
                end
            end
        end
    end)
end

local function FormatDuration(seconds)
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

-- Past fights first, then Current and Overall below a divider, like the client's meter.
function app:ShowSessionMenu(frame)
    MenuUtil.CreateContextMenu(frame.session, function(_, root)
        if self:IsAvailable() then
            for _, session in ipairs(C_DamageMeter.GetAvailableCombatSessions()) do
                local name = session.name
                if not name or name == "" then
                    name = string.format(DAMAGE_METER_COMBAT_NUMBER or "Combat %d", session.sessionID)
                end
                local label = name
                if session.durationSeconds then
                    label = string.format("%s [%s]", name, FormatDuration(session.durationSeconds))
                end
                root:CreateRadio(label, function()
                    return frame.config.sessionID == session.sessionID
                end, function()
                    SelectSession(self, frame, "Current", session.sessionID, name)
                end)
            end
            root:CreateDivider()
        end
        for _, key in ipairs({ "Current", "Overall" }) do
            root:CreateRadio(SESSION_NAMES[key], function()
                return not frame.config.sessionID and frame.config.session == key
            end, function()
                SelectSession(self, frame, key)
            end)
        end
    end)
end

local function CreateRow(frame, index)
    local row = CreateFrame("Frame", nil, frame.container)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", LIST_LEFT, -LIST_TOP - (index - 1) * (ROW_HEIGHT + ROW_SPACING))
    row:SetPoint("RIGHT", -1, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.0625, 0.9, 0.0626, 0.9)
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetPoint("LEFT", row.icon, "RIGHT")
    bar:SetPoint("TOP", 0, -1)
    bar:SetPoint("BOTTOMRIGHT", -4, 1)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetAtlas("UI-HUD-CoolDownManager-Bar")
    bar:SetStatusBarTexture(fill)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", -2, 2)
    background:SetPoint("BOTTOMRIGHT", 2, -2)
    background:SetAtlas("ui-damagemeters-bar-shadowbg")
    local edge = bar:CreateTexture(nil, "OVERLAY")
    edge:SetPoint("TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", 2, -2)
    edge:SetAtlas("ui-damagemeters-bar-shadowedge")
    row.bar = bar
    row.name = Label(bar, "NumberFontNormal")
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value = Label(bar, "NumberFontNormal")
    row.value:SetPoint("RIGHT", -3, 0)
    row.value:SetJustifyH("LEFT")
    row.name:SetPoint("RIGHT", row.value, "LEFT", -25, 0)
    frame.rows[index] = row
    return row
end

function app:RefreshWindow(frame, session, message)
    local config = frame.config
    local statistic = self:GetStatistic(config.statistic)
    frame.statistic.text:SetText(statistic.label)
    local shortName = config.sessionID and tostring(config.sessionID) or SESSION_SHORT[config.session] or "?"
    frame.session.text:SetText(shortName)
    frame.session:SetWidth(#shortName > 1 and 32 or 18)
    self:UpdateSessionTimer(frame)
    local sources = session and session.combatSources or {}
    local listHeight = frame:GetHeight() - LIST_TOP - LIST_BOTTOM + ROW_SPACING
    local capacity = math.max(1, math.floor(listHeight / (ROW_HEIGHT + ROW_SPACING)))
    frame.offset = math.max(0, math.min(frame.offset, #sources - capacity))
    for _, row in ipairs(frame.rows) do
        row:Hide()
    end
    -- Preserve the client's ordering. Never compare, sort or calculate with secret combat values.
    for index = 1, math.min(capacity, #sources - frame.offset) do
        local sourceIndex = index + frame.offset
        local source = sources[sourceIndex]
        local row = frame.rows[index] or CreateRow(frame, index)
        -- Formatting through the setter keeps secret names secret, as the client's meter does.
        row.name:SetFormattedText(SOURCE_NAME_FORMAT, sourceIndex, source.name)
        if statistic.noIcon then
            row.icon:SetTexture(nil)
        elseif source.specIconID and source.specIconID ~= 0 then
            row.icon:SetTexture(source.specIconID)
        elseif source.classFilename ~= "" then
            row.icon:SetAtlas(GetClassAtlas(source.classFilename))
        else
            row.icon:SetTexture(nil)
        end
        -- The client's default "Compact" numbers: main value with the other one in parentheses.
        local main, other = source.totalAmount, source.amountPerSecond
        if statistic.rate then
            main, other = other, main
        end
        if statistic.count then
            row.value:SetFormattedText(VALUE_FORMAT_MINIMAL, AbbreviateLargeNumbers(main))
        else
            row.value:SetFormattedText(
                VALUE_FORMAT_COMPACT,
                AbbreviateLargeNumbers(main),
                AbbreviateLargeNumbers(other)
            )
        end
        row.bar:SetMinMaxValues(0, session.maxAmount)
        row.bar:SetValue(source.totalAmount)
        local color = RAID_CLASS_COLORS[source.classFilename] or DAMAGE_METER_STATUS_BAR_DEFAULT_COLOR
        if color then
            row.bar:SetStatusBarColor(color.r, color.g, color.b, 1)
        else
            row.bar:SetStatusBarColor(0.35, 0.6, 0.8, 1)
        end
        row:Show()
    end
    frame.message:SetText(message or "No combat data yet.")
    frame.message:SetShown(#sources == 0)
end

-- "[m:ss] " before the statistic while the current fight runs, or for a saved fight.
function app:UpdateSessionTimer(frame)
    local config, seconds = frame.config, nil
    if self:IsAvailable() and C_DamageMeter.GetSessionDurationSeconds then
        if not config.sessionID and config.session == "Current" and UnitAffectingCombat("player") then
            seconds = C_DamageMeter.GetSessionDurationSeconds(Enum.DamageMeterSessionType.Current)
        end
    end
    if seconds and seconds > 0 then
        frame.timer:SetFormattedText("[%d:%02d] ", math.floor(seconds / 60), math.floor(seconds % 60))
    else
        frame.timer:SetText("")
    end
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

function app:CreateWindow()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame.rows, frame.offset = {}, 0
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(320, 120, 800, 900)
    frame:EnableMouse(true)
    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetAtlas("ui-damagemeters-header-bar")
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)
    -- Everything below the header; minimizing hides it and keeps the header bar.
    frame.container = CreateFrame("Frame", nil, frame)
    frame.container:SetAllPoints()
    local background = frame.container:CreateTexture(nil, "BACKGROUND", nil, -1)
    background:SetAtlas("damagemeters-background")
    background:SetAllPoints()
    background:SetAlpha(BACKGROUND_ALPHA)

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT", -52, 0)
    title:SetHeight(HEADER_HEIGHT)
    -- Dragging also works over either selector in the compact header.
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function()
        if not app.db.profile.locked then
            frame:StartMoving()
        end
    end)
    title:SetScript("OnDragStop", function()
        SaveGeometry(frame)
    end)
    local close = Button(frame, "", 18, function()
        frame.config.minimized = not frame.config.minimized
        self:UpdateMinimized(frame)
    end)
    close:SetSize(18, 19)
    close:SetPoint("TOPRIGHT", -3, -5)
    frame.minimize = close
    local menu = Button(frame, "", 27, function(button)
        MenuUtil.CreateContextMenu(button, function(_, root)
            root:CreateButton("Add window", function()
                self:AddWindow()
            end)
            root:CreateButton("Damage Meter settings", function()
                self.core:OpenOptions("SeamlessDamageMeter")
            end)
            root:CreateButton("Remove this window", function()
                self:RemoveWindow(frame.config)
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
    frame.timer = Label(frame, "GameFontNormalMed1")
    frame.timer:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -9)
    frame.timer:SetJustifyH("LEFT")
    frame.session = SessionSelector(frame, function()
        self:ShowSessionMenu(frame)
    end)
    frame.session:SetPoint("RIGHT", menu, "LEFT", -2, 3)
    frame.statistic = StatisticSelector(frame, function()
        self:ShowStatisticMenu(frame)
    end)
    frame.statistic:SetPoint("TOPLEFT", frame.timer, "TOPRIGHT", 0, 6)
    frame.statistic:SetPoint("RIGHT", frame.session, "LEFT", -5, 0)
    for _, selector in ipairs({ frame.statistic, frame.session }) do
        -- Keep both above the drag area that covers the header.
        selector:SetFrameLevel(title:GetFrameLevel() + 2)
        selector:RegisterForDrag("LeftButton")
        selector:SetScript("OnDragStart", title:GetScript("OnDragStart"))
        selector:SetScript("OnDragStop", title:GetScript("OnDragStop"))
    end

    frame.message = Label(frame.container, "GameFontNormalMed1")
    frame.message:SetPoint("TOPLEFT", 20, -HEADER_HEIGHT)
    frame.message:SetPoint("BOTTOMRIGHT", -20, 0)
    frame.message:SetJustifyH("CENTER")
    local resize = Button(frame.container, "", 60, function() end)
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
            frame.sizing = true
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function()
        frame.sizing = false
        SaveGeometry(frame)
        self:RefreshWindows()
    end)
    -- The resize handle fades in only while the window is hovered.
    local function WatchHover()
        if frame:IsMouseOver() or resize:IsMouseOver() or frame.sizing then
            return
        end
        frame:SetScript("OnUpdate", nil)
        UIFrameFadeOut(resize, 0.25, resize:GetAlpha(), 0)
    end
    frame:SetScript("OnEnter", function()
        if not self.db.profile.locked and not frame:GetScript("OnUpdate") then
            UIFrameFadeIn(resize, 0.25, resize:GetAlpha(), 1)
        end
        frame:SetScript("OnUpdate", WatchHover)
    end)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        frame:SetScript("OnUpdate", nil)
        resize:SetAlpha(0)
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = math.max(0, frame.offset - delta * 3)
        self:RefreshWindows()
    end)
    return frame
end

function app:UpdateMinimized(frame)
    local minimized = frame.config.minimized
    local atlas = minimized and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all"
    AtlasButton(frame.minimize, atlas, atlas .. "-pressed", "ui-questtrackerbutton-red-highlight")
    frame.container:SetShown(not minimized)
end

function app:RebuildWindows()
    self:HideWindows()
    if not self.db.profile.initialized then
        self:AddWindow()
        return
    end
    for index, config in ipairs(self.db.profile.windows) do
        local frame = self.windows[index]
        if not frame then
            frame = self:CreateWindow()
            self.windows[index] = frame
        end
        frame.config, frame.offset = config, 0
        frame:ClearAllPoints()
        frame:SetSize(config.width, config.height)
        frame:SetPoint("CENTER", UIParent, "CENTER", config.x, config.y)
        self:UpdateMinimized(frame)
        frame:SetShown(not config.hidden)
    end
    self:RefreshWindows()
end
