---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local unitTooltip = app.unitTooltip

-- Puts the unit's raid target marker (skull, cross, ...) in front of its name, kept up to date
-- while the tooltip is shown.
local feature = app.features:NewFeature("RaidIcon", {
    category = "units",
    name = L["Raid target icon"],
    desc = L["Shows the unit's raid target marker (skull, cross, ...) in front of its name."],
    order = 23,
})

-- GetRaidTargetIndex returns a secret to addon code, so the marker can't be named in the text.
-- Like Blizzard's target frame, a texture shows it: the secret goes straight to SetSpriteSheetCell.
-- A transparent inline texture in front of the name keeps the room it sits on.
local SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local SHEET_ROWS, SHEET_COLUMNS = 4, 4
local ICON_SIZE = 16
local SPACER = ("|TInterface\\Common\\spacer:%d:%d|t "):format(ICON_SIZE, ICON_SIZE)

-- Per tooltip: the marker texture, created on first use.
---@type table<GameTooltip, Texture>
local icons = {}

-- The name line of the unit GameTooltip shows, and whether it has room for a marker.
---@type { unit: string, left: FontString, marked: boolean }?
local shown

function feature:OnInitialize()
    self:AddLinePostCall(Enum.TooltipDataLineType.UnitName, "OnNameLine")
end

function feature:OnEnable()
    self:RegisterEvent("RAID_TARGET_UPDATE", "OnRaidTargetUpdate")
end

function feature:OnDisable()
    shown = nil
    for _, icon in pairs(icons) do
        icon:Hide()
    end
end

-- The unit's marker index (maybe secret), nil without one. Nil is never secret, so a secret return
-- means the unit has a marker.
---@param unit string
---@return any index
---@return boolean marked
local function markerOf(unit)
    local index = GetRaidTargetIndex(unit)
    return index, anySecret(index) or index ~= nil
end

-- The tooltip's marker texture; it goes away when the tooltip is cleared or hidden.
---@param tooltip GameTooltip
---@return Texture
local function iconOf(tooltip)
    local icon = icons[tooltip]
    if not icon then
        icon = tooltip:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(SHEET)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:Hide()
        local hide = function()
            icon:Hide()
        end
        tooltip:HookScript("OnTooltipCleared", hide)
        tooltip:HookScript("OnHide", hide)
        icons[tooltip] = icon
    end
    return icon
end

-- Shows the marker over the spacer at the start of the name line.
---@param tooltip GameTooltip
---@param left FontString
---@param index any
local function showIcon(tooltip, left, index)
    local icon = iconOf(tooltip)
    icon:SetSpriteSheetCell(index, SHEET_ROWS, SHEET_COLUMNS)
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", left, "LEFT")
    icon:Show()
end

---@param tooltip GameTooltip
---@param lineData table
function feature:OnNameLine(tooltip, lineData)
    local unit = unitTooltip.Unit(tooltip)
    local left = unit and unitTooltip.LeftLine(tooltip, lineData)
    local text = left and unitTooltip.Readable(left:GetText())
    if not text then
        return
    end
    local index, marked = markerOf(unit)
    if marked then
        left:SetText(SPACER .. text)
        showIcon(tooltip, left, index)
    end
    if tooltip == GameTooltip then
        shown = { unit = unit, left = left, marked = marked }
    end
end

-- A marker set, changed or removed while the tooltip is shown.
function feature:OnRaidTargetUpdate()
    if not shown or not GameTooltip:IsShown() then
        return
    end
    local _, unit = GameTooltip:GetUnit()
    if not unit or anySecret(unit) or unit ~= shown.unit then
        return
    end
    local text = unitTooltip.Readable(shown.left:GetText())
    if not text then
        return
    end
    local index, marked = markerOf(unit)
    if marked then
        if not shown.marked then
            shown.left:SetText(SPACER .. text)
        end
        showIcon(GameTooltip, shown.left, index)
    elseif shown.marked then
        if text:sub(1, #SPACER) == SPACER then
            shown.left:SetText(text:sub(#SPACER + 1))
        end
        iconOf(GameTooltip):Hide()
    end
    shown.marked = marked
    GameTooltip:Show()
end
