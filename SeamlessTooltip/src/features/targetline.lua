---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret

-- Adds the unit's target to unit tooltips: "T: Name", the name in class or hostile/friendly color,
-- ">>YOU<<" when it targets you. Kept up to date while the tooltip is shown.
local feature = app.features:NewFeature("TargetLine", {
    category = "units",
    name = L["Target"],
    desc = L['Adds what the unit is targeting as "T: Name" to its tooltip.'],
    order = 25,
    options = {
        you = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L[">>YOU<< for you"],
            desc = L['Shows "T: >>YOU<<" when the unit targets you.'],
        },
    },
})

local LABEL = NORMAL_FONT_COLOR:WrapTextInColorCode(L["T:"])
local YOU_COLOR = CreateColor(1, 0.25, 0.25)
local NO_TARGET = GRAY_FONT_COLOR:WrapTextInColorCode("-")
-- How often the shown line is checked for a new target, in seconds.
local UPDATE_INTERVAL = 0.05

-- The target line of the unit GameTooltip shows: the unit, the line's number (nil until the unit
-- had a target) and its text.
---@type { unit: string, line: integer?, text: string? }?
local shown
local elapsedSinceUpdate = 0

function feature:OnInitialize()
    self:AddTooltipPostCall(Enum.TooltipDataType.Unit, "OnUnitTooltip")
end

-- Hooks drop when the feature is switched off (AceHook).
function feature:OnEnable()
    self:SecureHookScript(GameTooltip, "OnUpdate", "OnTooltipUpdate")
    self:SecureHookScript(GameTooltip, "OnHide", "OnTooltipHide")
end

function feature:OnDisable()
    shown = nil
end

-- "T: Name" for `unit`'s target, nil without one. Nil too when the game keeps the target secret
-- (names and unit comparisons in restricted content).
---@param unit string
---@return string?
function feature:TargetText(unit)
    local target = unit .. "target"
    local exists = UnitExists(target)
    if anySecret(exists) or not exists then
        return
    end
    local isYou = UnitIsUnit(target, "player")
    if anySecret(isYou) then
        return
    end
    if isYou and self:Settings().you then
        return LABEL .. " " .. YOU_COLOR:WrapTextInColorCode(L[">>YOU<<"])
    end

    -- First name and surname, as the game shows them.
    local name = app.unitTooltip.DisplayName(target)
    if not name then
        return
    end
    local color
    local isPlayer = UnitIsPlayer(target)
    if not anySecret(isPlayer) and isPlayer then
        local _, classFile = UnitClass(target)
        if classFile and not anySecret(classFile) then
            color = C_ClassColor.GetClassColor(classFile)
        end
    end
    if not color then
        local r, g, b = app.unitTooltip.UnitColor(target)
        if r then
            color = CreateColor(r, g, b)
        end
    end
    return LABEL .. " " .. (color and color:WrapTextInColorCode(name) or name)
end

-- The tooltip shows itself after the post-calls, so the added line is laid out with the rest.
---@param tooltip GameTooltip
function feature:OnUnitTooltip(tooltip)
    if tooltip ~= GameTooltip then
        return
    end
    local _, unit = tooltip:GetUnit()
    if not unit or anySecret(unit) then
        shown = nil
        return
    end
    local text = self:TargetText(unit)
    shown = { unit = unit, text = text }
    if text then
        tooltip:AddLine(text)
        shown.line = tooltip:NumLines()
    end
end

-- Units in the world keep their tooltip while hovered, so a new target is written into the line
-- (or added as one); "T: -" once the target is gone.
function feature:OnTooltipUpdate(tooltip, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if not shown or elapsedSinceUpdate < UPDATE_INTERVAL then
        return
    end
    elapsedSinceUpdate = 0

    local _, unit = tooltip:GetUnit()
    if not unit or anySecret(unit) or unit ~= shown.unit then
        return
    end
    local text = self:TargetText(unit)
    if text == shown.text then
        return
    end
    shown.text = text
    if shown.line then
        local left = _G["GameTooltipTextLeft" .. shown.line]
        if left then
            left:SetText(text or (LABEL .. " " .. NO_TARGET))
        end
    elseif text then
        tooltip:AddLine(text)
        shown.line = tooltip:NumLines()
    end
    tooltip:Show()
end

function feature:OnTooltipHide()
    shown = nil
end
