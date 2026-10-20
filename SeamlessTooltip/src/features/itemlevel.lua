---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local lines = app.lines

-- Adds the item level to the tooltips of weapons and armor, unless the game shows it already.
local feature = app.features:NewFeature("ItemLevel", {
    category = "items",
    name = L["Item level"],
    desc = L["Adds the item level to weapons and armor."],
    order = 15,
    defaults = {
        qualityColor = true,
    },
    options = {
        qualityColor = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["In quality color"],
            desc = L["Shows the item level in the color of the item's quality (green, blue, purple, ...)."],
        },
    },
})

local LABEL = L["Item Level"]

-- Per tooltip whose lines are being processed: whether the game added an item level line itself.
---@type table<GameTooltip, boolean>
local hasGameLine = {}

function feature:OnInitialize()
    self:AddLinePreCall(Enum.TooltipDataLineType.ItemLevel, "OnItemLevelLine")
    self:AddTooltipPostCall(Enum.TooltipDataType.Item, "OnItemTooltip")
end

---@param tooltip GameTooltip
function feature:OnItemLevelLine(tooltip)
    hasGameLine[tooltip] = true
end

---@param tooltip GameTooltip
---@param tooltipData table
function feature:OnItemTooltip(tooltip, tooltipData)
    local gameLine = hasGameLine[tooltip]
    hasGameLine[tooltip] = nil
    local link = app.features.ItemLink(tooltipData)
    if gameLine or not link then
        return
    end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
    if classID ~= Enum.ItemClass.Weapon and classID ~= Enum.ItemClass.Armor then
        return
    end
    -- The level of this very item (upgrades, scaling), nil until the client has its data.
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if not level or anySecret(level) or level <= 0 then
        return
    end
    local color
    local quality = C_Item.GetItemQualityByID(link)
    if self:Settings().qualityColor and quality and not anySecret(quality) then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        color = r and CreateColor(r, g, b)
    end
    lines.AddValue(tooltip, LABEL, level, color)
end
