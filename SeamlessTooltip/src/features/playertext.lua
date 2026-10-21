---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local unitTooltip = app.unitTooltip

-- Changes the text lines of player tooltips: name, class and race in color, a short level line
-- ("3 Dwarf Priest") with the level in its difficulty color, the guild as "<Guild> Rank (2)", the
-- class and the faction left out.
local feature -- declared first: the options below refer to it
feature = app.features:NewFeature("PlayerText", {
    category = "units",
    name = L["Player text"],
    desc = L["Changes the text of player tooltips."],
    order = 10,
    options = {
        classColorName = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Name in class color"],
        },
        classColorClass = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["Class in class color"],
        },
        raceReactionColor = {
            type = "toggle",
            order = 30,
            width = "full",
            name = L["Race in reaction color"],
            desc = L["Colors the race like the game colors hostile and friendly units: players of the other faction you can attack are red."],
        },
        shortLevel = {
            type = "toggle",
            order = 40,
            width = "full",
            name = L["Short level line"],
            desc = L['Shows "Level 3 Dwarf (Player)" and the class line as "3 Dwarf Priest", the level in its difficulty color (red is much higher than you, grey much lower).'],
        },
        hideClass = {
            type = "toggle",
            order = 50,
            width = "full",
            name = L["Hide the class"],
            desc = L['Leaves the class out; with the short level line, out of that line ("3 Dwarf").'],
        },
        guildLine = {
            type = "toggle",
            order = 60,
            width = "full",
            name = L["Guild as <Guild>"],
            desc = L["Shows the guild in brackets, in the player's hostile/friendly color; your own guild in pink."],
        },
        guildRank = {
            type = "toggle",
            order = 70,
            width = "full",
            name = L["Guild rank"],
            desc = L['Adds the player\'s guild rank behind the guild ("<Guild> Officer").'],
            disabled = function()
                local settings = feature:Settings()
                return not settings.enabled or not settings.guildLine
            end,
        },
        guildRankIndex = {
            type = "toggle",
            order = 80,
            width = "full",
            name = L["Guild rank number"],
            desc = L['Adds the rank\'s number behind the guild, 0 being the guild master ("<Guild> Officer (2)").'],
            disabled = function()
                local settings = feature:Settings()
                return not settings.enabled or not settings.guildLine
            end,
        },
        faction = unitTooltip.FactionOption(90),
    },
})

-- The guild of a player in your own guild, and the rank behind it: a bit greyed out.
local OWN_GUILD_COLOR = CreateColor(1.0, 0.3, 1.0)
local RANK_COLOR = CreateColor(0.65, 0.65, 0.65)

-- Per tooltip whose lines are being processed: whether its level line was handled yet.
---@type table<GameTooltip, boolean>
local levelDone = {}

-- Line callbacks for every line type; only lines of player tooltips are changed.
function feature:OnInitialize()
    self:AddLinePreCall(TooltipDataProcessor.AllTypes, "OnLinePre")
    self:AddLinePostCall(TooltipDataProcessor.AllTypes, "OnLinePost")
end

-- The player whose tooltip lines are being processed.
---@param tooltip GameTooltip
---@return string?
local function playerOf(tooltip)
    local unit, isPlayer = unitTooltip.Unit(tooltip)
    return isPlayer and unit or nil
end

-- The unit's localized class and its class color.
---@param unit string
---@return string? className
---@return ColorMixin? classColor
local function classOf(unit)
    local className, classFile = UnitClass(unit)
    if className and classFile and not anySecret(className, classFile) then
        return className, C_ClassColor.GetClassColor(classFile)
    end
end

-- `text` in the unit's name color (hostile red, friendly green, attackable players yellow, ...).
---@param unit string
---@param text string
---@return string
local function inReactionColor(unit, text)
    local r, g, b = unitTooltip.UnitColor(unit)
    if not r then
        return text
    end
    return CreateColor(r, g, b):WrapTextInColorCode(text)
end

-- The unit's guild and rank (its index 0 is the guild master), if addon code may read them.
---@param unit string
---@return string? guildName
---@return string? rankName
---@return integer? rankIndex
local function guildOf(unit)
    local guildName, rankName, rankIndex = GetGuildInfo(unit)
    if guildName and not anySecret(guildName, rankName, rankIndex) then
        return guildName, rankName, rankIndex
    end
end

