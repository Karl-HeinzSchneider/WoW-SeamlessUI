---@type string, SeamlessDamageMeter
local _, app = ...

-- Each window is laid out like the client's own meter window (Blizzard_DamageMeter, which WoW
-- Forever loads) and uses its templates: the type, session and settings dropdowns, the source
-- entry bars and the minimal scroll bar. Bar settings follow the client's Edit Mode values.
app.windows = {}
local HEADER_HEIGHT = 32
local SCROLLBAR_OFFSET = 15
local SESSION_NAMES = {
    Current = DAMAGE_METER_CURRENT_SESSION or "Current Combat",
    Overall = DAMAGE_METER_OVERALL_SESSION or "Overall",
}
local SESSION_SHORT = {
    Current = DAMAGE_METER_CURRENT_SESSION_SHORT or "C",
    Overall = DAMAGE_METER_OVERALL_SESSION_SHORT or "O",
}

-- The client's meter frame holds the Edit Mode settings; defaults match its default layout.
local function MeterSetting(method, default)
    local meter = DamageMeter
    if type(meter) == "table" and type(meter[method]) == "function" then
        local value = meter[method](meter)
        if value ~= nil then
            return value
        end
    end
    return default
end

local function BarHeight()
    return MeterSetting("GetBarHeight", DAMAGE_METER_DEFAULT_BAR_HEIGHT or 25)
end

local function BarSpacing()
    return MeterSetting("GetBarSpacing", DAMAGE_METER_DEFAULT_BAR_SPACING or 4)
end

local function SetupEntry(entry)
    entry:SetUseClassColor(MeterSetting("ShouldUseClassColor", true))
    entry:SetBarHeight(BarHeight())
    entry:SetTextScale(MeterSetting("GetTextScale", 1))
    entry:SetShowBarIcons(MeterSetting("ShouldShowBarIcons", true))
    entry:SetStyle(MeterSetting("GetStyle", Enum.DamageMeterStyle.Default))
    entry:SetNumberDisplayType(MeterSetting("GetNumberDisplayType", Enum.DamageMeterNumbers.Compact))
    entry:SetBackgroundAlpha(MeterSetting("GetBackgroundAlpha", 0.5))
    -- No source breakdown window here; let drags and the wheel reach the window.
    entry:EnableMouse(false)
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
        height = 140,
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

local function Select(self, frame, changes)
    for key, value in pairs(changes) do
        frame.config[key] = value
    end
    frame.discardScroll = true
    self:RefreshWindows()
end

-- One submenu per category (Damage, Healing, Actions), like the client's meter.
function app:SetupStatisticMenu(frame)
    frame.statistic:SetupMenu(function(_, root)
        root:SetTag("MENU_SEAMLESS_DAMAGE_METER_TYPE")
        for _, category in ipairs(self.categories) do
            local submenu
            for _, statistic in ipairs(self.statistics) do
                if statistic.category == category.key and self:IsStatisticAvailable(statistic) then
                    submenu = submenu or root:CreateButton(category.label)
                    submenu:CreateRadio(statistic.label, function()
                        return frame.config.statistic == statistic.key
                    end, function()
                        Select(self, frame, { statistic = statistic.key })
                    end)
                end
            end
        end
    end)
end

-- Past fights first, then Current and Overall below a divider, like the client's meter.
function app:SetupSessionMenu(frame)
    frame.session:SetupMenu(function(_, root)
        root:SetTag("MENU_SEAMLESS_DAMAGE_METER_SESSIONS")
        if self:IsAvailable() then
            for _, session in ipairs(C_DamageMeter.GetAvailableCombatSessions()) do
                local name = session.name
                if not name or name == "" then
                    name = (DAMAGE_METER_COMBAT_NUMBER or "Combat %d"):format(session.sessionID)
                end
                local label = name
                if session.durationSeconds then
                    label = ("%s [%s]"):format(name, SecondsToClock(session.durationSeconds))
                end
                root:CreateRadio(label, function()
                    return frame.config.sessionID == session.sessionID
                end, function()
                    Select(self, frame, { session = "Current", sessionID = session.sessionID, sessionName = name })
                end)
            end
        end
        root:CreateDivider()
        for _, key in ipairs({ "Current", "Overall" }) do
            root:CreateRadio(SESSION_NAMES[key], function()
                return not frame.config.sessionID and frame.config.session == key
            end, function()
                Select(self, frame, { session = key, sessionID = false, sessionName = false })
            end)
        end
    end)
end

function app:SetupSettingsMenu(frame)
    frame.settings:SetupMenu(function(_, root)
        root:SetTag("MENU_SEAMLESS_DAMAGE_METER_SETTINGS")
        root:CreateButton(DAMAGE_METER_OPEN_SETTINGS or "Damage Meter settings", function()
            self.core:OpenOptions("SeamlessDamageMeter")
        end)
        root:CreateButton("Add window", function()
            self:AddWindow()
        end)
        root:CreateButton("Remove this window", function()
            self:RemoveWindow(frame.config)
        end)
    end)
