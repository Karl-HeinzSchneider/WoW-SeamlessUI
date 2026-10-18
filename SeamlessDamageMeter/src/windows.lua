---@type string, SeamlessDamageMeter
local _, app = ...

app.windows = {}
app.windowFrames = {}
local HEADER_HEIGHT = 32
local SESSION_MENU_MAX_HEIGHT = 240
local CreateRow

local function ScrollOffsetKey(frame)
    return frame.favorites and frame.favorites:IsShown() and "favoriteOffset" or "offset"
end

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
        button.arrow = arrow
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
        config.overrides.width = frame:GetWidth()
        if not app:GetWindowSetting(config, "fixedHeight") then
            config.overrides.height = frame:GetHeight()
        end
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

function app:ShowStatisticMenu(frame, favoriteSlot, owner)
    local config = frame.config
    MenuUtil.CreateContextMenu(owner or frame.statistic, function(_, root)
        local categories = {
            {
                DAMAGE_METER_CATEGORY_DAMAGE or "Damage",
                { "DamageDone", "Dps", "DamageTaken", "AvoidableDamageTaken", "EnemyDamageTaken" },
            },
            { DAMAGE_METER_CATEGORY_HEALING or "Healing", { "HealingDone", "Hps", "Absorbs" } },
            { DAMAGE_METER_CATEGORY_ACTIONS or "Actions", { "Interrupts", "Dispels", "Deaths" } },
        }
        for _, category in ipairs(categories) do
            local menu = root:CreateButton(category[1])
            for _, key in ipairs(category[2]) do
                local statistic = self:GetStatistic(key)
                if self:IsAvailable() and Enum.DamageMeterType[key] ~= nil then
                    menu:CreateRadio(statistic.label, function()
                        if favoriteSlot then
                            return self.db.profile.favorites[favoriteSlot] == key
                        end
                        return config.statistic == key
                    end, function()
                        if frame.config ~= config then
                            return
                        end
                        if favoriteSlot then
                            self.db.profile.favorites[favoriteSlot] = key
                            self:UpdateFavorites(frame)
                            return
                        end
                        config.statistic = key
                        frame.offset = 0
                        frame.favorites:Hide()
                        self:RefreshWindows()
                    end)
                end
            end
        end
        if favoriteSlot and self.db.profile.favorites[favoriteSlot] then
            root:CreateDivider()
            root:CreateButton("Clear favorite", function()
                if frame.config == config then
                    self.db.profile.favorites[favoriteSlot] = nil
                    self:UpdateFavorites(frame)
                end
            end)
        end
    end)
end

function app:UpdateFavorites(frame)
    local rowHeight = self:GetWindowSetting(frame.config, "rowHeight")
    local spacing = self:GetWindowSetting(frame.config, "rowSpacing")
    local count = self.db.profile.maxVisibleFavorites + 1
    for _, button in ipairs(frame.favorites.buttons) do
        button.row.entry:Hide()
    end
    for slot = 1, count do
        local isSelector = slot == count
        local button = frame.favorites.buttons[slot]
        if not button then
            local row = CreateRow(frame, -1)
            row.entry:SetParent(frame.favorites)
            row.entry:EnableMouse(false)
            row:EnableMouse(false)
            row.icon:Hide()
            row.value:Hide()
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", 3, 0)
            row.name:SetPoint("RIGHT", -3, 0)
            row:SetMinMaxValues(0, 1)
            row:SetValue(1)
            local number = Label(row.entry)
            number:SetPoint("LEFT", 4, 0)
            button = Button(row.entry, "", 1, function(owner, mouseButton)
                if slot == self.db.profile.maxVisibleFavorites + 1 then
                    self:ShowStatisticMenu(frame, nil, owner)
                    return
                end
                local key = self.db.profile.favorites[slot]
                if mouseButton == "RightButton" or not key then
                    self:ShowStatisticMenu(frame, slot, owner)
                elseif self:IsAvailable() and Enum.DamageMeterType[key] ~= nil then
                    frame.config.statistic = key
                    frame.offset = 0
                    frame.favorites:Hide()
                    self:RefreshWindows()
                end
            end)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:EnableMouse(true)
            button:SetFrameLevel(row:GetFrameLevel() + 1)
            button:SetAllPoints(row.entry)
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAtlas("UI-HUD-CoolDownManager-Bar")
            highlight:SetAllPoints(row)
            highlight:SetAlpha(0.2)
            highlight:SetBlendMode("ADD")
            button.row, button.number = row, number
            frame.favorites.buttons[slot] = button
        end
        button.number:SetText(isSelector and "" or slot)
        local key = not isSelector and self.db.profile.favorites[slot]
        local row = button.row
        row.entry:SetHeight(rowHeight)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", rowHeight, 0)
        row.entry:ClearAllPoints()
        row.entry:SetPoint("TOPLEFT", 0, -(slot - 1 - (frame.favoriteOffset or 0)) * (rowHeight + spacing))
        row.entry:SetPoint("RIGHT", 0, 0)
        row.entry:SetShown(slot > (frame.favoriteOffset or 0))
        self:StyleWindowLabel(row.name, frame.config)
        self:StyleWindowLabel(button.number, frame.config)
        row.name:SetText(isSelector and "Select type" or key and self:GetStatistic(key).label or "+ Set favorite")
        local color = self:GetWindowSetting(frame.config, "barColor")
        row:SetStatusBarColor(color[1], color[2], color[3], key and color[4] or 0.25)
    end
