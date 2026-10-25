---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds details about an item to its tooltip: how many of it fit in one stack.
local feature = app.features:NewFeature("ItemDetails")

local STACK_SIZE_LABEL = L["Stack Size"]

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Item, "OnItemTooltip")
end

-- The stack size is nil until the client has the item's data; the tooltip is filled again then.
function feature:OnItemTooltip(tooltip, tooltipData)
    local id = tooltipData.id
    if not id or anySecret(id) or not self:Settings().stackSize then
        return
    end
    local stackSize = C_Item.GetItemMaxStackSizeByID(id)
    if stackSize and not anySecret(stackSize) and stackSize > 1 then
        lines.AddValue(tooltip, STACK_SIZE_LABEL, stackSize)
    end
end
