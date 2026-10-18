---@type string, SeamlessDamageMeter
local _, app = ...
local service, archive = app.combatService, app.archive

local function Amount(value)
    return AbbreviateLargeNumbers(value or 0)
end

local function Label(parent, text, x, y, width, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)
    return label
end

local function Shade(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

-- Each list owns its scroll position and reuses its rows across refreshes.
local function Panel(frame, title, x, y, width, height, columns)
    local panel = CreateFrame("Frame", nil, frame.dashboard)
    panel:SetPoint("TOPLEFT", x, y)
    panel:SetSize(width, height)
    Shade(panel, 0, 0, 0, 0.45)
    panel.heading = Label(panel, title, 10, -9, width - 20, "GameFontNormal")
    panel.message = Label(panel, "", 10, -height + 20, width - 20)
    panel.message:SetTextColor(0.65, 0.65, 0.65)
    panel.columns = columns
    if columns then
        Label(panel, "#   Name", 10, -32, width - 255)
        for index, name in ipairs({ "Amount", "Rate", "Share" }) do
            local label = Label(panel, name, width - 242 + (index - 1) * 78, -32, 72)
            label:SetJustifyH("RIGHT")
        end
    end
    panel.scroll = CreateFrame("ScrollFrame", nil, panel)
    panel.scroll:SetPoint("TOPLEFT", 6, columns and -50 or -32)
    panel.scroll:SetPoint("BOTTOMRIGHT", -6, 26)
    panel.scroll:EnableMouseWheel(true)
    panel.scroll:SetScript("OnMouseWheel", function(scroll, delta)
        scroll:SetVerticalScroll(
            math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() - delta * 56))
        )
    end)
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.content:SetSize(width - 12, 1)
    panel.scroll:SetScrollChild(panel.content)
    panel.rows = {}
    panel.width = width - 12
    return panel
end

local function ListRow(panel, index)
    local row = panel.rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, panel.content)
    row:SetSize(panel.width, 26)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
    Shade(row, 0.12, 0.12, 0.12, index % 2 == 0 and 0.65 or 0.35)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("TOPLEFT", 26, 0)
    row.bar:SetPoint("BOTTOMRIGHT")
    row.bar:SetStatusBarTexture("Interface\\AddOns\\SeamlessDamageMeter\\Textures\\ShadedBar.tga")
    row.bar:SetMinMaxValues(0, 1)
    row.bar:EnableMouse(false)
    row.icon = row.bar:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("RIGHT", row.bar, "LEFT")
    row.name = Label(row.bar, "", 6, -7, panel.columns and panel.width - 280 or panel.width - 38)
    row.values = {}
    if panel.columns then
        for position = 1, 3 do
            local label = Label(row.bar, "", panel.width - 262 + (position - 1) * 78, -7, 72)
            label:SetJustifyH("RIGHT")
            row.values[position] = label
        end
    end
    row.selection = row.bar:CreateTexture(nil, "OVERLAY")
    row.selection:SetAllPoints()
    row.selection:SetColorTexture(1, 0.82, 0.25, 0.16)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:SetScript("OnClick", function()
        if row.select then
            row.select()
        end
    end)
    row:SetScript("OnEnter", function()
        if row.tip then
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetText(row.tip)
            GameTooltip:Show()
        end
    end)
    local function HideTooltip()
        if GameTooltip:IsOwned(row) then
            GameTooltip:Hide()
        end
    end
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnHide", HideTooltip)
    panel.rows[index] = row
    return row
end

local function FinishList(panel, count, message)
    for index = count + 1, #panel.rows do
        panel.rows[index]:Hide()
    end
    panel.content:SetHeight(math.max(1, count * 28))
    panel.scroll:SetVerticalScroll(
        math.min(panel.scroll:GetVerticalScroll(), math.max(0, count * 28 - panel.scroll:GetHeight()))
    )
    panel.message:SetText(message or (count > 0 and "Mouse wheel to scroll" or "No entries available."))
end

