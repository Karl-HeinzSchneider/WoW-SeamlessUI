---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret

-- Colors the border of unit tooltips: players in their class color, NPCs in their hostile/friendly
-- color, mobs another player has tapped in grey.
local feature = app.features:NewFeature("UnitBorder", {
    category = "units",
    name = L["Border color"],
    desc = L['Colors the border of unit tooltips by the unit. Works with the game\'s border and with "Border and background".'],
    order = 35,
    options = {
        players = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Players in class color"],
        },
        npcs = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["NPCs in reaction color"],
            desc = L["Hostile red, neutral yellow, friendly green."],
        },
        tapped = {
            type = "toggle",
            order = 30,
            width = "full",
            name = L["Tapped mobs in grey"],
            desc = L["Mobs another player has tapped, which give you no loot or experience."],
        },
    },
})

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Unit, "OnUnitTooltip")
end

-- The unit's border color under the settings, nil for the game's.
---@param unit string
---@param settings table
---@return number? r
---@return number? g
---@return number? b
local function unitColor(unit, settings)
    local isPlayer = UnitIsPlayer(unit)
    if anySecret(isPlayer) then
        return
    end
    if isPlayer then
        local _, classFile = UnitClass(unit)
        if settings.players and classFile and not anySecret(classFile) then
            return C_ClassColor.GetClassColor(classFile):GetRGB()
        end
        return
    end
    if settings.tapped then
        local tapDenied = UnitIsTapDenied(unit)
        if anySecret(tapDenied) then
            return
        end
        if tapDenied then
            return GRAY_FONT_COLOR:GetRGB()
        end
    end
    if settings.npcs then
        return app.unitTooltip.UnitColor(unit)
    end
end

---@param tooltip GameTooltip
function feature:OnUnitTooltip(tooltip)
    local unit = app.unitTooltip.Unit(tooltip)
    if not unit then
        return
    end
    local r, g, b = unitColor(unit, self:Settings())
    if r then
        app.border.Paint(tooltip, r, g, b)
    end
end
