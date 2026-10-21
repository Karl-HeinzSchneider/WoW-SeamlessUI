---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local lines = app.lines

-- Shows what an item sells for at a vendor, for the whole stack and for one item, in place of the
-- game's own sell price line (and where the game shows none).
local feature = app.features:NewFeature("VendorPrice", {
    category = "items",
    name = L["Vendor price"],
    desc = L["Shows what an item sells for at a vendor; for a stack, also what one of it sells for."],
    order = 25,
    options = {
        perItem = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Price per item"],
            desc = L['Adds the price of one item behind a stack\'s price ("1s 20c (6c each)").'],
        },
    },
})

local LABEL = L["Sell Price"]

-- Per tooltip whose lines are being processed: the stack's price from the game's sell price line
-- when it was dropped for ours, false when the game's line stays.
---@type table<GameTooltip, number|false>
local gamePrices = {}

function feature:OnInitialize()
    self:AddLinePreCall(Enum.TooltipDataLineType.SellPrice, "OnSellPriceLine")
    self:AddTooltipPostCall(Enum.TooltipDataType.Item, "OnItemTooltip")
end

-- What one of the item sells for; nil until the client has the item's data.
---@param item number|string an item ID or link
---@return number?
local function sellPriceOf(item)
    local sellPrice = select(11, C_Item.GetItemInfo(item))
    if sellPrice and not anySecret(sellPrice) then
        return sellPrice
    end
end

---@param copper number
---@return string
local function money(copper)
    if MoneyFormatterUtil and GameTooltipMoneyFormat then
        return MoneyFormatterUtil.FormatMoney(copper, GameTooltipMoneyFormat)
    end
    return C_CurrencyInfo.GetCoinTextureString(copper)
end

-- The game's line is dropped where ours can take its place: a single price (no min/max range) for
-- an item whose own price is known.
---@param tooltip GameTooltip
---@param lineData table
---@return boolean? consumed true drops the line
function feature:OnSellPriceLine(tooltip, lineData)
    gamePrices[tooltip] = false
    local price, maxPrice = lineData.price, lineData.maxPrice
    if not price or anySecret(price, maxPrice) or (maxPrice and maxPrice > 0) then
        return
    end
    local info = tooltip:GetProcessingTooltipInfo()
    local id = info and info.tooltipData and info.tooltipData.id
    if id and not anySecret(id) and sellPriceOf(id) then
        gamePrices[tooltip] = price
        return true
    end
end

-- How many items the tooltip is about: the game's stack price over one item's price, else the
-- count of a bag slot's stack.
---@param tooltip GameTooltip
---@param gamePrice number?
---@param sellPrice number
---@return integer
local function countOf(tooltip, gamePrice, sellPrice)
    if gamePrice then
        return math.max(1, math.floor(gamePrice / sellPrice + 0.5))
    end
    local owner = tooltip:GetOwner()
    local count = owner and owner.GetBagID and owner.count
    return type(count) == "number" and count > 1 and count or 1
end

---@param tooltip GameTooltip
---@param tooltipData table
function feature:OnItemTooltip(tooltip, tooltipData)
    local gamePrice = gamePrices[tooltip]
    gamePrices[tooltip] = nil
    local id = tooltipData.id
    -- The game's line stays (a price range), or a comparison tooltip beside an item, which leaves
    -- the price out like the game does.
    if gamePrice == false or not id or anySecret(id) or tooltip.isShopping then
        return
    end
    local sellPrice = sellPriceOf(id)
    if not sellPrice or sellPrice <= 0 then
        return
    end
    local count = countOf(tooltip, gamePrice, sellPrice)
    local text = money(sellPrice * count)
    if count > 1 and self:Settings().perItem then
        text = text .. GRAY_FONT_COLOR:WrapTextInColorCode((L[" (%s each)"]):format(money(sellPrice)))
    end
    lines.AddValue(tooltip, LABEL, text)
end