end

function app:ToggleFavorites(frame)
    if frame.favorites:IsShown() then
        frame.favorites:Hide()
        self:RefreshWindows()
        return
    end
    for _, other in ipairs(self.windows) do
        other.favorites:Hide()
    end
    frame.favoriteOffset = 0
    if frame.config.collapsed then
        frame.config.collapsed = false
        self:ApplyWindowLayout(frame)
    end
    frame.favorites:Show()
    self:RefreshWindows()
end

local function CreateFavorites(frame)
    local overlay = CreateFrame("Frame", nil, frame)
    frame.favorites = overlay
    overlay:SetFrameLevel(frame.body:GetFrameLevel() + 1)
    overlay:SetAllPoints(frame.body)
    overlay:SetClipsChildren(true)
    overlay:EnableMouse(true)
    overlay.buttons = {}
    overlay:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            app:ToggleFavorites(frame)
        end
    end)
    overlay:EnableMouseWheel(true)
    overlay:SetScript("OnMouseWheel", frame:GetScript("OnMouseWheel"))
    overlay:Hide()
end

local function AddSessionDuration(description, session)
    local duration = session.durationSeconds and SecondsToClock(session.durationSeconds) or ""
    description:AddInitializer(function(button)
        local time = button:AttachFontString()
        time:SetFontObject("GameFontHighlightSmall")
        time:SetWidth(55)
        time:SetHeight(20)
        time:SetPoint("RIGHT", -8, 0)
        time:SetJustifyH("RIGHT")
        time:SetText(duration)
        local name = button.fontString
        local width = 35 + name:GetUnboundedStringWidth() + 12 + 55
        name:SetPoint("RIGHT", time, "LEFT", -12, 0)
        return width, 20
    end)
end

function app:ShowSessionMenu(frame)
    local menu = MenuUtil.CreateContextMenu(frame.session, function(_, root)
        root:SetScrollMode(SESSION_MENU_MAX_HEIGHT)
        if not (self.IsEditingWindows and self:IsEditingWindows()) then
            local sessions = self.combatService:ListSessions()
            for _, session in ipairs(sessions) do
                local name = session.name ~= "" and session.name
                    or ("Combat " .. (session.archiveID or session.sessionID))
                local label = self.combatService:Describe(session, true)
                local description = root:CreateRadio(label, function()
                    return session.archiveID and frame.config.archiveID == session.archiveID
                        or (
                            not session.archiveID
                            and not frame.config.archiveID
                            and frame.config.sessionID == session.sessionID
                        )
                end, function()
                    frame.config.sessionID, frame.config.sessionName = session.sessionID, name
                    frame.config.archiveID, frame.config.sessionGeneration =
                        session.archiveID, session.sessionGeneration
                    frame.offset = 0
                    self:RefreshWindows()
                end)
                AddSessionDuration(description, session)
            end
            if #sessions > 0 then
                root:CreateDivider()
            end
        end
        for _, key in ipairs({ "Current", "Overall" }) do
            local label = key == "Current" and (DAMAGE_METER_CURRENT_SESSION or key)
                or (DAMAGE_METER_OVERALL_SESSION or key)
            root:CreateRadio(label, function()
                return not frame.config.archiveID and not frame.config.sessionID and frame.config.session == key
            end, function()
                frame.config.session, frame.config.sessionID, frame.config.sessionName = key, nil, nil
                frame.config.archiveID, frame.config.sessionGeneration = nil, nil
                frame.offset = 0
                self:RefreshWindows()
            end)
        end
        local fight = self.combatService:GetMetadata(frame.config)
        if fight then
            root:CreateDivider()
            root:CreateButton(fight.pinned and "Unpin selected fight" or "Pin selected fight", function()
                self.combatService:Pin(fight.id)
            end)
            root:CreateButton("Fight details / copy report", function()
                self:ShowAnalysis(frame.config)
            end)
            local compare = root:CreateButton("Compare with saved fight")
            compare:SetScrollMode(SESSION_MENU_MAX_HEIGHT)
            for _, session in ipairs(self.combatService:ListSessions()) do
                if session.archiveID and session.archiveID ~= fight.id then
                    local description = compare:CreateButton(self.combatService:Describe(session, true), function()
                        self:ShowComparison(fight.id, session.archiveID, frame.config.statistic)
                    end)
                    AddSessionDuration(description, session)
                end
            end
            local delete = root:CreateButton("Delete selected saved fight")
            delete:CreateButton("Confirm deletion", function()
                self.combatService:Delete(fight.id)
            end)
            local older = root:CreateButton("Delete segments older than selected")
            older:CreateButton("Confirm deletion (including pinned segments)", function()
                self.combatService:DeleteOlderSegments(fight.id)
            end)
        end
        if not (self.IsEditingWindows and self:IsEditingWindows()) then
            local clear = root:CreateButton("Clear saved segments")
            clear:CreateButton("Confirm deletion (including pinned segments)", function()
                self.combatService:ClearHistory()
            end)
        end
    end)
    if menu and menu.ScrollBox and menu.ScrollBox:IsShown() then
        menu.ScrollBox:ScrollToEnd(true)
    end
