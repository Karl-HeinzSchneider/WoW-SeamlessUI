---@type string, SeamlessTooltip
local _, app = ...

local anySecret = app.features.AnySecret

-- Shared by the features that change the text lines of unit tooltips (Player text, NPC text): which
-- unit a tooltip's lines belong to, and the pieces those lines are made of. This client shows a
-- player as name, (guild,) "Level 3 Dwarf (Player)", a class line ("Priest"), the faction; an NPC
-- as name, (title,) "Level 10 (Elite)", for enemies a creature type line ("Beast").
---@class SeamlessTooltip.UnitTooltip
local unitTooltip = {}
app.unitTooltip = unitTooltip

local LineType = Enum.TooltipDataLineType

-- The word(s) around the level in the level line: "Level " before it for TOOLTIP_UNIT_LEVEL =
-- "Level %s"; other languages may put them after it.
local LEVEL_BEFORE, LEVEL_AFTER = TOOLTIP_UNIT_LEVEL:match("^(.-)%%s(.*)$")

-- Per tooltip whose lines are being processed: its unit, if addon code may read it.
---@type table<GameTooltip, { unit: string?, isPlayer: boolean }>
local units = {}

-- True while the lines of a unit tooltip are being processed.
---@param tooltip GameTooltip
---@return boolean
function unitTooltip.IsUnitTooltip(tooltip)
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    return info ~= nil and info.tooltipData ~= nil and info.tooltipData.type == Enum.TooltipDataType.Unit
end

-- The name line (always the first line of a unit tooltip) names the unit. Registered at file load,
-- before any feature's line callbacks, so they all see the new unit on that line already.
TooltipDataProcessor.AddLinePreCall(TooltipDataProcessor.AllTypes, function(tooltip, lineData)
    if lineData.type ~= LineType.UnitName or not unitTooltip.IsUnitTooltip(tooltip) then
        return
    end
    local unit = lineData.unitToken
    local readableUnit = unit and not anySecret(unit) and unit or nil
    -- Checked for a secret before its truth is tested.
    local isPlayer = false
    if readableUnit then
        local result = UnitIsPlayer(readableUnit)
        isPlayer = not anySecret(result) and result == true
    end
    units[tooltip] = { unit = readableUnit, isPlayer = isPlayer }
end)

-- The unit whose tooltip lines are being processed, and whether it is a player; nil when it is not
-- a unit tooltip or the unit can't be read.
---@param tooltip GameTooltip
---@return string? unit
---@return boolean isPlayer
function unitTooltip.Unit(tooltip)
    local entry = unitTooltip.IsUnitTooltip(tooltip) and units[tooltip]
    if entry and entry.unit then
        return entry.unit, entry.isPlayer
    end
    return nil, false
end

-- The hostile/friendly color the game uses for a unit's name. This mirrors
-- GameTooltip_UnitColor, but checks every unit query before testing its result: Blizzard's helper
-- tests those results directly and errors when one is secret in restricted content.
---@param unit string
---@return number? r
---@return number? g
---@return number? b
function unitTooltip.UnitColor(unit)
    local playerControlled = UnitPlayerControlled(unit)
    if anySecret(playerControlled) then
        return
    end
    if playerControlled then
        local canAttackPlayer = UnitCanAttack(unit, "player")
        if anySecret(canAttackPlayer) then
            return
        end
        if canAttackPlayer then
            local playerCanAttack = UnitCanAttack("player", unit)
            if anySecret(playerCanAttack) then
                return
            end
            local color = playerCanAttack and FACTION_BAR_COLORS[2] or WHITE_FONT_COLOR
            return color.r, color.g, color.b
        end

        local playerCanAttack = UnitCanAttack("player", unit)
        if anySecret(playerCanAttack) then
            return
        end
        if playerCanAttack then
            local color = FACTION_BAR_COLORS[4]
            return color.r, color.g, color.b
        end

        local isPvp = UnitIsPVP(unit)
        if anySecret(isPvp) then
            return
        end
        local color = isPvp and FACTION_BAR_COLORS[6] or WHITE_FONT_COLOR
        return color.r, color.g, color.b
    end

    local reaction = UnitReaction(unit, "player")
    if anySecret(reaction) then
        return
    end
    local color = reaction and FACTION_BAR_COLORS[reaction] or WHITE_FONT_COLOR
    return color.r, color.g, color.b
end

