---@type string, SeamlessTooltip
local _, app = ...

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds who cast a buff or debuff to its tooltip, the name in the caster's class color.
local feature = app.features:NewFeature("AuraSource", {
    category = "spells",
    name = "Aura caster",
    desc = "Adds who cast a buff or debuff to its tooltip. Players are shown in their class color.",
    order = 20,
})

-- How an aura tooltip was filled (its processing info's getterName) and how to look the aura up
-- from the same (unit, index or auraInstanceID, filter) arguments.
local GETTERS = {
    GetUnitAura = C_UnitAuras.GetAuraDataByIndex,
    GetUnitBuff = C_UnitAuras.GetBuffDataByIndex,
    GetUnitDebuff = C_UnitAuras.GetDebuffDataByIndex,
    GetUnitAuraByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID,
    GetUnitBuffByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID,
    GetUnitDebuffByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID,
}

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.UnitAura, "OnAuraTooltip")
    self:AddLinePreCall(Enum.TooltipDataLineType.AuraCaster, "OnGameCasterLine")
end

-- The caster of the aura whose tooltip is being processed: name and color (class color for
-- players, nil = white). Nil when it can't be read: aura lookups can error while aura access
-- is restricted, even when their arguments are not secret.
---@param tooltip GameTooltip
---@return string? name
---@return ColorMixin? color
local function sourceOf(tooltip)
    local info = tooltip.GetProcessingTooltipInfo and tooltip:GetProcessingTooltipInfo()
    local getAura = info and GETTERS[info.getterName]
    local args = info and info.getterArgs
    if not getAura or not args then
        return
    end
    local unit, indexOrID, filter = args[1], args[2], args[3]
    if anySecret(unit, indexOrID, filter) or not unit or not indexOrID then
        return
    end
    local ok, aura = pcall(getAura, unit, indexOrID, filter)
    if not ok or anySecret(aura) or not aura then
        return
    end
    local source = aura.sourceUnit
    if anySecret(source) or not source then
        return
    end
    -- First name and surname, as the game shows them.
    local name = app.unitTooltip.DisplayName(source)
    if not name then
        return
    end

    local isPlayer = UnitIsPlayer(source)
    if not anySecret(isPlayer) and isPlayer then
        local _, classFile = UnitClass(source)
        if not anySecret(classFile) and classFile then
            return name, C_ClassColor.GetClassColor(classFile)
        end
    end
    return name
end

-- The game's caster line (its setting tooltipShowAuraCasterNames, in the Spells tab; line type
-- AuraCaster) gives way to ours, but only where ours can be shown (in combat it may be the only
-- one).
---@param tooltip GameTooltip
---@return boolean? consumed
function feature:OnGameCasterLine(tooltip)
    if sourceOf(tooltip) then
        return true
    end
end

---@param tooltip GameTooltip
function feature:OnAuraTooltip(tooltip)
    local name, color = sourceOf(tooltip)
    if name then
        lines.AddValue(tooltip, "Source:", name, color)
    end
end