-- The guild line's text without brackets if it is the unit's guild line (the guild name, maybe
-- with its realm), else nil.
---@param text string
---@param guildName string
---@return string?
local function guildLineName(text, guildName)
    local inner = text:match("^<(.*)>$") or text
    if inner:sub(1, #guildName) == guildName then
        return inner
    end
end

-- "<Guild>" in the unit's hostile/friendly color (pink for your own guild), then the grey rank and
-- rank number as set.
---@param unit string
---@param shownName string
---@param rankName string?
---@param rankIndex integer?
---@param settings table
---@return string
local function guildLine(unit, shownName, rankName, rankIndex, settings)
    local inOwnGuild = UnitIsInMyGuild(unit)
    local guild = "<" .. shownName .. ">"
    if not anySecret(inOwnGuild) and inOwnGuild then
        guild = OWN_GUILD_COLOR:WrapTextInColorCode(guild)
    else
        guild = inReactionColor(unit, guild)
    end
    local rank = {}
    if settings.guildRank and rankName and rankName ~= "" then
        rank[#rank + 1] = rankName
    end
    if settings.guildRankIndex and rankIndex then
        rank[#rank + 1] = "(" .. rankIndex .. ")"
    end
    if #rank == 0 then
        return guild
    end
    return guild .. " " .. RANK_COLOR:WrapTextInColorCode(table.concat(rank, " "))
end

---@param tooltip GameTooltip
---@param lineData table
---@return boolean? consumed true drops the line
function feature:OnLinePre(tooltip, lineData)
    local unit = playerOf(tooltip)
    if not unit then
        return
    end
    if unitTooltip.IsNameLine(lineData) then
        levelDone[tooltip] = false
        return
    end
    local text = unitTooltip.Readable(lineData.leftText)
    if not text or lineData.rightText then
        return
    end
    local settings = self:Settings()
    local dropFaction = unitTooltip.DropFactionLine(text, settings.faction)
    if dropFaction ~= nil then
        return dropFaction
    end
    -- The class line: the short level line carries the class itself.
    if (settings.shortLevel or settings.hideClass) and text == classOf(unit) then
        return true
    end
end

-- "Level 3 Dwarf (Player)" â†’ "3 Dwarf Priest". Nil when the race can't be read; the line then
-- stays as it is.
---@param unit string
---@param text string
---@param settings table
---@return string?
local function shortLevelLine(unit, text, settings)
    local race = UnitRace(unit)
    if not race or anySecret(race) then
        return
    end
    local parts = {
        unitTooltip.ColorLevel(text:match("%d+") or "??"),
        settings.raceReactionColor and inReactionColor(unit, race) or race,
    }
    if not settings.hideClass then
        local className, classColor = classOf(unit)
        if className then
            parts[#parts + 1] = settings.classColorClass and classColor:WrapTextInColorCode(className) or className
        end
    end
    return table.concat(parts, " ")
end

-- The level line kept in the game's form: only colors and the class word.
---@param unit string
---@param text string
---@param settings table
---@return string?
local function adjustLevelLine(unit, text, settings)
    local changed = text
    local className, classColor = classOf(unit)
    if className then
        if settings.hideClass then
            -- Clients that name the class in this line: "Level 80 Human Warrior (Player)".
            changed = unitTooltip.ReplaceWord(changed, " " .. className, "") or changed
        elseif settings.classColorClass then
            changed = unitTooltip.ReplaceWord(changed, className, classColor:WrapTextInColorCode(className)) or changed
        end
    end
    local race = UnitRace(unit)
    if settings.raceReactionColor and race and not anySecret(race) then
        changed = unitTooltip.ReplaceWord(changed, race, inReactionColor(unit, race)) or changed
    end
    return changed ~= text and changed or nil
end

-- Font strings are changed after their line was added; Blizzard's line data stays untouched.
---@param tooltip GameTooltip
---@param lineData table
function feature:OnLinePost(tooltip, lineData)
    local unit = playerOf(tooltip)
    local left = unit and unitTooltip.LeftLine(tooltip, lineData)
    if not left then
        return
    end
    local settings = self:Settings()
    local text = unitTooltip.Readable(left:GetText())
    local className, classColor = classOf(unit)
    local guildName, rankName, rankIndex = guildOf(unit)
    local shownGuild = text and guildName and guildLineName(text, guildName)

    if unitTooltip.IsNameLine(lineData) then
        if settings.classColorName and classColor then
            left:SetTextColor(classColor:GetRGB())
        end
    elseif shownGuild then
        -- The guild line; checked before the level line, as a guild name may have a number in it.
        if settings.guildLine then
            left:SetText(guildLine(unit, shownGuild, rankName, rankIndex, settings))
        end
    elseif text and className and text == className then
        -- The class line, when it is kept.
        if settings.classColorClass then
            left:SetTextColor(classColor:GetRGB())
        end
    elseif text and not levelDone[tooltip] and unitTooltip.HasLevel(text) then
        levelDone[tooltip] = true
        local changed
        if settings.shortLevel then
            changed = shortLevelLine(unit, text, settings)
        else
            changed = adjustLevelLine(unit, text, settings)
        end
        if changed then
            left:SetText(changed)
        end
    end
end
