---@type string, SeamlessCore
local _, app = ...

---@class SeamlessCore.XPTooltip : AceModule, AceEvent-3.0, AceHook-3.0
local module = {}
app.addon:NewModule("XPTooltip", module, "AceEvent-3.0", "AceHook-3.0")

function module:AddQuestSummary()
    if not app.db.profile.tweaks.questXPTooltip then
        return
    end

    local tooltip = GetAppropriateTooltip()
    if not tooltip:IsShown() then
        return
    end

    local summary = app.addon:GetQuestLogSummary()
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Completed quests", tostring(summary.completedQuests), 1, 0.82, 0, 1, 1, 1)
    tooltip:AddDoubleLine("Quest XP", BreakUpLargeNumbers(summary.completedQuestXP), 1, 0.82, 0, 1, 1, 1)
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
            self:SecureHook(tick, "ExhaustionToolTipText", "AddQuestSummary")
        end
    end
end

function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "InstallHooks")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "InstallHooks")
    self:InstallHooks()
end
