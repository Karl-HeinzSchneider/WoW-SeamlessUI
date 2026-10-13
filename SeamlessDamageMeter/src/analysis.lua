---@type string, SeamlessDamageMeter
local _, app = ...
local service, archive = app.combatService, app.archive

local function Amount(value)
    return AbbreviateLargeNumbers(value or 0)
end

local function CreateAnalysis()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(740, 480)
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
    frame.scroll:SetPoint("TOPLEFT", 16, -88)
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
    frame.text:SetWidth(700)
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
    frame.buttons = {}
    for index, tab in ipairs({
        { "fight", "Fight" },
        { "spells", "Spells" },
        { "targets", "Targets / players" },
        { "report", "Copy report" },
    }) do
        local key = tab[1]
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(150, 26)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 175, -50)
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
    elseif not source then
        lines[1] = "Select a public player or enemy row to inspect it. Restricted or expired rows cannot be analyzed."
    elseif frame.mode == "targets" then
        title = title .. " - " .. source.name
        local breakdown, message
        if config.statistic == "EnemyDamageTaken" then
            breakdown, message = service:GetEnemyContributors(config, source)
            lines[1] = "Contributors: damage, rate, share of this enemy's damage received."
        elseif config.statistic == "DamageDone" or config.statistic == "Dps" then
            breakdown, message = service:GetPlayerTargets(config, source)
            lines[1] = "Targets: damage, rate, share of your damage / share of the enemy's damage received."
        else
            message = "Target analysis is available for damage done, DPS and enemy damage taken."
        end
        if breakdown then
            for _, entry in ipairs(breakdown.entries) do
                local own = source.totalAmount > 0 and entry.totalAmount / source.totalAmount * 100 or 0
                local text = ("%s: %s (%.1f/s) %.1f%%"):format(
                    entry.spellName,
                    Amount(entry.totalAmount),
                    entry.amountPerSecond or 0,
                    own
                )
                if config.statistic ~= "EnemyDamageTaken" then
                    text = text .. (" / %.1f%%"):format(entry.enemyShare or 0)
                end
                lines[#lines + 1] = text
            end
            if not breakdown.complete then
                lines[#lines + 1] = "Incomplete contributions; totals do not fully reconcile."
            end
        else
            lines[#lines + 1] = message
        end
    else
        title = title .. " - " .. source.name
        local details, message = service:GetDetails(config, source, config.statistic)
        local public = details and archive:CopyDetails(details)
        if public then
            for _, spell in ipairs(public.deathEvents or public.combatSpells or {}) do
                local id = spell.spellID or spell.spellId
                local name = spell.spellName or (id and C_Spell.GetSpellName(id)) or spell.event or UNKNOWN
                local unit = spell.combatSpellDetails and spell.combatSpellDetails.unitName or spell.sourceName
                local text = name
                    .. (unit and unit ~= "" and (" - " .. unit) or "")
                    .. ": "
                    .. Amount(spell.totalAmount or spell.amount)
                if spell.amountPerSecond then
                    text = text .. (" (%.1f/s)"):format(spell.amountPerSecond)
                end
                if spell.isAvoidable then
                    text = text .. " - avoidable"
                end
                if spell.isDeadly then
                    text = text .. " - deadly"
                end
                if spell.overkillAmount and spell.overkillAmount > 0 then
                    text = text .. " - overkill " .. Amount(spell.overkillAmount)
                end
                lines[#lines + 1] = text
            end
            if #lines == 0 then
                lines[1] = "No source details available."
            end
        else
            lines[1] = message or "Detailed analysis is available when combat values become public."
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
