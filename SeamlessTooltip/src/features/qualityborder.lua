---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret

-- Colors the border of item tooltips in the item's quality color (green, blue, purple, ...).
local feature = app.features:NewFeature("QualityBorder")

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Item, "OnItemTooltip")
end

---@param tooltip GameTooltip
---@param tooltipData table
function feature:OnItemTooltip(tooltip, tooltipData)
    local link = app.features.ItemLink(tooltipData)
    if not link then
        return
    end
    local quality = C_Item.GetItemQualityByID(link)
    if not quality or anySecret(quality) or quality < self:Settings().minQuality then
        return
    end
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if r then
        app.border.Paint(tooltip, r, g, b)
    end
end