end

-- "[m:ss] " before the type name while the current fight runs, as the client's meter does.
function app:UpdateSessionTimer(frame)
    local config, seconds = frame.config, nil
    if self:IsAvailable() and C_DamageMeter.GetSessionDurationSeconds then
        if not config.sessionID and config.session == "Current" and UnitAffectingCombat("player") then
            seconds = C_DamageMeter.GetSessionDurationSeconds(Enum.DamageMeterSessionType.Current)
        end
    end
    if seconds and seconds ~= 0 then
        frame.timer:SetText(("[%s] "):format(SecondsToClock(seconds)))
    else
        frame.timer:SetText("")
    end
end

-- Copies each source, as the client's window does, without touching the API's tables.
-- Values may be secret; they are only copied, never compared or calculated with.
local function BuildDataProvider(session, statistic)
    local provider = CreateDataProvider()
    if not session then
        return provider
    end
    local meterType = Enum.DamageMeterType and Enum.DamageMeterType[statistic.key]
    for index, source in ipairs(session.combatSources or {}) do
        local entry = {}
        for key, value in pairs(source) do
            entry[key] = value
        end
        entry.maxAmount = session.maxAmount
        entry.sessionTotalAmount = session.totalAmount
        entry.index = index
        entry.showsValuePerSecondAsPrimary = statistic.rate == true
        entry.suppressIcon = statistic.noIcon == true
        entry.suppressValuePerSecond = statistic.count == true
        entry.damageMeterType = meterType
        provider:Insert(entry)
    end
    return provider
end

function app:RefreshWindow(frame, session, message)
    local config = frame.config
    local statistic = self:GetStatistic(config.statistic)
    frame.typeName:SetText(statistic.label)
    frame.sessionName:SetText(config.sessionID and tostring(config.sessionID) or SESSION_SHORT[config.session] or "?")
    self:UpdateSessionTimer(frame)
    local provider = BuildDataProvider(session, statistic)
    local retain = frame.discardScroll and ScrollBoxConstants.DiscardScrollPosition
        or ScrollBoxConstants.RetainScrollPosition
    frame.discardScroll = nil
    frame.scrollBox:SetDataProvider(provider, retain)
    frame.notActive:SetText(message or "")
    frame.notActive:SetShown(provider:IsEmpty() and message ~= nil)
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

local function CreateHeader(self, frame)
    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetAtlas("ui-damagemeters-header-bar")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    frame.header = header

    frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    frame.timer:SetJustifyH("LEFT")
    frame.timer:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -9)

    local minimize = CreateFrame("Button", nil, frame)
    minimize:SetSize(18, 19)
    minimize:SetPoint("TOPRIGHT", header, "TOPRIGHT", -3, -5)
    minimize:SetNormalAtlas("ui-questtrackerbutton-collapse-all", true)
    minimize:SetPushedAtlas("ui-questtrackerbutton-collapse-all-pressed", true)
    minimize:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
    minimize:SetScript("OnClick", function()
        frame.config.minimized = not frame.config.minimized
        self:UpdateMinimized(frame)
    end)
    frame.minimize = minimize

    frame.settings = CreateFrame("DropdownButton", nil, frame, "DamageMeterSettingsDropdownButtonTemplate")
    frame.settings:SetPoint("RIGHT", minimize, "LEFT", -2, -2)

    local session = CreateFrame("DropdownButton", nil, frame, "WowStyle2DropdownTemplate")
    session:SetSize(18, 18)
    session:SetPoint("RIGHT", frame.settings, "LEFT", -2, 3)
    frame.sessionName = session:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    frame.sessionName:SetJustifyH("CENTER")
    frame.sessionName:SetAllPoints()
    frame.session = session

    local statistic = CreateFrame("DropdownButton", nil, frame, "WowStyle1ArrowDropdownTemplate")
    statistic.hasShadow = false
    statistic:OnButtonStateChanged()
    statistic:SetPoint("TOPLEFT", frame.timer, "TOPRIGHT", 0, 6)
    frame.typeName = statistic:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    frame.typeName:SetJustifyH("LEFT")
    frame.typeName:SetPoint("LEFT", statistic.Arrow, "RIGHT", 0, 3)
    frame.typeName:SetPoint("RIGHT", session, "LEFT", -5, 0)
    frame.statistic = statistic

    -- Session names in some languages need two characters, as in the client's window.
    if #SESSION_SHORT.Current > 1 or #SESSION_SHORT.Overall > 1 then
        session:SetWidth(32)
    end
    self:SetupStatisticMenu(frame)
    self:SetupSessionMenu(frame)
    self:SetupSettingsMenu(frame)
end

