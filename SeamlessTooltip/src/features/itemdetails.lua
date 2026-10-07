---@type string, SeamlessTooltip
local _, app = ...

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds details about an item to its tooltip: how many of it fit in one stack.
local feature = app.features:NewFeature("ItemDetails", {
    category = "items",
    name = "Item details",
    desc = "Adds details about an item to its tooltip.",
    order = 20,
    defaults = {
        stackSize = false,
    },
    options = {
        stackSize = {
            type = "toggle",
            order = 10,
            width = "full",
            name = "Stack size",
            desc = "How many of the item fit in one stack; only for items that stack.",
        },
    },
})

local STACK_SIZE_LABEL = AUCTION_STACK_SIZE or "Stack Size"

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
