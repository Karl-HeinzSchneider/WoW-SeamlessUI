---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds the item ID, and its icon's file ID, to item tooltips.
local feature = app.features:NewFeature("ItemIDs", {
    category = "items",
    name = L["Item IDs"],
    desc = L["Adds the item's ID, and its icon's ID, to item tooltips."],
    order = 10,
    defaults = {
        item = true,
        icon = false,
    },
    options = {
        item = {
            type = "toggle",
            order = 10,
            name = L["Item ID"],
        },
        icon = {
            type = "toggle",
            order = 20,
            name = L["Icon ID"],
            desc = L["The file ID of the item's icon."],
        },
    },
})

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
