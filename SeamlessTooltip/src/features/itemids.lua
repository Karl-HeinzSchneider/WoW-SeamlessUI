---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds the item ID, and its icon's file ID, to item tooltips.
local feature = app.features:NewFeature("ItemIDs")

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Item, "OnItemTooltip")
end

function feature:OnItemTooltip(tooltip, tooltipData)
    local id = tooltipData.id
    if id == nil or anySecret(id) then
        return
    end
    local settings = self:Settings()
    if settings.item then
        lines.AddValue(tooltip, L["Item ID"], id)
    end
    if settings.icon then
        local icon = C_Item.GetItemIconByID(id)
        if icon and not anySecret(icon) then
            lines.AddValue(tooltip, L["Icon ID"], icon)
        end
    end
end
