---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local unitTooltip = app.unitTooltip

-- Adds a player's state behind the name: <AFK>, <DND>, <Offline>, <Dead>, <Ghost>, <PvP>; the
-- game's own "PvP" line can go.
local feature = app.features:NewFeature("StatusTags", {
    category = "units",
    name = L["Status tags"],
    desc = L["Adds a player's state behind the name, e.g. <AFK> or <Dead>."],
    order = 22,
    options = {
        afk = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["<AFK> and <DND>"],
        },
        offline = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["<Offline>"],
        },
        dead = {
            type = "toggle",
            order = 30,
            width = "full",
            name = L["<Dead> and <Ghost>"],
        },
        pvp = {
            type = "toggle",
            order = 40,
            width = "full",
            name = L["<PvP>"],
            desc = L["For players flagged for PvP."],
        },
        hidePvpLine = {
            type = "toggle",
            order = 50,
            width = "full",
            name = L['Hide the "PvP" line'],
            desc = L["The line the game adds for players flagged for PvP."],
        },
    },
})

local TAG_COLOR = CreateColor(0.65, 0.65, 0.65)
local AFK = L["<AFK>"]
local DND = L["<DND>"]
local OFFLINE = L["<Offline>"]
local DEAD_TAG = L["<Dead>"]
local GHOST = L["<Ghost>"]
local PVP_TAG = L["<PvP>"]

function feature:OnInitialize()
    self:AddLinePreCall(TooltipDataProcessor.AllTypes, "OnLinePre")
    self:AddLinePostCall(Enum.TooltipDataLineType.UnitName, "OnNameLine")
end

-- True when a unit API answered true (and not in secret).
---@param result any
---@return boolean
local function yes(result)
    return not anySecret(result) and result == true
end

-- The tags that apply to the player, in the tag color (dead ones in red).
---@param unit string
---@param text string the name line, so tags the game already shows aren't doubled
---@param settings table
---@return string[]
local function tagsOf(unit, text, settings)
    local tags = {}
    local function add(tag, color)
        if not text:find(tag, 1, true) then
            tags[#tags + 1] = (color or TAG_COLOR):WrapTextInColorCode(tag)
        end
    end
    local connected = UnitIsConnected(unit)
    if settings.offline and not anySecret(connected) and connected == false then
        add(OFFLINE)
    end
    if settings.afk then
        if yes(UnitIsAFK(unit)) then
            add(AFK)
        elseif yes(UnitIsDND(unit)) then
            add(DND)
        end
    end
    if settings.dead then
        if yes(UnitIsGhost(unit)) then
            add(GHOST, RED_FONT_COLOR)
        elseif yes(UnitIsDead(unit)) then
            add(DEAD_TAG, RED_FONT_COLOR)
        end
    end
    if settings.pvp and (yes(UnitIsPVP(unit)) or yes(UnitIsPVPFreeForAll(unit))) then
        add(PVP_TAG)
    end
    return tags
end

-- The game's "PvP" line of player tooltips.
---@param tooltip GameTooltip
---@param lineData table
---@return boolean? consumed true drops the line
function feature:OnLinePre(tooltip, lineData)
    local _, isPlayer = unitTooltip.Unit(tooltip)
    if isPlayer and self:Settings().hidePvpLine and PVP then
        return unitTooltip.Readable(lineData.leftText) == PVP and not lineData.rightText
    end
end

---@param tooltip GameTooltip
---@param lineData table
function feature:OnNameLine(tooltip, lineData)
    local unit, isPlayer = unitTooltip.Unit(tooltip)
    local left = isPlayer and unitTooltip.LeftLine(tooltip, lineData)
    local text = left and unitTooltip.Readable(left:GetText())
    if not text then
        return
    end
    local tags = tagsOf(unit, text, self:Settings())
    if #tags > 0 then
        left:SetText(text .. " " .. table.concat(tags, " "))
    end
end