-- A unit's name as the game shows it: on this client with the character's surname ("First Last";
-- UnitName's second return is the surname here, the realm elsewhere), through Blizzard's
-- NameUtil.FormatUnitNameForDisplay where it exists. Nil when the name is secret.
---@param unit string
---@return string?
function unitTooltip.DisplayName(unit)
    local name, surname = UnitName(unit)
    if not name or anySecret(name, surname) then
        return
    end
    if NameUtil and NameUtil.FormatUnitNameForDisplay then
        return NameUtil.FormatUnitNameForDisplay(unit)
    end
    return name
end

-- The name line?
---@param lineData table
---@return boolean
function unitTooltip.IsNameLine(lineData)
    return lineData.type == LineType.UnitName
end

-- The left font string of a line that was just added.
---@param tooltip GameTooltip
---@param lineData table
---@return FontString?
function unitTooltip.LeftLine(tooltip, lineData)
    local name = tooltip:GetName()
    return name and lineData.lineIndex and _G[name .. "TextLeft" .. lineData.lineIndex]
end

-- A line's text if addon code may read it.
---@param text any
---@return string?
function unitTooltip.Readable(text)
    if type(text) == "string" and not anySecret(text) then
        return text
    end
end

-- The level line: the first after the name with a level (a number or "??"); names, titles and
-- guilds have none. Callers track "first" themselves.
---@param text string
---@return boolean
function unitTooltip.HasLevel(text)
    return text:find("%d") ~= nil or text:find("??", 1, true) ~= nil
end

-- Whether a faction line ("Alliance", "Horde", "Neutral") is dropped for a `mode` of "SHOW",
-- "OWN" (hide the player's own faction) or "HIDE". Nil for any other line.
---@param text string
---@param mode string
---@return boolean?
function unitTooltip.DropFactionLine(text, mode)
    if text ~= FACTION_ALLIANCE and text ~= FACTION_HORDE and text ~= FACTION_NEUTRAL then
        return nil
    end
    if mode == "HIDE" then
        return true
    elseif mode == "OWN" then
        local _, ownFaction = UnitFactionGroup("player")
        return text == ownFaction
    end
    return false
end

-- A select option for DropFactionLine's mode; a new table per feature, as the options framework
-- writes into it.
---@param order integer
---@return table
function unitTooltip.FactionOption(order)
    return {
        type = "select",
        order = order,
        name = "Faction line",
        desc = 'The "Alliance" / "Horde" line.',
        values = {
            SHOW = "Show",
            OWN = "Hide if it is your own faction",
            HIDE = "Hide",
        },
        sorting = { "SHOW", "OWN", "HIDE" },
    }
end

-- The level's difficulty color compared to the player, like quest and creature levels; "??" (far
-- above the player) in the highest one.
---@param level string a number or "??"
---@return string
function unitTooltip.ColorLevel(level)
    local color = tonumber(level) and GetCreatureDifficultyColor(tonumber(level)) or QuestDifficultyColors.impossible
    return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, level)
end

-- "Level 10 (Elite)" → "", "10" (colored), " (Elite)": the level line split around the level,
-- the word "Level" dropped. Nil without a level.
---@param text string
---@return string? head
---@return string? level
---@return string? tail
function unitTooltip.LevelParts(text)
    local first, last = text:find("%d+")
    if not first then
        first, last = text:find("??", 1, true)
    end
    if not first then
        return
    end
    local head, tail = text:sub(1, first - 1), text:sub(last + 1)
    if LEVEL_BEFORE and LEVEL_BEFORE ~= "" and head:sub(-#LEVEL_BEFORE) == LEVEL_BEFORE then
        head = head:sub(1, -#LEVEL_BEFORE - 1)
    end
    if LEVEL_AFTER and LEVEL_AFTER ~= "" and tail:sub(1, #LEVEL_AFTER) == LEVEL_AFTER then
        tail = tail:sub(#LEVEL_AFTER + 1)
    end
    return head, unitTooltip.ColorLevel(text:sub(first, last)), tail
end

-- Replaces the first plain occurrence of `word` in `text` (nil if there is none).
---@param text string
---@param word string
---@param replacement string
---@return string?
function unitTooltip.ReplaceWord(text, word, replacement)
    local first, last = text:find(word, 1, true)
    if first then
        return text:sub(1, first - 1) .. replacement .. text:sub(last + 1)
    end
end
