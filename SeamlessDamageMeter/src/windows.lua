---@type string, SeamlessDamageMeter
local _, app = ...

app.windows = {}
local ROW_HEIGHT = 22

local function Label(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
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
        width = 340,
        height = 260,
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
    row:SetPoint("TOPLEFT", 7, -55 - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -7, 0)
    row:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.12, 0.12, 0.14, 0.8)
    row.rank = Label(row)
    row.rank:SetPoint("LEFT", 4, 0)
    row.rank:SetWidth(22)
    row.name = Label(row)
    row.name:SetPoint("LEFT", 28, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value = Label(row)
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
    frame.statistic:SetText(statistic.label .. " v")
    frame.session:SetText((config.sessionName or config.session) .. " v")
    local sources = session and session.combatSources or {}
    local capacity = math.max(1, math.floor((frame:GetHeight() - 82) / ROW_HEIGHT))
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
        if statistic.rate then
            row.value:SetFormattedText("%.0f/s", source.amountPerSecond)
        else
            row.value:SetFormattedText("%.0f", source.totalAmount)
        end
        row:SetMinMaxValues(0, session.maxAmount)
        row:SetValue(source.totalAmount)
        local color = RAID_CLASS_COLORS[source.classFilename]
        if color then
            row:SetStatusBarColor(color.r, color.g, color.b, 0.8)
        else
            row:SetStatusBarColor(0.35, 0.6, 0.8, 0.8)
        end
        row:Show()
    end
    frame.message:SetText(message or "No combat data yet.")
    frame.message:SetShown(#sources == 0)
    if session then
        frame.footer:SetFormattedText("Total: %.0f", session.totalAmount)
    else
        frame.footer:SetText("Blizzard combat statistics")
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
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame.rows, frame.offset = {}, 0
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(280, 160, 800, 900)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.035, 0.04, 0.055, 0.92)
    frame:SetBackdropBorderColor(0.25, 0.28, 0.34, 1)

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT", 5, -3)
    title:SetPoint("TOPRIGHT", -76, -3)
    title:SetHeight(24)
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
    frame.title = Label(title, "GameFontNormalSmall")
    frame.title:SetPoint("LEFT", 4, 0)

    local close = Button(frame, "x", 22, function()
        frame.config.hidden = true
        frame:Hide()
    end)
    close:SetPoint("TOPRIGHT", -3, -3)
    local add = Button(frame, "+", 22, function()
        self:AddWindow()
    end)
    add:SetPoint("RIGHT", close, "LEFT", -2, 0)
    local menu = Button(frame, "...", 22, function(button)
        MenuUtil.CreateContextMenu(button, function(_, root)
            root:CreateButton("Damage Meter settings", function()
                self.core:OpenOptions("SeamlessDamageMeter")
            end)
            root:CreateButton("Remove this window", function()
                self:RemoveWindow(frame.config)
            end)
        end)
    end)
    menu:SetPoint("RIGHT", add, "LEFT", -2, 0)
    frame.statistic = Button(frame, "", 170, function()
        self:ShowStatisticMenu(frame)
    end)
    frame.statistic:SetPoint("TOPLEFT", 5, -29)
    frame.session = Button(frame, "", 145, function()
        self:ShowSessionMenu(frame)
    end)
    frame.session:SetPoint("TOPLEFT", frame.statistic, "TOPRIGHT", 2, 0)
    frame.session:SetPoint("RIGHT", -5, 0)

    frame.message = Label(frame)
    frame.message:SetPoint("TOPLEFT", 16, -72)
    frame.message:SetPoint("BOTTOMRIGHT", -16, 35)
    frame.message:SetJustifyH("CENTER")
    frame.footer = Label(frame)
    frame.footer:SetPoint("BOTTOMLEFT", 9, 8)
    local resize = Button(frame, "/", 20, function() end)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
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
        frame.title:SetText("Seamless Meter " .. config.id)
        frame:SetShown(not config.hidden)
    end
    self:RefreshWindows()
end
