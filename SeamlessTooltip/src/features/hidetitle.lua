---@type string, SeamlessTooltip
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local anySecret = app.features.AnySecret
local unitTooltip = app.unitTooltip

-- Leaves a player's title ("Private", "the Explorer") out of the name line.
local feature = app.features:NewFeature("HideTitle")

function feature:OnInitialize()
    self:AddLinePostCall(Enum.TooltipDataLineType.UnitName, "OnNameLine")
end

-- The title's text before and after the name ("Private " / ", the Explorer"), from the name with
-- title. Nil without a title. This client has surnames (UnitName's second return); one that
-- follows the name in the titled name is part of the name, not of the title.
---@param unit string
---@return string? before
---@return string? after
local function titleOf(unit)
    local name, surname = UnitName(unit)
    local titled = UnitPVPName(unit)
    if not name or not titled or anySecret(name, surname, titled) or name == titled then
        return
    end
    local first, last = titled:find(name, 1, true)
    if not first then
        return
    end
    local before, after = titled:sub(1, first - 1), titled:sub(last + 1)
    if surname and surname ~= "" and after:sub(1, #surname + 1) == " " .. surname then
        after = after:sub(#surname + 2)
    end
    return before, after
end

-- The name line may carry more than the name (a surname, tags added by other features); only the
-- title's own text is taken out.
---@param tooltip GameTooltip
---@param lineData table
function feature:OnNameLine(tooltip, lineData)
    local unit, isPlayer = unitTooltip.Unit(tooltip)
    local left = isPlayer and unitTooltip.LeftLine(tooltip, lineData)
    local text = left and unitTooltip.Readable(left:GetText())
    if not text then
        return
    end
    local before, after = titleOf(unit)
    local changed = text
    if before and before ~= "" then
        changed = unitTooltip.ReplaceWord(changed, before, "") or changed
    end
    if after and after ~= "" then
        changed = unitTooltip.ReplaceWord(changed, after, "") or changed
    end
    if changed ~= text then
        left:SetText(changed)
    end
end
