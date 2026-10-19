---@type string, SeamlessCore
local _, app = ...

---@class SeamlessCore.XPTooltip : AceModule, AceEvent-3.0, AceHook-3.0
local module = {}
app.addon:NewModule("XPTooltip", module, "AceEvent-3.0", "AceHook-3.0")

local function durationText(seconds)
    local minutes = math.ceil(seconds / 60)
    local days = math.floor(minutes / 1440)
    local hours = math.floor(minutes / 60) % 24
    return string.format("%dd %dh %dm", days, hours, minutes % 60)
end

---@param tooltip GameTooltip
function module:AddXPDetails(tooltip)
    local maxXP = UnitXPMax("player")
    if not maxXP or maxXP <= 0 or GameRulesUtil.IsPlayerAtEffectiveMaxLevel() then
        return
    end

    local settings = app.db.profile.tweaks
    local remaining = math.max(0, maxXP - UnitXP("player"))
    local rested = math.max(0, GetXPExhaustion() or 0)
    local restedPercent = rested / maxXP * 100
    local capPercent = settings.restedXPCap
    local ratePercent = settings.restedXPRate
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        "XP to next level",
        string.format("%s (%.1f%%)", BreakUpLargeNumbers(remaining), remaining / maxXP * 100),
        1,
        0.82,
        0,
        1,
        1,
        1
    )
    tooltip:AddDoubleLine(
        "Rested XP",
        string.format("%s (%.1f%% of a level)", BreakUpLargeNumbers(rested), restedPercent),
        1,
        0.82,
        0,
        1,
        1,
        1
    )
    tooltip:AddDoubleLine("Rested cap (configured)", string.format("%g%% of a level", capPercent), 1, 0.82, 0, 1, 1, 1)
    if restedPercent >= capPercent then
        tooltip:AddDoubleLine("Rested cap", "Reached", 1, 0.82, 0, 1, 1, 1)
    elseif ratePercent > 0 then
        local seconds = (capPercent - restedPercent) / ratePercent * 8 * 60 * 60
        tooltip:AddDoubleLine("Time to cap (estimate)", durationText(seconds), 1, 0.82, 0, 1, 1, 1)
        tooltip:AddLine(
            string.format("Assumes inn/city rest at %g%% per 8 hours, without spending rested XP.", ratePercent),
            0.7,
            0.7,
            0.7,
            true
        )
    end
end

function module:AddTooltipDetails()
    local settings = app.db.profile.tweaks
    if not settings.enhancedXPTooltip then
        return
    end

    local tooltip = GetAppropriateTooltip()
    if not tooltip:IsShown() then
        return
    end

    self:AddXPDetails(tooltip)
    tooltip:Show()
end

function module:InstallHooks()
    local manager = StatusTrackingBarManager
    local info = StatusTrackingBarInfo
    if not manager or not info then
        return
    end

    -- Each container owns its own player XP bar. Hook its tooltip builder so
    -- both the bar and rested-XP tick retain Blizzard's normal tooltip content.
    for _, container in ipairs(manager.barContainers or {}) do
        local bar = container.bars and container.bars[info.BarsEnum.Experience]
        local tick = bar and bar.ExhaustionTick
        if tick and not self:IsHooked(tick, "ExhaustionToolTipText") then
            self:SecureHook(tick, "ExhaustionToolTipText", "AddTooltipDetails")
        end
    end
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "InstallHooks")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "InstallHooks")
    self:InstallHooks()
end
