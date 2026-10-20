---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds the spell ID, and its icon's file ID, to spell and aura (buff/debuff) tooltips.
local feature = app.features:NewFeature("SpellIDs", {
    category = "spells",
    name = L["Spell IDs"],
    desc = L["Adds the spell's ID, and its icon's ID, to spell tooltips and to buffs and debuffs."],
    order = 10,
    defaults = {
        spell = true,
        icon = false,
    },
    options = {
        spell = {
            type = "toggle",
            order = 10,
            name = L["Spell ID"],
        },
        icon = {
            type = "toggle",
            order = 20,
            name = L["Icon ID"],
            desc = L["The file ID of the spell's icon."],
        },
    },
})

-- Buffs and debuffs are a tooltip type of their own; their data's id is the aura's spell ID too.
-- Aura data is secret while auras are restricted (in combat); no line then.
function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Spell, "OnSpellTooltip")
    self:AddTooltipPostCall(Enum.TooltipDataType.UnitAura, "OnSpellTooltip")
    self:AddLinePreCall(TooltipDataProcessor.AllTypes, "OnLinePre")
end

-- The spell ID of the aura tooltip being processed, if addon code may read it.
---@param tooltip GameTooltip
---@return number?
local function auraSpellID(tooltip)
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    local data = info and info.tooltipData
    if data and data.type == Enum.TooltipDataType.UnitAura and data.id ~= nil and not anySecret(data.id) then
        return data.id
    end
end

-- The game's spell ID line (its setting tooltipShowAuraSpellIDs, in the Spells tab) gives way to ours:
-- the second line of an aura tooltip whose only number is the aura's spell ID ("Spell ID: 687" in
-- any language). Only while ours is shown.
---@param tooltip GameTooltip
---@param lineData table
---@return boolean? consumed
function feature:OnLinePre(tooltip, lineData)
    if not self:Settings().spell or tooltip:NumLines() ~= 1 or lineData.rightText then
        return
    end
    local id = auraSpellID(tooltip)
    local text = lineData.leftText
    if not id or type(text) ~= "string" or anySecret(text) then
        return
    end
    if text:gsub("%D", "") == tostring(id) and text:find(tostring(id), 1, true) then
        -- Exactly one run of digits, and it is the ID.
        local _, runs = text:gsub("%d+", "")
        if runs == 1 then
            return true
        end
    end
end

function feature:OnSpellTooltip(tooltip, tooltipData)
    local id = tooltipData.id
    if id == nil or anySecret(id) then
        return
    end
    local settings = self:Settings()
    if settings.spell then
        lines.AddValue(tooltip, L["Spell ID"], id)
    end
    if settings.icon then
        local icon = C_Spell.GetSpellTexture(id)
        if icon and not anySecret(icon) then
            lines.AddValue(tooltip, L["Icon ID"], icon)
        end
    end
end
