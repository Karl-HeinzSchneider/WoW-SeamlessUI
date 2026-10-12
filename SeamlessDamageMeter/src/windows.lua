---@type string, SeamlessDamageMeter
local _, app = ...

app.windows = {}
local ROW_HEIGHT = 25
local ROW_SPACING = 4
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

local function Selector(parent, callback)
    local button = Button(parent, "", 100, callback)
    button.text = Label(button, "GameFontNormalMed1")
    button.text:SetPoint("LEFT", 18, 0)
    button.text:SetPoint("RIGHT", -2, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetAtlas("common-dropdown-classic-a-buttonDown")
    arrow:SetSize(20, 20)
    arrow:SetPoint("LEFT", -2, 0)
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

function app:ShowStatisticMenu(frame)
    MenuUtil.CreateContextMenu(frame.statistic, function(_, root)
        root:CreateTitle("Statistic")
        for _, statistic in ipairs(self.statistics) do
            if self:IsAvailable() and Enum.DamageMeterType[statistic.key] ~= nil then
                root:CreateRadio(statistic.label, function()
                    return frame.config.statistic == statistic.key
                end, function()
                    frame.config.statistic = statistic.key
                    frame.offset = 0
                    self:RefreshWindows()
                end)
            end
        end
    end)
end

function app:ShowSessionMenu(frame)
    MenuUtil.CreateContextMenu(frame.session, function(_, root)
        root:CreateTitle("Combat session")
        for _, key in ipairs({ "Current", "Overall" }) do
            root:CreateRadio(key, function()
                return not frame.config.sessionID and frame.config.session == key
            end, function()
                frame.config.session, frame.config.sessionID, frame.config.sessionName = key, nil, nil
                frame.offset = 0
                self:RefreshWindows()
            end)
        end
        if self:IsAvailable() then
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
    local row = CreateFrame("StatusBar", nil, frame)
    row:SetHeight(ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", 25, -HEADER_HEIGHT - 1 - (index - 1) * (ROW_HEIGHT + ROW_SPACING))
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
    row.rank = Label(row, "NumberFontNormal")
    row.rank:SetPoint("LEFT", 2, 0)
    row.rank:SetWidth(22)
    row.name = Label(row, "NumberFontNormal")
    row.name:SetPoint("LEFT", 28, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value = Label(row, "NumberFontNormal")
    row.value:SetPoint("RIGHT", -4, 0)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWidth(110)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -5, 0)
    frame.rows[index] = row
    return row
end

function app:RefreshWindow(frame, session, message)
    local config = frame.config
    local statistic = self:GetStatistic(config.statistic)
    frame.statistic.text:SetText(statistic.label)
    frame.session.text:SetText(config.sessionName or config.session)
    local sources = session and session.combatSources or {}
    local capacity = math.max(1, math.floor((frame:GetHeight() - HEADER_HEIGHT) / (ROW_HEIGHT + ROW_SPACING)))
    frame.offset = math.max(0, math.min(frame.offset, #sources - capacity))
    for _, row in ipairs(frame.rows) do
        row:Hide()
    end
    -- Preserve the client's ordering. Never compare, sort or calculate with secret combat values.
    for index = 1, math.min(capacity, #sources - frame.offset) do
        local sourceIndex = index + frame.offset
        local source = sources[sourceIndex]
        local row = frame.rows[index] or CreateRow(frame, index)
        row.rank:SetText(sourceIndex)
        row.name:SetText(source.name)
        if source.specIconID and source.specIconID ~= 0 then
            row.icon:SetTexture(source.specIconID)
        elseif source.classFilename ~= "" then
            row.icon:SetAtlas(GetClassAtlas(source.classFilename))
        else
            row.icon:SetTexture(nil)
        end
        if statistic.rate then
            row.value:SetFormattedText("%.0f/s", source.amountPerSecond)
        else
            row.value:SetFormattedText("%.0f", source.totalAmount)
        end
        row:SetMinMaxValues(0, session.maxAmount)
        row:SetValue(source.totalAmount)
        local color = RAID_CLASS_COLORS[source.classFilename]
        if color then
            row:SetStatusBarColor(color.r, color.g, color.b, 1)
        else
            row:SetStatusBarColor(0.35, 0.6, 0.8, 1)
        end
        row:Show()
    end
    frame.message:SetText(message or "No combat data yet.")
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
        frame.config.hidden = true
        frame:Hide()
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
    frame.statistic = Selector(frame, function()
        self:ShowStatisticMenu(frame)
    end)
    frame.statistic:SetPoint("TOPLEFT", 2, -4)
    frame.session = Selector(frame, function()
        self:ShowSessionMenu(frame)
    end)
    frame.session:SetWidth(105)
    frame.session:SetPoint("RIGHT", menu, "LEFT", -2, 2)
    frame.statistic:SetPoint("RIGHT", frame.session, "LEFT", -5, 0)
    for _, selector in ipairs({ frame.statistic, frame.session }) do
        selector:RegisterForDrag("LeftButton")
        selector:SetScript("OnDragStart", title:GetScript("OnDragStart"))
        selector:SetScript("OnDragStop", title:GetScript("OnDragStop"))
    end

    frame.message = Label(frame, "GameFontNormalMed1")
    frame.message:SetPoint("TOPLEFT", 20, -HEADER_HEIGHT)
    frame.message:SetPoint("BOTTOMRIGHT", -20, 0)
    frame.message:SetJustifyH("CENTER")
    local resize = Button(frame, "", 32, function() end)
    resize:SetSize(32, 32)
    resize:SetPoint("BOTTOMRIGHT", 4, -4)
    AtlasButton(
        resize,
        "damagemeters-scalehandle",
        "damagemeters-scalehandle-pressed",
        "damagemeters-scalehandle-hover"
    )
    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not self.db.profile.locked then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function()
        SaveGeometry(frame)
        self:RefreshWindows()
    end)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = math.max(0, frame.offset - delta * 3)
        self:RefreshWindows()
    end)
    return frame
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
        frame:SetShown(not config.hidden)
    end
    self:RefreshWindows()
end
