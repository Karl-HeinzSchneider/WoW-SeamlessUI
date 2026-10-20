---@type string, SeamlessCastbar
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Cast time and spell rank text. The player bar has the game's own cast time text, switched on
-- by its Edit Mode "Show Cast Time" setting; we only change how it reads. Target and focus bars
-- have none, so they get one of ours, to the right of the bar like the player's.

---@param value any
local function known(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end
app.Known = known

-- Cast time formats by profile value, and their order in menus.
app.castTimeFormats = {
    REMAINING = L["Remaining (1.3)"],
    REMAINING_TOTAL = L["Remaining / total (1.3 / 2.5)"],
    ELAPSED_TOTAL = L["Elapsed / total (1.2 / 2.5)"],
}
app.castTimeFormatOrder = { "REMAINING", "REMAINING_TOTAL", "ELAPSED_TOTAL" }

---@param elapsed number seconds since the cast started
---@param total number cast or channel length
---@param format "REMAINING"|"REMAINING_TOTAL"|"ELAPSED_TOTAL"
---@param decimals integer
---@return string
function app.FormatCastTime(elapsed, total, format, decimals)
    local pattern = "%." .. decimals .. "f"
    elapsed = math.min(math.max(elapsed, 0), total)
    local remaining = total - elapsed
    if format == "REMAINING" then
        return pattern:format(remaining)
    end
    local first = format == "ELAPSED_TOTAL" and elapsed or remaining
    return L["%s / %s (cast time)"]:format(pattern:format(first), pattern:format(total))
end

-- Our cast time text on bars without the game's own.
---@type table<StatusBar, FontString>
local timeTexts = {}

---@param bar StatusBar
---@return FontString
local function timeText(bar)
    local text = timeTexts[bar]
    if not text then
        text = bar:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
        text:SetPoint("LEFT", bar, "RIGHT", 4, 0)
        timeTexts[bar] = text
    end
    return text
end

---@param bar StatusBar
function app.UpdateCastTime(bar)
    local own = not bar.CastTimeText
    local settings = app.Active(bar) and app.Settings(bar).castTime
    if not (settings and settings.enabled) then
        if own and timeTexts[bar] then
            timeTexts[bar]:Hide()
        end
        return
    end
    -- After a cast ends the bar keeps showing its last time while it fades.
    if not (bar.casting or bar.channeling) then
        return
    end
    local value = bar:GetValue()
    local _, total = bar:GetMinMaxValues()
    if not known(value) or not known(total) or total <= 0 then
        if own and timeTexts[bar] then
            timeTexts[bar]:Hide()
        end
        return
    end
    -- A channel's bar runs down: its value is the time left.
    local elapsed = bar.channeling and total - value or value
    local label = app.FormatCastTime(elapsed, total, settings.format, settings.decimals)
    if own then
        local text = timeText(bar)
        text:SetText(label)
        text:Show()
    else
        bar.CastTimeText:SetText(label)
    end
end

---@param bar StatusBar
function app.RestoreCastTime(bar)
    if timeTexts[bar] then
        timeTexts[bar]:Hide()
    end
end

-- The spell name as the game set it, and the label we replaced it with.
---@type table<StatusBar, { name: string, label: string }>
local names = {}

---@param bar StatusBar
function app.RestoreName(bar)
    local changed = names[bar]
    names[bar] = nil
    if changed and bar.Text and bar.Text:GetText() == changed.label then
        bar.Text:SetText(changed.name)
    end
end

---@param bar StatusBar
function app.UpdateName(bar)
    if not (app.Active(bar) and app.Settings(bar).rank.enabled) then
        app.RestoreName(bar)
        return
    end
    local fontString = bar.Text
    if not fontString or not (bar.casting or bar.channeling) then
        return
    end
    local name, spellID = fontString:GetText(), bar.spellID
    if not known(name) or not name or name == "" or not known(spellID) then
        return
    end
    local changed = names[bar]
    if changed and name == changed.label then
        return
    end
    local rank = C_Spell.GetSpellSubtext(spellID)
    if not known(rank) or not rank or rank == "" then
        names[bar] = nil
        return
    end
    local label = L["%s (%s) (spell and rank)"]:format(name, rank)
    names[bar] = { name = name, label = label }
    fontString:SetText(label)
end

-- The player bar shows the spell icon only while it is locked to the player frame.
---@type table<StatusBar, true>
local icons = {}

---@param bar StatusBar
function app.RestoreIcon(bar)
    if icons[bar] then
        icons[bar] = nil
        if bar.look == "CLASSIC" then
            bar.Icon:Hide()
        end
    end
end

---@param bar StatusBar
function app.UpdateIcon(bar)
    if app.BarKey(bar) ~= "player" or not bar.Icon then
        return
    end
    if not (app.Active(bar) and app.Settings(bar).icon.enabled) then
        app.RestoreIcon(bar)
        return
    end
    if bar.look == "CLASSIC" then
        icons[bar] = true
        bar.Icon:Show()
    end
end