local function CreateContainer(self, frame)
    -- Everything below the header; minimizing hides it and keeps the header bar.
    local container = CreateFrame("Frame", nil, frame)
    container:SetAllPoints()
    frame.container = container

    local background = container:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("damagemeters-background")
    background:SetAllPoints()
    frame.background = background

    frame.notActive = container:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1")
    frame.notActive:SetJustifyH("CENTER")
    frame.notActive:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 20, 0)
    frame.notActive:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -20, 0)

    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 0, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 0, 8)
    scrollBar:SetAlpha(0.3)
    frame.scrollBox, frame.scrollBar = scrollBox, scrollBar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(BarHeight())
    view:SetElementInitializer("DamageMeterSourceEntryTemplate", function(entry, data)
        if not entry.seamlessSetup then
            entry.seamlessSetup = true
            SetupEntry(entry)
        end
        entry:Init(data)
    end)
    view:SetPadding(0, 0, 0, 0, BarSpacing())
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    local withBar = {
        CreateAnchor("TOPLEFT", frame.header, "BOTTOMLEFT", 5, -2),
        CreateAnchor("BOTTOMRIGHT", -1 - SCROLLBAR_OFFSET, 6),
    }
    local withoutBar = {
        CreateAnchor("TOPLEFT", frame.header, "BOTTOMLEFT", 5, -2),
        CreateAnchor("BOTTOMRIGHT", -1, 6),
    }
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar, withBar, withoutBar)

    local resize = CreateFrame("Button", nil, container)
    resize:SetSize(60, 60)
    resize:SetPoint("BOTTOMRIGHT", 9, -8)
    resize:SetNormalAtlas("damagemeters-scalehandle")
    resize:SetHighlightAtlas("damagemeters-scalehandle-hover")
    resize:SetPushedAtlas("damagemeters-scalehandle-pressed")
    resize:SetAlpha(0)
    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not self.db.profile.locked then
            frame.sizing = true
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function()
        frame.sizing = false
        SaveGeometry(frame)
    end)
    frame.resize = resize
end

-- On hover the resize handle fades in and the scroll bar brightens, as in the client's window.
local function SetupHover(self, frame)
    local hovered = false
    local function Fade(region, to)
        UIFrameFadeIn(region, 0.25, region:GetAlpha(), to)
    end
    local function Watch()
        local over = frame:IsMouseOver() or frame.resize:IsMouseOver() or frame.sizing
        if over and not hovered then
            hovered = true
            Fade(frame.scrollBar, 1)
            if not self.db.profile.locked then
                Fade(frame.resize, 1)
            end
        elseif not over then
            hovered = false
            Fade(frame.scrollBar, 0.3)
            Fade(frame.resize, 0)
            frame:SetScript("OnUpdate", nil)
        end
    end
    frame:SetScript("OnEnter", function()
        frame:SetScript("OnUpdate", Watch)
    end)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        frame:SetScript("OnUpdate", nil)
        hovered = false
        frame.resize:SetAlpha(0)
        frame.scrollBar:SetAlpha(0.3)
    end)
end

function app:CreateWindow()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(200, 120, 600, 400)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not self.db.profile.locked then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        SaveGeometry(frame)
    end)
    CreateHeader(self, frame)
    CreateContainer(self, frame)
    SetupHover(self, frame)
    return frame
end

function app:UpdateMinimized(frame)
    local atlas = frame.config.minimized and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all"
    frame.minimize:SetNormalAtlas(atlas, true)
    frame.minimize:SetPushedAtlas(atlas .. "-pressed", true)
    frame.container:SetShown(not frame.config.minimized)
end

-- Picks up Edit Mode changes to the client's meter (bar height, spacing, text, style).
function app:ApplyMeterSettings(frame)
    frame.background:SetAlpha(MeterSetting("GetBackgroundAlpha", 0.5))
    frame:SetAlpha(MeterSetting("GetWindowAlpha", 1))
    local view = frame.scrollBox:GetView()
    view:SetElementExtent(BarHeight())
    view:SetPadding(0, 0, 0, 0, BarSpacing())
    frame.scrollBox:ForEachFrame(SetupEntry)
end

function app:RebuildWindows()
    self:HideWindows()
    if not self.db.profile.initialized then
        self:AddWindow()
        return
    end
    for index, config in ipairs(self.db.profile.windows) do
        -- Choosing Current or Overall stores false; normalize it so the saved profile stays clean.
        config.sessionID = config.sessionID or nil
        config.sessionName = config.sessionName or nil
        local frame = self.windows[index]
        if not frame then
            frame = self:CreateWindow()
            self.windows[index] = frame
        end
        frame.config, frame.discardScroll = config, true
        frame:ClearAllPoints()
        frame:SetSize(config.width, config.height)
        frame:SetPoint("CENTER", UIParent, "CENTER", config.x, config.y)
        self:UpdateMinimized(frame)
        self:ApplyMeterSettings(frame)
        frame:SetShown(not config.hidden)
    end
    self:RefreshWindows()
end
