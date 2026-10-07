---@type string, SeamlessTooltip
local _, app = ...

local anySecret = app.features.AnySecret
local unitTooltip = app.unitTooltip

-- Changes the text lines of NPC tooltips: a short level line ("10 Beast (Elite)") with the level in
-- its difficulty color and the creature type moved into it, the faction left out.
local feature = app.features:NewFeature("NpcText", {
    category = "units",
    name = "NPC text",
    desc = "Changes the text of NPC tooltips.",
    order = 20,
    defaults = {
        shortLevel = true,
        faction = "SHOW",
    },
    options = {
        shortLevel = {
            type = "toggle",
            order = 10,
            width = "full",
            name = "Short level line",
            desc = 'Shows "Level 10 (Elite)" and the creature type line ("Beast") as "10 Beast (Elite)", the '
                .. "level in its difficulty color.",
        },
        faction = unitTooltip.FactionOption(20),
    },
})

-- Per tooltip whose lines are being processed: whether its level line was handled yet, its pieces,
-- and the creature type taken from its own line. The type line may come before or after the level
-- line; whichever comes last puts the short line together.
---@class SeamlessTooltip.NpcTextState
---@field levelDone boolean
---@field level { left: FontString, head: string, level: string, tail: string }?
---@field creatureType string?

---@type table<GameTooltip, SeamlessTooltip.NpcTextState>
local states = {}

-- Line callbacks for every line type; only lines of NPC tooltips are changed.
function feature:OnInitialize()
    self:AddLinePreCall(TooltipDataProcessor.AllTypes, "OnLinePre")
    self:AddLinePostCall(TooltipDataProcessor.AllTypes, "OnLinePost")
end

-- The NPC whose tooltip lines are being processed.
---@param tooltip GameTooltip
---@return string?
local function npcOf(tooltip)
    local unit, isPlayer = unitTooltip.Unit(tooltip)
    return not isPlayer and unit or nil
end

-- The unit's localized creature type ("Beast", "Humanoid").
---@param unit string
---@return string?
local function creatureTypeOf(unit)
    local creatureType = UnitCreatureType(unit)
    if creatureType and not anySecret(creatureType) then
        return creatureType
    end
end

-- "10 Beast (Elite)" from the level line's pieces and the creature type, once both are known.
---@param state SeamlessTooltip.NpcTextState
local function compose(state)
    local line = state.level
    if line then
        local creatureType = state.creatureType and (" " .. state.creatureType) or ""
        line.left:SetText(line.head .. line.level .. creatureType .. line.tail)
    end
end

---@param tooltip GameTooltip
---@param lineData table
---@return boolean? consumed true drops the line
function feature:OnLinePre(tooltip, lineData)
    local unit = npcOf(tooltip)
    if not unit then
        return
    end
    if unitTooltip.IsNameLine(lineData) then
        states[tooltip] = { levelDone = false }
        return
    end
    local text = unitTooltip.Readable(lineData.leftText)
    local state = states[tooltip]
    if not text or not state or lineData.rightText then
        return
    end
    local settings = self:Settings()
    local dropFaction = unitTooltip.DropFactionLine(text, settings.faction)
    if dropFaction ~= nil then
        return dropFaction
    end
    -- The creature type line of enemy NPCs: moved into the short level line.
    if settings.shortLevel and text == creatureTypeOf(unit) then
        state.creatureType = text
        compose(state)
        return true
    end
end

-- The level line becomes the short line; the font string is changed after it was added.
---@param tooltip GameTooltip
---@param lineData table
function feature:OnLinePost(tooltip, lineData)
    local state = npcOf(tooltip) and states[tooltip]
    local left = state and unitTooltip.LeftLine(tooltip, lineData)
    if not left or state.levelDone or unitTooltip.IsNameLine(lineData) then
        return
    end
    local text = unitTooltip.Readable(left:GetText())
    if text and unitTooltip.HasLevel(text) then
        state.levelDone = true
        local head, level, tail = unitTooltip.LevelParts(text)
        if self:Settings().shortLevel and head then
            state.level = { left = left, head = head, level = level, tail = tail }
            compose(state)
        end
    end
end