end

local function HideRowTooltip(row)
    local tooltip = app.detailTooltip
    if tooltip and tooltip.owner == row then
        tooltip.owner = nil
        tooltip:Hide()
    end
end

local function IsPublic(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Percentage(amount, total)
    if IsPublic(amount) and IsPublic(total) and type(amount) == "number" and type(total) == "number" and total > 0 then
        return math.floor(amount / total * 100 + 0.5)
    end
end

local function SetNumericText(label, value, rate)
    if not IsPublic(value) then
        label:SetFormattedText(rate and "%.1f" or "%.0f", value)
    else
        label:SetText(value ~= nil and AbbreviateLargeNumbers(value) or "")
    end
end

-- Fixed columns use public layout settings, never the width of restricted combat text.
local percentageMeasure
local function SetRowValues(row, config, amount, rate, percentage, enemyPercentage, showRate, rateFirst, showEnemy)
    local labels = { row.enemyPercentageValue, row.value, row.secondaryValue, row.percentageValue }
    local fontSize = app:GetWindowSetting(config, "fontSize")
    local gap = math.max(3, fontSize * 0.35)
    if not percentageMeasure then
        percentageMeasure = Label(UIParent)
        percentageMeasure:Hide()
        percentageMeasure:SetText("100%")
    end
    app:StyleWindowLabel(percentageMeasure, config)
    local percentageWidth = math.ceil(percentageMeasure:GetStringWidth()) + 4
    local widths = { percentageWidth, fontSize * 4.5, fontSize * 4, percentageWidth }
    local shown = { showEnemy, true, showRate, true }
    local total, count, reserved = 0, 0, 0
    for index = 1, 4 do
        -- Reserve the target share even when hidden so shared numeric columns stay aligned.
        if index == 1 or shown[index] then
            count = count + 1
            if index == 1 or index == 4 then
                reserved = reserved + widths[index]
            else
                total = total + widths[index]
            end
        end
    end
    local available = app:GetWindowSetting(config, "width")
        - (app:GetWindowSetting(config, "showIcons") and app:GetWindowSetting(config, "rowHeight") or 0)
        - 30
    local factor = math.min(1, math.max(1, available * 0.7 - reserved - gap * (count - 1)) / total)
    local offset = 3
    for index = 4, 1, -1 do
        local label = labels[index]
        app:StyleWindowLabel(label, config)
        label:SetJustifyH("RIGHT")
        label:ClearAllPoints()
        local width = widths[index] * ((index == 1 or index == 4) and 1 or factor)
        label:SetWidth(width)
        label:SetShown(shown[index] and true or false)
        if shown[index] then
            label:SetPoint("RIGHT", row, "RIGHT", -offset, 0)
            offset = offset + width + gap
        end
    end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetPoint("RIGHT", showEnemy and row.enemyPercentageValue or row.value, "LEFT", -gap, 0)
    local primary, secondary = amount, rate
    if rateFirst then
        primary, secondary = rate, amount
    end
    SetNumericText(row.value, primary, rateFirst)
    SetNumericText(row.secondaryValue, secondary, not rateFirst)
    if percentage ~= nil then
        row.percentageValue:SetFormattedText("%d%%", percentage)
    else
        row.percentageValue:SetText("")
    end
    if enemyPercentage ~= nil then
        row.enemyPercentageValue:SetFormattedText("%d%%", enemyPercentage)
    else
        row.enemyPercentageValue:SetText("")
    end
end

local function CreateDetailTooltip()
    local tooltip = CreateFrame("Frame", nil, UIParent)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    tooltip:EnableMouse(false)
    tooltip.rows = {}
    local background = tooltip:CreateTexture(nil, "BACKGROUND", nil, -1)
    background:SetAtlas("damagemeters-background")
    background:SetAllPoints()
    tooltip.background = background
    tooltip.body = CreateFrame("Frame", nil, tooltip)
    tooltip.body:SetPoint("TOPLEFT", 5, -5)
    tooltip.body:SetPoint("BOTTOMRIGHT", -5, 5)
    tooltip.body:SetClipsChildren(true)
    tooltip.body:EnableMouse(false)
    tooltip.targetLabel = Label(tooltip.body)
    tooltip.targetLabel:SetJustifyH("LEFT")
    tooltip.targetLabel:SetWordWrap(false)
    tooltip.targetMessage = Label(tooltip.body)
    tooltip.targetMessage:SetJustifyH("LEFT")
    tooltip.targetMessage:SetWordWrap(true)
    tooltip:Hide()
    return tooltip
end

local function ShowRowTooltip(row, frame)
    if not row.source or row.preview or app:IsWindowCollapsed(frame.config) then
        HideRowTooltip(row)
        return
    end
    local details, detailReason = app:GetSourceDetails(frame.config, row.source)
    details = details or { combatSpells = {}, totalAmount = row.source.totalAmount, maxAmount = row.source.totalAmount }
    local spells = details.deathEvents or details.combatSpells or {}
    local entries = {}
    for _, spell in ipairs(spells) do
        entries[#entries + 1] = spell
    end
    local inCombat = UnitAffectingCombat("player")
    local targetDetails, targetReason
    if not inCombat and (frame.config.statistic == "DamageDone" or frame.config.statistic == "Dps") then
        targetDetails, targetReason = app:GetTargetBreakdown(frame.config, row.source)
        if targetDetails and #targetDetails.entries > 0 then
            entries[#entries + 1] = { isTargetHeading = true }
            for _, target in ipairs(targetDetails.entries) do
                entries[#entries + 1] = target
            end
            if targetDetails.message then
                targetReason = targetDetails.message
                entries[#entries + 1] = { isTargetMessage = true }
            end
        end
    elseif not inCombat and frame.config.statistic == "EnemyDamageTaken" then
        targetDetails, targetReason = app.combatService:GetEnemyContributors(frame.config, row.source)
        if targetDetails and #targetDetails.entries > 0 then
            entries = { { isTargetHeading = true } }
            for _, contributor in ipairs(targetDetails.entries) do
                entries[#entries + 1] = contributor
            end
            if not targetDetails.complete then
                targetReason = "Available contributions only; totals do not fully reconcile."
                entries[#entries + 1] = { isTargetMessage = true }
            end
        end
    end
    if #entries == 0 then
        targetReason = detailReason or "No details available."
        entries[1] = { isTargetMessage = true }
    end
    local poolKey = inCombat and "combatSpellTooltip" or "postCombatTooltip"
    local tooltip = app[poolKey]
    if not tooltip then
        tooltip = CreateDetailTooltip()
        app[poolKey] = tooltip
    end
    if app.detailTooltip and app.detailTooltip ~= tooltip then
        app.detailTooltip.owner = nil
        app.detailTooltip:Hide()
    end
    app.detailTooltip = tooltip
    local config = frame.config
    local rowHeight = app:GetWindowSetting(config, "rowHeight")
    local spacing = app:GetWindowSetting(config, "rowSpacing")
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local capacity =
        math.max(1, math.floor((UIParent:GetHeight() * 0.75 / scale - 10 + spacing) / (rowHeight + spacing)))
    if tooltip.owner ~= row then
        tooltip.offset = 0
    end
    tooltip.owner, tooltip.config = row, config
    tooltip.capacity, tooltip.count = capacity, #entries
    tooltip.offset = math.max(0, math.min(tooltip.offset or 0, #entries - capacity))
    tooltip:SetScale(scale)
    tooltip:SetHeight(10 + math.min(capacity, #entries) * (rowHeight + spacing) - spacing)
    tooltip.background:SetVertexColor(unpack(app:GetWindowSetting(config, "backgroundColor")))
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT", row.entry, "TOPLEFT", 0, 0)
    tooltip:SetPoint("BOTTOMRIGHT", row.entry, "TOPRIGHT", 0, 0)
    local statistic = app:GetStatistic(frame.config.statistic)
    local showRate = not details.deathEvents and statistic.key ~= "Interrupts" and statistic.key ~= "Dispels"
    local showEnemy = targetDetails and #targetDetails.entries > 0 and statistic.key ~= "EnemyDamageTaken"
    tooltip.targetLabel:Hide()
    tooltip.targetMessage:Hide()
    app:StyleWindowLabel(tooltip.targetLabel, config)
    app:StyleWindowLabel(tooltip.targetMessage, config)
    for index = 1, math.min(capacity, #entries) do
        local spell = entries[index + tooltip.offset]
        local bar = tooltip.rows[index]
        if not bar then
            bar = CreateRow(tooltip, -1)
            bar.entry:EnableMouse(false)
            bar.entry:EnableMouseWheel(false)
            bar:EnableMouse(false)
            tooltip.rows[index] = bar
        end
        if spell.isTargetHeading or spell.isTargetMessage then
            local label = spell.isTargetHeading and tooltip.targetLabel or tooltip.targetMessage
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", 2, -(index - 1) * (rowHeight + spacing))
            label:SetPoint("RIGHT", -2, 0)
            label:SetHeight(rowHeight)
            local heading = frame.config.statistic == "EnemyDamageTaken" and "Contributors (% of enemy)"
                or "Targets (% of enemy; % of yours)"
            label:SetText(spell.isTargetHeading and heading or targetReason)
            label:Show()
            bar:Hide()
        else
            bar.entry:SetHeight(rowHeight)
            bar.entry:ClearAllPoints()
            bar.entry:SetPoint("TOPLEFT", 0, -(index - 1) * (rowHeight + spacing))
            bar.entry:SetPoint("RIGHT", 0, 0)
            bar:SetHeight(rowHeight)
            bar:SetPoint("TOPLEFT", app:GetWindowSetting(config, "showIcons") and rowHeight or 0, 0)
            bar.icon:SetShown(app:GetWindowSetting(config, "showIcons"))
            bar.icon:SetSize(rowHeight, rowHeight)
            app:StyleWindowLabel(bar.name, config)
            app:StyleWindowLabel(bar.value, config)
            local name = spell.spellName
            if IsPublic(name) and (name == nil or name == "") then
                local spellID = spell.spellID or spell.spellId
                name = (spellID and C_Spell.GetSpellName(spellID)) or UNKNOWN
                if details.deathEvents and spell.event == "SWING_DAMAGE" then
                    name = ACTION_SWING or "Melee"
                elseif details.deathEvents and spell.event == "ENVIRONMENTAL_DAMAGE" and spell.environmentalType then
                    name = _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. string.upper(spell.environmentalType)] or name
                end
            end
            local unit = spell.creatureName
            if IsPublic(unit) and (unit == nil or unit == "") then
                unit = spell.sourceName
                if spell.combatSpellDetails then
                    unit = spell.combatSpellDetails.unitName
                end
            end
            if not inCombat and (not IsPublic(unit) or (unit ~= nil and unit ~= "")) then
                bar.name:SetFormattedText("%s (%s)", name, unit)
            else
                bar.name:SetText(name)
            end
            local unitDetails = spell.combatSpellDetails or {}
            local spellID = spell.spellID or spell.spellId
            if details.deathEvents and spell.event == "SWING_DAMAGE" then
                spellID = 88163
            end
            if unitDetails.specIconID and unitDetails.specIconID ~= 0 then
                bar.icon:SetTexture(unitDetails.specIconID)
            elseif unitDetails.unitClassFilename and unitDetails.unitClassFilename ~= "" then
                bar.icon:SetAtlas(GetClassAtlas(unitDetails.unitClassFilename))
            else
                bar.icon:SetTexture(spellID and C_Spell.GetSpellTexture(spellID) or nil)
            end
            local amount = spell.totalAmount
            if IsPublic(amount) and amount == nil then
                amount = spell.amount
            end
            if IsPublic(amount) and amount == nil then
                amount = 0
            end
            local rate = spell.amountPerSecond
            local total = spell.isTarget and targetDetails.totalAmount or details.totalAmount
            local percentage = Percentage(amount, total)
            local enemyPercentage = spell.isTarget and spell.enemyShare and math.floor(spell.enemyShare + 0.5) or nil
            SetRowValues(
                bar,
                config,
                amount,
                rate,
                percentage,
                enemyPercentage,
                showRate,
                statistic.rate,
                showEnemy and spell.isTarget
            )
            -- The API provides the scale; restricted amounts go directly to the widgets.
            local maximum = spell.isTarget and targetDetails.maxAmount or details.maxAmount
            if IsPublic(maximum) and maximum == nil then
                maximum = 1
            end
            bar:SetMinMaxValues(0, maximum)
            bar:SetValue(amount)
            local classFilename = unitDetails.unitClassFilename
            if not classFilename or classFilename == "" then
                classFilename = row.source.classFilename
            end
            local color = RAID_CLASS_COLORS[classFilename]
            if color and app:GetWindowSetting(config, "classColors") then
                bar:SetStatusBarColor(color.r, color.g, color.b, 1)
            else
                bar:SetStatusBarColor(unpack(app:GetWindowSetting(config, "barColor")))
            end
            bar:Show()
        end
    end
    for index = math.min(capacity, #entries) + 1, #tooltip.rows do
        tooltip.rows[index]:Hide()
    end
    tooltip:Show()
end

CreateRow = function(frame, index)
    local entry = CreateFrame("Frame", nil, frame.body)
    entry:SetHeight(app:GetWindowSetting(frame.config, "rowHeight"))
    entry:SetPoint("TOPLEFT", 0, 0)
    entry:SetPoint("RIGHT", 0, 0)
    entry:SetClipsChildren(true)
    local row = CreateFrame("StatusBar", nil, entry)
    row.entry = entry
    row.window = frame
    entry:EnableMouse(true)
    entry:EnableMouseWheel(true)
    entry:SetScript("OnMouseWheel", function(owner, delta)
        local tooltip = app.detailTooltip
        if tooltip and tooltip.owner == row and tooltip.count > tooltip.capacity then
            tooltip.offset = tooltip.offset - delta * 3
            ShowRowTooltip(row, frame)
        else
            local scroll = frame:GetScript("OnMouseWheel")
            if scroll then
                scroll(owner, delta)
            end
        end
    end)
    entry:SetScript("OnEnter", function()
        ShowRowTooltip(row, frame)
    end)
    entry:SetScript("OnLeave", function()
        HideRowTooltip(row)
    end)
    entry:SetScript("OnHide", function()
        HideRowTooltip(row)
    end)
    entry:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            app:ToggleFavorites(frame)
        elseif button == "LeftButton" and row.source and not row.preview then
            app:ShowAnalysis(frame.config, row.source)
        end
    end)
    row:SetScript("OnHide", function()
        HideRowTooltip(row)
        row.source = nil
    end)
    row:SetHeight(app:GetWindowSetting(frame.config, "rowHeight"))
    row:SetPoint("TOPLEFT", app:GetWindowSetting(frame.config, "rowHeight"), 0)
    row:SetPoint("RIGHT", -4, 0)
    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\AddOns\\SeamlessDamageMeter\\Textures\\ShadedBar.tga")
    row:SetStatusBarTexture(fill)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(row)
    background:SetColorTexture(0, 0, 0, 0.35)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(app:GetWindowSetting(frame.config, "rowHeight"), app:GetWindowSetting(frame.config, "rowHeight"))
    row.icon:SetPoint("RIGHT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0, 1, 0, 1)
    row.name = Label(row, "NumberFontNormal")
    row.name:SetPoint("LEFT", 2, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value = Label(row, "NumberFontNormal")
    row.value:SetPoint("RIGHT", -3, 0)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)
    for _, key in ipairs({ "secondaryValue", "percentageValue", "enemyPercentageValue" }) do
        row[key] = Label(row, "NumberFontNormal")
        row[key]:SetJustifyH("RIGHT")
        row[key]:SetWordWrap(false)
        row[key]:Hide()
    end
    row.name:SetPoint("RIGHT", row.value, "LEFT", -25, 0)
    if index > 0 then
        frame.rows[index] = row
    end
    return row
end

local function UpdateRow(row, source, sourceIndex, session, statistic, config)
    row.source, row.preview = source, session.isPreview
    local rowHeight = app:GetWindowSetting(config, "rowHeight")
    row.entry:SetHeight(rowHeight)
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", app:GetWindowSetting(config, "showIcons") and rowHeight or 0, 0)
    row.icon:SetShown(app:GetWindowSetting(config, "showIcons"))
    row.icon:SetSize(rowHeight, rowHeight)
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
    local showRate = statistic.key ~= "Interrupts" and statistic.key ~= "Dispels" and statistic.key ~= "Deaths"
    SetRowValues(
        row,
        config,
        source.totalAmount,
        source.amountPerSecond,
        Percentage(source.totalAmount, session.totalAmount),
        nil,
        showRate,
        statistic.rate,
        false
    )
    row:SetMinMaxValues(0, session.maxAmount)
    row:SetValue(source.totalAmount)
    local color = RAID_CLASS_COLORS[source.classFilename]
    if color and app:GetWindowSetting(config, "classColors") then
        row:SetStatusBarColor(color.r, color.g, color.b, 1)
    else
        row:SetStatusBarColor(unpack(app:GetWindowSetting(config, "barColor")))
    end
    row:Show()
    if app.detailTooltip and app.detailTooltip.owner == row then
        ShowRowTooltip(row, row.window)
    end
end

function app:RefreshWindow(frame, session, message)
    local config = frame.config
    local preview = session and session.isPreview
    local collapsed = self:IsWindowCollapsed(config)
    local statistic = self:GetStatistic(config.statistic)
    frame.statistic.text:SetText(frame.favorites:IsShown() and "Favorites" or statistic.label)
    frame.session.text:SetText(
        preview and "Preview"
            or (config.archiveID and ("S" .. config.archiveID))
            or config.sessionID
            or (
                config.session == "Overall" and DAMAGE_METER_OVERALL_SESSION_SHORT
                or DAMAGE_METER_CURRENT_SESSION_SHORT
            )
    )
    frame.session:SetWidth(preview and 60 or frame.session.normalWidth)
    local duration = self.combatService:GetDuration(config, session)
    if
        not (issecretvalue and issecretvalue(duration))
        and duration
        and duration > 0
        and (preview or config.archiveID or config.sessionID or UnitAffectingCombat("player"))
    then
        frame.timer:SetFormattedText("[%s]", SecondsToClock(duration))
    else
        frame.timer:SetText("")
    end
    frame.statistic:ClearAllPoints()
    frame.statistic:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, 0)
    local hideTypeSelector = self:GetWindowSetting(config, "hideTypeSelector")
    frame.statistic.arrow:SetShown(not hideTypeSelector)
    frame.statistic:EnableMouse(not hideTypeSelector)
    frame.statistic.text:ClearAllPoints()
    frame.statistic.text:SetPoint("TOPLEFT", frame.statistic, "TOPLEFT", 25, -9)
    local availableWidth = math.max(0, frame:GetWidth() - 28 - frame.session:GetWidth() - 62)
    local labelWidth = math.min(frame.statistic.text:GetStringWidth(), availableWidth)
    frame.statistic.text:SetWidth(labelWidth)
    frame.timer:ClearAllPoints()
    frame.timer:SetPoint("LEFT", frame.statistic.text, "RIGHT", 5, 0)
    frame.timer:SetWidth(0)
    frame.timer:SetShown(not self:GetWindowSetting(config, "hideCombatTimer"))
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
    local favoritesShown = frame.favorites:IsShown()
    local count = favoritesShown and (self.db.profile.maxVisibleFavorites + 1) or #sources
    local offsetKey = ScrollOffsetKey(frame)
    local scrollable = count > capacity
    frame.body:SetPoint("BOTTOMRIGHT", scrollable and -16 or -1, 6)
    frame.scrollbar:SetShown(scrollable and not collapsed)
    frame[offsetKey] = math.max(0, math.min(frame[offsetKey] or 0, count - capacity))
    frame.updatingScroll = true
    frame.scrollbar:SetMinMaxValues(0, math.max(0, count - capacity))
    frame.scrollbar:SetValue(frame[offsetKey])
    if scrollable then
        frame.thumb:SetHeight(math.max(23, frame.scrollbar:GetHeight() * capacity / count))
    end
    frame.updatingScroll = false
    for index, row in ipairs(frame.rows) do
        if favoritesShown or collapsed or index > math.min(capacity + 1, #sources - frame.offset) then
            row:Hide()
        end
    end
    if favoritesShown then
        if frame.localRow then
            frame.localRow:Hide()
        end
        frame.message:Hide()
        self:UpdateFavorites(frame)
        return
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
    local pinned = not collapsed and localIndex and (localIndex <= frame.offset or localIndex > frame.offset + capacity)
    if frame.localRow and not pinned then
        frame.localRow:Hide()
    end
    if pinned then
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
    self.combatService:BeginRefresh()
    for _, frame in ipairs(self.windows) do
        if frame:IsShown() then
            local config = frame.config
            local session, message = self:GetSession(config)
            self:RefreshWindow(frame, session, message)
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
    frame.timer:SetWordWrap(false)
    frame.timer:SetJustifyH("LEFT")
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
    frame.statistic:SetSize(25, 25)
    frame.statistic.arrow:ClearAllPoints()
    frame.statistic.arrow:SetPoint("CENTER", frame.statistic, "CENTER", 0, -2)
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
    frame.statistic:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, 0)
    for _, selector in ipairs({ frame.statistic, frame.session }) do
        -- Keep selector clicks above the mouse-enabled header used for dragging.
        selector:SetFrameLevel(title:GetFrameLevel() + 1)
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
        if
            button == "LeftButton"
            and self:GetWindowSetting(frame.config, "showResizeHandle")
            and not self:GetWindowSetting(frame.config, "lockSize")
            and (not self.db.profile.locked or (self.IsEditingWindows and self:IsEditingWindows()))
        then
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
            local offsetKey = ScrollOffsetKey(frame)
            frame[offsetKey] = math.max(0, (frame[offsetKey] or 0) + direction[3])
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
        local offsetKey = ScrollOffsetKey(frame)
        if not frame.updatingScroll and frame[offsetKey] ~= offset then
            frame[offsetKey] = offset
            self:RefreshWindows()
        end
    end)
    frame.scrollbar = scrollbar
    frame:SetScript("OnUpdate", function(_, elapsed)
        local hover = frame:IsMouseOver() and not self:IsWindowCollapsed(frame.config)
        local editing = self.IsEditingWindows and self:IsEditingWindows()
        local resizeTarget = (editing or (hover and not self.db.profile.locked)) and 1 or 0
        local scrollTarget = hover and 1 or 0.3
        local step = math.min(1, elapsed / 0.25)
        resize:SetAlpha(resize:GetAlpha() + (resizeTarget - resize:GetAlpha()) * step)
        scrollbar:SetAlpha(scrollbar:GetAlpha() + (scrollTarget - scrollbar:GetAlpha()) * step)
    end)
    frame:SetScript("OnSizeChanged", function()
        if frame.config and not self:IsWindowCollapsed(frame.config) and not frame.applyingLayout then
            if frame.editing then
                frame.config.overrides.width = frame:GetWidth()
                if not self:GetWindowSetting(frame.config, "fixedHeight") then
                    frame.config.overrides.height = frame:GetHeight()
                end
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
        local offsetKey = ScrollOffsetKey(frame)
        frame[offsetKey] = math.max(0, (frame[offsetKey] or 0) - delta * 3)
        self:RefreshWindows()
    end)
    frame.body:EnableMouseWheel(true)
    frame.body:SetScript("OnMouseWheel", frame:GetScript("OnMouseWheel"))
    scrollbar:EnableMouseWheel(true)
    scrollbar:SetScript("OnMouseWheel", frame:GetScript("OnMouseWheel"))
    CreateFavorites(frame)
    -- Mouse-enabled children consume clicks, so route their right-clicks too.
    for _, region in ipairs({ frame, frame.body, title, frame.statistic, frame.session, close, menu, scrollbar, resize }) do
        local mouseUp = region:GetScript("OnMouseUp")
        region:SetScript("OnMouseUp", function(owner, button)
            if button == "RightButton" then
                self:ToggleFavorites(frame)
            elseif mouseUp then
                mouseUp(owner, button)
            end
        end)
    end
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        frame.editing = nil
        frame.favorites:Hide()
    end)
    return frame
end

function app:ApplyWindowLayout(frame)
    frame.favorites:Hide()
    local config = frame.config
    local collapsed = self:IsWindowCollapsed(config)
    frame.applyingLayout = true
    local height = self:GetWindowSetting(config, "height")
    local fixed = self:GetWindowSetting(config, "fixedHeight")
    frame:SetResizeBounds(200, collapsed and HEADER_HEIGHT or (fixed and height or 120), 800, fixed and height or 900)
    frame:SetHeight(collapsed and HEADER_HEIGHT or self:GetWindowSetting(config, "height"))
    self:PositionWindow(frame)
    frame.applyingLayout = false
    frame.body:SetShown(not collapsed)
    frame.background:SetShown(not collapsed)
    frame.resize:SetShown(
        not collapsed
            and self:GetWindowSetting(config, "showResizeHandle")
            and not self:GetWindowSetting(config, "lockSize")
    )
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
        self:StyleWindowLabel(frame.message, config)
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
    local font = self:GetWindowSetting(config, "font")
    local fontPath
    if font == "Default damage meter" then
        fontPath = NumberFontNormal:GetFont()
    else
        fontPath = media:Fetch("font", font)
    end
    label:SetFont(fontPath, self:GetWindowSetting(config, "fontSize"), self:GetWindowSetting(config, "fontFlags"))
    label:SetTextColor(unpack(self:GetWindowSetting(config, "textColor")))
end
