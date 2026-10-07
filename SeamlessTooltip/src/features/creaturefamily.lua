---@type string, SeamlessTooltip
local _, app = ...

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds a creature's family (Wolf, Cat, Spider, ...) to its tooltip; handy for hunters looking for a
-- pet.
local feature = app.features:NewFeature("CreatureFamily", {
    category = "units",
    name = "Creature family",
    desc = "Adds a beast's family (Wolf, Cat, Spider, ...) to its tooltip.",
    order = 27,
    enabled = false,
})

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Unit, "OnUnitTooltip")
end

---@param tooltip GameTooltip
function feature:OnUnitTooltip(tooltip)
    local unit, isPlayer = app.unitTooltip.Unit(tooltip)
    if not unit or isPlayer then
        return
    end
    local family = UnitCreatureFamily(unit)
    if family and not anySecret(family) then
        lines.AddValue(tooltip, "Family", family)
    end
end