local function PopulateRow(panel, index, entry, maximum, total, color, counts)
    local row = ListRow(panel, index)
    local id = entry.spellID or entry.spellId
    local name = entry.spellName or entry.name or (id and C_Spell.GetSpellName(id)) or entry.event or UNKNOWN
    local amount = entry.totalAmount or entry.amount or 0
    row.name:SetText(index .. ". " .. name)
    row.tip = name
    if entry.isAvoidable then
        row.tip = row.tip .. "\nAvoidable damage"
    end
    if entry.isDeadly then
        row.tip = row.tip .. "\nDeadly"
    end
    if entry.overkillAmount and entry.overkillAmount > 0 then
        row.tip = row.tip .. "\nOverkill: " .. Amount(entry.overkillAmount)
    end
    local unit = entry.combatSpellDetails
    if unit and unit.unitName then
        row.tip = row.tip .. "\n" .. unit.unitName
    elseif entry.sourceName then
        row.tip = row.tip .. "\n" .. entry.sourceName
    end
    local icon = entry.specIconID or (unit and unit.specIconID)
    local class = entry.classFilename or (unit and unit.unitClassFilename)
    if id then
        row.icon:SetTexture(C_Spell.GetSpellTexture(id))
    elseif icon and icon ~= 0 then
        row.icon:SetTexture(icon)
    elseif archive:IsPublic(class) and class and class ~= "" then
        row.icon:SetAtlas(GetClassAtlas(class))
    else
        row.icon:SetTexture(nil)
    end
    row.bar:SetMinMaxValues(0, math.max(1, maximum or 0))
    row.bar:SetValue(amount)
    row.bar:SetStatusBarColor(color.r, color.g, color.b, 0.8)
    row.selection:Hide()
    row.select = nil
    if panel.columns then
        row.values[1]:SetText(Amount(amount))
        row.values[2]:SetText(not counts and entry.amountPerSecond and Amount(entry.amountPerSecond) or "")
        row.values[3]:SetText(total and total > 0 and ("%.1f%%"):format(amount / total * 100) or "")
        if entry.enemyShare then
            row.tip = row.tip .. ("\nShare of enemy damage received: %.1f%%"):format(entry.enemyShare)
        end
    end
    row:Show()
    return row
end

local function CreateAnalysis()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(940, 620)
    frame:SetScale(math.min(1, UIParent:GetWidth() / 960, UIParent:GetHeight() / 640))
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("damagemeters-background")
    background:SetAllPoints()
    background:SetVertexColor(0.12, 0.12, 0.12, 1)
    local rim = CreateFrame("Frame", nil, frame)
    rim:SetPoint("TOPLEFT", 0, 0)
    rim:SetPoint("TOPRIGHT", 0, 0)
    rim:SetHeight(2)
    Shade(rim, 0.65, 0.5, 0.2, 1)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 16, -16)
    frame.title:SetPoint("RIGHT", -45, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetNormalFontObject("GameFontHighlight")
    close:SetText("X")
    close:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.scroll = CreateFrame("ScrollFrame", nil, frame)
    frame.scroll:SetPoint("TOPLEFT", 16, -130)
    frame.scroll:SetPoint("BOTTOMRIGHT", -16, 38)
    frame.scroll:EnableMouseWheel(true)
    frame.scroll:SetScript("OnMouseWheel", function(scroll, delta)
        scroll:SetVerticalScroll(
            math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() - delta * 48))
        )
    end)
    frame.text = CreateFrame("EditBox", nil, frame.scroll)
    frame.text:SetMultiLine(true)
    frame.text:SetAutoFocus(false)
    frame.text:SetFontObject("GameFontHighlight")
    frame.text:SetWidth(908)
    frame.text:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    frame.text:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local scroll = frame.scroll
        local offset = scroll:GetVerticalScroll()
        if -y < offset then
            scroll:SetVerticalScroll(math.max(0, -y))
        elseif -y + height > offset + scroll:GetHeight() then
            scroll:SetVerticalScroll(math.max(0, -y + height - scroll:GetHeight()))
        end
    end)
    frame.scroll:SetScrollChild(frame.text)
    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.footer:SetPoint("BOTTOMLEFT", 16, 14)
    frame.footer:SetText(
        "Mouse wheel to scroll. Select text and Ctrl+C to copy. Same-name enemies may be grouped by the client."
    )
    frame.summary = Label(frame, "", 16, -91, 908, "GameFontHighlight")
    frame.dashboard = CreateFrame("Frame", nil, frame)
    frame.dashboard:SetPoint("TOPLEFT", 16, -126)
    frame.dashboard:SetSize(908, 448)
    frame.actors = Panel(frame, "Players / enemies", 0, 0, 224, 224)
    frame.sessions = Panel(frame, "Fights", 0, -234, 224, 214)
    frame.spells = Panel(frame, "Spell breakdown", 234, 0, 674, 280, true)
    frame.targets = Panel(frame, "Targets", 234, -290, 674, 158, true)
    frame.buttons = {}
    for index, tab in ipairs({
        { "fight", "Fight" },
        { "spells", "Breakdown" },
        { "targets", "Targets / players" },
        { "report", "Copy report" },
    }) do
        local key = tab[1]
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(150, 26)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 175, -50)
        Shade(button, 0.18, 0.15, 0.09, 0.8)
        button:SetNormalFontObject("GameFontHighlight")
        button:SetHighlightFontObject("GameFontNormal")
        button:SetText(tab[2])
        button:SetScript("OnClick", function()
            frame.mode = key
            app:RefreshAnalysis()
            if key == "report" then
                frame.text:SetFocus()
                frame.text:HighlightText()
            end
        end)
        frame.buttons[key] = button
    end
    frame:Hide()
    app.analysisWindow = frame
    return frame
