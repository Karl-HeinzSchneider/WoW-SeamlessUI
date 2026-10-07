---@type string, SeamlessTooltip
local _, app = ...

local anySecret = app.features.AnySecret

-- Colors the border of item tooltips in the item's quality color (green, blue, purple, ...).
local feature = app.features:NewFeature("QualityBorder", {
    category = "items",
    name = "Quality border",
    desc = "Colors the border of item tooltips in the item's quality color. Works with the game's border "
        .. 'and with "Border and background".',
    order = 30,
    defaults = {
        minQuality = 2,
    },
    options = {
        minQuality = {
            type = "select",
            order = 10,
            name = "From quality",
            desc = "Items of a lower quality keep the normal border.",
            -- Filled below from the game's quality names and colors.
            values = {},
            sorting = {},
        },
    },
})

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
