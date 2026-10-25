---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret

-- Colors the border of item tooltips in the item's quality color (green, blue, purple, ...).
local feature = app.features:NewFeature("QualityBorder")

-- Poor (grey) up to Heirloom; the select shows each in its own color.
local qualityOption = feature.info.options.minQuality
for quality = 0, 7 do
    local r, g, b = C_Item.GetItemQualityColor(quality)
    local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if r and name then
        qualityOption.values[quality] = CreateColor(r, g, b):WrapTextInColorCode(name)
        qualityOption.sorting[#qualityOption.sorting + 1] = quality
    end
end

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