end

local function SourceFor(frame, session)
    if not frame.sourceIdentity then
        return nil
    end
    for _, source in ipairs(session and session.combatSources or {}) do
        if
            archive:IsPublic(source.sourceGUID)
            and archive:IsPublic(source.name)
            and archive:IsPublic(source.sourceCreatureID)
            and (source.sourceGUID or source.name) == frame.sourceIdentity
            and source.sourceCreatureID == frame.sourceCreatureID
        then
            return source
        end
    end
end

local function ResetLists(frame)
    for _, panel in ipairs({ frame.actors, frame.sessions, frame.spells, frame.targets }) do
        panel.scroll:SetVerticalScroll(0)
    end
end

local function RefreshDashboard(frame, session, source, reason)
    local config = frame.config
    local counts = config.statistic == "Interrupts" or config.statistic == "Dispels" or config.statistic == "Deaths"
    local color = { r = 0.65, g = 0.5, b = 0.2 }
    if source and archive:IsPublic(source.classFilename) then
        color = RAID_CLASS_COLORS[source.classFilename] or color
    end
    local actorCount = 0
    for _, actor in ipairs(session and session.combatSources or {}) do
        -- Identity and totals are needed for selection and public percentage arithmetic.
        if
            archive:IsPublic(actor.name)
            and archive:IsPublic(actor.sourceGUID)
            and archive:IsPublic(actor.sourceCreatureID)
            and archive:IsPublic(actor.totalAmount)
            and archive:IsPublic(actor.specIconID)
        then
            actorCount = actorCount + 1
            local row = PopulateRow(frame.actors, actorCount, actor, 1, nil, color, counts)
            row.bar:SetValue(0)
            row.selection:SetShown(actor == source)
            row.select = function()
                frame.sourceIdentity, frame.sourceCreatureID = actor.sourceGUID or actor.name, actor.sourceCreatureID
                frame.spells.scroll:SetVerticalScroll(0)
                frame.targets.scroll:SetVerticalScroll(0)
                app:RefreshAnalysis()
            end
        end
    end
    FinishList(frame.actors, actorCount, actorCount == 0 and (reason or "No public actors available.") or nil)
    local choices = { { name = "Current combat", session = "Current" }, { name = "Overall", session = "Overall" } }
    for _, entry in ipairs(service:ListSessions()) do
        choices[#choices + 1] = entry
    end
    for index, entry in ipairs(choices) do
        local row = ListRow(frame.sessions, index)
        row.name:SetText(entry.name)
        row.tip = (entry.archiveID or entry.sessionID) and service:Describe(entry, true) or entry.name
        row.icon:SetTexture(nil)
        row.bar:SetValue(0)
        row.selection:SetShown(
            (entry.archiveID and entry.archiveID == config.archiveID)
                or (entry.sessionID and entry.sessionID == config.sessionID)
                or (
                    entry.session
                    and not config.archiveID
                    and not config.sessionID
                    and entry.session == (config.session or "Current")
                )
        )
        row.select = function()
            config.archiveID, config.sessionID, config.sessionGeneration =
                entry.archiveID, entry.sessionID, entry.sessionGeneration
            config.session = entry.session or "Current"
            ResetLists(frame)
            app:RefreshAnalysis()
        end
        row:Show()
    end
    FinishList(frame.sessions, #choices)
    local details, message
    if source then
        details, message = service:GetDetails(config, source, config.statistic)
    end
    local public = details and archive:CopyDetails(details)
    local entries = public and (public.deathEvents or public.combatSpells) or {}
    local maximum = 0
    for _, entry in ipairs(entries) do
        maximum = math.max(maximum, entry.totalAmount or entry.amount or 0)
    end
    frame.spells.heading:SetText(config.statistic == "Deaths" and "Death recap" or "Spell breakdown")
    local total = config.statistic ~= "Deaths"
            and source
            and archive:IsPublic(source.totalAmount)
            and source.totalAmount
        or nil
    for index, entry in ipairs(entries) do
        PopulateRow(frame.spells, index, entry, maximum, total, color, counts)
    end
    FinishList(
        frame.spells,
        #entries,
        not public and (message or "Select a public actor to inspect its spells.") or nil
    )
    local targets, targetMessage
    if source and config.statistic == "EnemyDamageTaken" then
        targets, targetMessage = service:GetEnemyContributors(config, source)
    elseif source and (config.statistic == "DamageDone" or config.statistic == "Dps") then
        targets, targetMessage = service:GetPlayerTargets(config, source)
    else
        targetMessage = "Target breakdown is available for damage done, DPS and enemy damage taken."
    end
    frame.targets.heading:SetText(config.statistic == "EnemyDamageTaken" and "Contributors" or "Targets")
    for index, entry in ipairs(targets and targets.entries or {}) do
        PopulateRow(frame.targets, index, entry, targets.maxAmount, targets.totalAmount, color, counts)
    end
    FinishList(
        frame.targets,
        targets and #targets.entries or 0,
        targets and not targets.complete and "Available contributions only; totals do not fully reconcile."
            or targetMessage
    )
end

function app:ShowAnalysis(config, source)
    local frame = self.analysisWindow or CreateAnalysis()
    frame.config = {
        statistic = config.statistic,
        session = config.session,
        sessionID = config.sessionID,
        sessionGeneration = config.sessionGeneration,
        archiveID = config.archiveID,
    }
    frame.sourceIdentity, frame.sourceCreatureID, frame.comparison = nil, nil, nil
    if
        source
        and archive:IsPublic(source.name)
        and archive:IsPublic(source.sourceGUID)
        and archive:IsPublic(source.sourceCreatureID)
    then
        frame.sourceIdentity, frame.sourceCreatureID = source.sourceGUID or source.name, source.sourceCreatureID
    end
    frame.mode = source and "spells" or "fight"
    ResetLists(frame)
    frame.scroll:SetVerticalScroll(0)
    frame:Show()
    self:RefreshAnalysis()
end

function app:ShowComparison(firstID, secondID, statistic)
    local frame = self.analysisWindow or CreateAnalysis()
    frame.config = { archiveID = firstID, statistic = statistic }
    frame.comparison, frame.mode = secondID, "compare"
    frame.sourceIdentity = nil
    frame.scroll:SetVerticalScroll(0)
    frame:Show()
    self:RefreshAnalysis()
end

function app:RefreshAnalysis()
    local frame = self.analysisWindow
    if not frame or not frame:IsShown() then
        return
    end
    local config = frame.config
    local fight = service:GetMetadata(config)
    local title = fight and fight.name or "Live combat analysis"
    local lines = {}
    local session, reason = service:GetSession(config, config.statistic)
    local source = SourceFor(frame, session)
    local dashboard = not frame.comparison and (frame.mode == "spells" or frame.mode == "targets")
    frame.dashboard:SetShown(dashboard)
    frame.scroll:SetShown(not dashboard)
    frame.summary:SetText(self:GetStatistic(config.statistic).label)
    for key, button in pairs(frame.buttons) do
        button:SetNormalFontObject(key == frame.mode and "GameFontNormal" or "GameFontHighlight")
    end
    frame.buttons.targets:SetShown(frame.comparison ~= nil)
    frame.buttons.spells:SetText(frame.comparison and "Spells" or "Breakdown")
    frame.buttons.report:ClearAllPoints()
    frame.buttons.report:SetPoint("TOPLEFT", frame.comparison and 541 or 366, -50)
    if dashboard then
        RefreshDashboard(frame, session, source, reason)
        if source then
            title = title .. " - " .. source.name
            local amount = archive:IsPublic(source.totalAmount) and Amount(source.totalAmount) or "Unavailable"
            local rate = archive:IsPublic(source.amountPerSecond) and source.amountPerSecond
            local duration = service:GetDuration(config, session)
            local showRate = rate
                and config.statistic ~= "Deaths"
                and config.statistic ~= "Interrupts"
                and config.statistic ~= "Dispels"
            frame.summary:SetText(
                self:GetStatistic(config.statistic).label
                    .. "   |   Total: "
                    .. amount
                    .. (showRate and ("   |   Rate: " .. Amount(rate) .. "/s") or "")
                    .. (
                        archive:IsPublic(duration)
                            and duration
                            and ("   |   Duration: " .. SecondsToClock(duration))
                        or ""
                    )
            )
        end
        frame.title:SetText(title)
        frame.footer:SetText(
            "Select an actor or fight. Hover a spell for details. Same-name enemies may be grouped by the client."
        )
        return
    end
    frame.footer:SetText("Mouse wheel to scroll. Select text and Ctrl+C to copy.")
    if frame.mode == "compare" or (frame.comparison and (frame.mode == "spells" or frame.mode == "targets")) then
        local other = archive:Get(frame.comparison)
        title = title .. " → " .. (other and other.name or "Deleted fight")
        local rows, message = service:Compare(config.archiveID, frame.comparison, config.statistic, frame.mode)
        lines[1] = "First fight → second fight. Differences are second minus first."
        lines[2] = "Statistic: " .. self:GetStatistic(config.statistic).label
        lines[3] = "Use Spells or Targets / players to compare breakdowns."
        if rows then
            for _, row in ipairs(rows) do
                lines[#lines + 1] = ("%s: %s → %s; difference %s; rate %.1f → %.1f/s (difference %+.1f/s)"):format(
                    row.name,
                    Amount(row.first),
                    Amount(row.second),
                    Amount(row.delta),
                    row.firstRate,
                    row.secondRate,
                    row.rateDelta
                )
                for _, entry in ipairs(row.breakdown or {}) do
                    local name = entry.spellID and C_Spell.GetSpellName(entry.spellID) or entry.name
                    lines[#lines + 1] = ("    %s: %s → %s; difference %s (rate %.1f → %.1f/s)"):format(
                        name or entry.name,
                        Amount(entry.first),
                        Amount(entry.second),
                        Amount(entry.delta),
                        entry.firstRate,
                        entry.secondRate
                    )
                end
                if row.incomplete then
                    lines[#lines + 1] = "    Breakdown is incomplete or unavailable for this statistic."
                end
            end
        else
            lines[#lines + 1] = message
        end
    elseif frame.mode == "report" then
        local report, message = service:Report(config)
        lines[1] = report or message
    elseif frame.mode == "fight" then
        if fight then
            lines[#lines + 1] = "Saved fight " .. fight.id .. " - " .. date("%d %b %Y %H:%M:%S", fight.capturedAt)
            lines[#lines + 1] = "Duration: " .. SecondsToClock(fight.durationSeconds or 0)
            lines[#lines + 1] = fight.complete and "Capture: complete"
                or "Capture: incomplete; some categories or details are unavailable."
            if fight.imported then
                lines[#lines + 1] =
                    "Imported from client history; the displayed date is when Seamless first observed it."
            end
            if fight.instance then
                lines[#lines + 1] = "Instance: " .. (fight.instance.name or "Unknown")
            end
            if fight.encounter then
                lines[#lines + 1] = "Encounter: "
                    .. (fight.encounter.name or "Unknown")
                    .. (fight.encounter.success == nil and "" or (fight.encounter.success and " - Kill" or " - Wipe"))
            end
            for _, statistic in ipairs(self.statistics) do
                local category = fight.categories[statistic.key]
                lines[#lines + 1] = statistic.label
                    .. ": "
                    .. (
                        category
                            and (Amount(category.session.totalAmount) .. (category.complete and "" or " - missing source details"))
                        or "not captured"
                    )
            end
        else
            lines[1] =
                "Live client data. Completed public fights are captured automatically, even with every window hidden."
            lines[2] = reason or "Select a saved fight for persistent metadata and reports."
        end
    end
    frame.title:SetText(title)
    local text = table.concat(lines, "\n\n")
    if frame.displayText ~= text then
        frame.displayText = text
        frame.text:SetText(text)
        frame.text:SetHeight(math.max(350, (#text / 70 + #lines * 2) * 18))
        frame.text:ClearFocus()
    end
end
