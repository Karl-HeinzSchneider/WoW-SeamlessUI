---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local lines = app.lines

-- Lists the members of your group or raid that target the unit: "Targeted by (2)  Name, Name".
local feature = app.features:NewFeature("TargetedBy", {
    category = "units",
    name = L["Targeted by"],
    desc = L["Lists the members of your group or raid that target the unit."],
    order = 26,
    defaults = {
        names = true,
        you = true,
    },
    options = {
        names = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Names"],
            desc = L["Lists who targets the unit, in class color; off shows only how many."],
        },
        you = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["Count yourself"],
        },
    },
})

local LABEL = L["Targeted by"]
-- More names than this are cut off with "...".
local MAX_NAMES = 6

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Unit, "OnUnitTooltip")
end

-- The unit tokens of the group: raid1..n (which include the player) in a raid, else the player
-- and party1..4.
---@return string[]
local function groupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    else
        units[1] = "player"
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end

-- A member's name in class color.
---@param member string
---@return string?
local function coloredName(member)
    local name = app.unitTooltip.DisplayName(member)
    local _, classFile = UnitClass(member)
    if name and classFile and not anySecret(classFile) then
        return C_ClassColor.GetClassColor(classFile):WrapTextInColorCode(name)
    end
    return name
end

---@param tooltip GameTooltip
function feature:OnUnitTooltip(tooltip)
    if not IsInGroup() then
        return
    end
    local unit = app.unitTooltip.Unit(tooltip)
    if not unit then
        return
    end
    local settings = self:Settings()
    local names, count = {}, 0
    for _, member in ipairs(groupUnits()) do
        local isUnit = UnitIsUnit(member .. "target", unit)
        local isYou = UnitIsUnit(member, "player")
        if not anySecret(isUnit, isYou) and isUnit and (settings.you or not isYou) then
            count = count + 1
            local name = #names < MAX_NAMES and coloredName(member)
            if name then
                names[#names + 1] = name
            end
        end
    end
    if count == 0 then
        return
    end
    if not settings.names then
        lines.AddValue(tooltip, LABEL, count)
        return
    end
    -- Names that are cut off or can't be read (secret) show as "...".
    if count > #names then
        names[#names + 1] = "..."
    end
    local label = NORMAL_FONT_COLOR:WrapTextInColorCode((L["%s (%d):"]):format(LABEL, count))
    tooltip:AddLine(label .. " " .. table.concat(names, ", "), 1, 1, 1, true)
end
