---@type string, SeamlessTooltip
local _, app = ...

local anySecret = app.features.AnySecret
local unitTooltip = app.unitTooltip

-- Greys out the name of a mob another player has tapped, like the game greys its unit frame.
local feature = app.features:NewFeature("TappedName", {
    category = "units",
    name = "Tapped mobs",
    desc = "Shows the name of a mob another player has tapped (no loot or experience for you) in grey.",
    order = 24,
})

function feature:OnInitialize()
    self:AddLinePostCall(Enum.TooltipDataLineType.UnitName, "OnNameLine")
end

---@param tooltip GameTooltip
---@param lineData table
function feature:OnNameLine(tooltip, lineData)
    local unit, isPlayer = unitTooltip.Unit(tooltip)
    if not unit or isPlayer then
        return
    end
    local tapDenied = UnitIsTapDenied(unit)
    local left = not anySecret(tapDenied) and tapDenied and unitTooltip.LeftLine(tooltip, lineData)
    if left then
        left:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end
end
