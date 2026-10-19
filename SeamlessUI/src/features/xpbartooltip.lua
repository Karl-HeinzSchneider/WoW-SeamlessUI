---@type string, SeamlessUI
local _, app = ...

-- Replaces the player XP bar's tooltip (the bar and its rested tick share one builder) with a
-- detailed layout: rest state, XP, XP left, rested XP and time to the rested cap, then the
-- completed quests in the log and their XP.
-- NewModule only uses a passed table as a prototype, so methods go on the module it returns.
---@class SeamlessUI.XPBarTooltip : AceModule, AceEvent-3.0, AceHook-3.0
local module = app.addon:NewModule("XPBarTooltip", "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessUI.XPBarTooltip]]
app.xpBarTooltip = module
module:SetEnabledState(false)

local function settings()
    return app.db.profile.xpBarTooltip
end

local function durationText(seconds)
    local minutes = math.ceil(seconds / 60)
    local days = math.floor(minutes / 1440)
    local hours = math.floor(minutes / 60) % 24
    return string.format("%dd %dh %dm", days, hours, minutes % 60)
end

---@param tooltip GameTooltip
---@param label string
---@param value string
local function addValue(tooltip, label, value)
    tooltip:AddDoubleLine(label, value, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
end

---@param value number
---@param of number
local function amountText(value, of)
    return string.format("%s (%.2f%%)", BreakUpLargeNumbers(value), of > 0 and value / of * 100 or 0)
end

---@param tooltip GameTooltip
local function addXPLines(tooltip)
    local maxXP = UnitXPMax("player")
    if not maxXP or maxXP <= 0 or GameRulesUtil.IsPlayerAtEffectiveMaxLevel() then
        return
    end
    local currXP = UnitXP("player")

    -- The client does not expose the rested cap or rate; Core's Tweaks hold the assumptions.
    local tweaks = app.core.db.profile.tweaks
    local restedMax = maxXP * tweaks.restedXPCap / 100
    local rested = math.max(0, GetXPExhaustion() or 0)

    tooltip:AddLine(" ")
    addValue(
        tooltip,
        "XP:",
        string.format("%s / %s (%.2f%%)", BreakUpLargeNumbers(currXP), BreakUpLargeNumbers(maxXP), currXP / maxXP * 100)
    )
    addValue(tooltip, "XP left:", amountText(math.max(0, maxXP - currXP), maxXP))
    addValue(tooltip, "Rested:", amountText(rested, restedMax))
    if rested < restedMax and tweaks.restedXPRate > 0 then
        local levels = (restedMax - rested) / maxXP * 100
        addValue(tooltip, "Time to max rested:", durationText(levels / tweaks.restedXPRate * 8 * 60 * 60))
    end
end

---@param tooltip GameTooltip
local function addQuestLines(tooltip)
    local summary = app.core:GetQuestLogSummary()
    tooltip:AddLine(" ")
    addValue(tooltip, "Completed quests:", string.format("%d / %d", summary.completedQuests, summary.totalQuests))
    addValue(tooltip, "Completed quests XP:", BreakUpLargeNumbers(summary.completedQuestXP) .. " XP")
end

-- Runs after ExhaustionTickMixin:ExhaustionToolTipText, which both the bar's and the tick's
-- OnEnter call. Re-anchoring clears the default lines (and those of hooks that ran before this
-- one, such as Core's enhanced XP lines), so the tooltip is rebuilt from scratch without
-- replacing the secure method.
function module:ShowTooltip()
    local tooltip = GetAppropriateTooltip()
    GameTooltip_SetDefaultAnchor(tooltip, UIParent)
    GameTooltip_SetTitle(tooltip, XPBAR_LABEL or "Experience", HIGHLIGHT_FONT_COLOR)

    local stateID, stateName, multiplier = GetRestState()
    if stateID then
        tooltip:AddLine(" ")
        GameTooltip_AddHighlightLine(tooltip, EXHAUST_TOOLTIP1:format(stateName, multiplier * 100))
        if not IsResting() and (stateID == 4 or stateID == 5) then
            GameTooltip_AddHighlightLine(tooltip, EXHAUST_TOOLTIP2)
        end
    end

    addXPLines(tooltip)
    if settings().completedQuests then
        addQuestLines(tooltip)
    end
    tooltip:Show()
end

function module:InstallHooks()
    local manager = StatusTrackingBarManager
    local info = StatusTrackingBarInfo
    if not manager or not info then
        return
    end

    -- Each container owns its own player XP bar.
    for _, container in ipairs(manager.barContainers or {}) do
        local bar = container.bars and container.bars[info.BarsEnum.Experience]
        local tick = bar and bar.ExhaustionTick
        if tick and not self:IsHooked(tick, "ExhaustionToolTipText") then
            self:SecureHook(tick, "ExhaustionToolTipText", "ShowTooltip")
        end
    end
end

-- AceHook deactivates the hooks on disable, which leaves the default tooltip.
function module:OnEnable()
    self:RegisterEvent("ADDON_LOADED", "InstallHooks")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "InstallHooks")
    self:InstallHooks()
end

function module:OnProfileRefresh()
    -- Before login Ace enables modules itself, by their enabled state.
    if not IsLoggedIn() then
        self:SetEnabledState(settings().enabled)
    elseif settings().enabled then
        self:Enable()
    else
        self:Disable()
    end
end

-- The completed-quests lines used to be Core's `tweaks.questXPTooltip`. Carry a profile's
-- "off" over to the UI profile of the same name, then drop it from Core.
function module:OnInitialize()
    for name, profile in pairs(app.core.db.profiles or {}) do
        local tweaks = profile.tweaks
        if tweaks and tweaks.questXPTooltip ~= nil then
            local target = app.db.profiles[name] or {}
            app.db.profiles[name] = target
            target.xpBarTooltip = target.xpBarTooltip or {}
            if tweaks.questXPTooltip == false and target.xpBarTooltip.completedQuests == nil then
                target.xpBarTooltip.completedQuests = false
            end
            tweaks.questXPTooltip = nil
        end
    end
end

---@return table
function module:Options()
    return app.core.FeatureGroup({
        name = "XP bar tooltip",
        desc = "Replaces the XP bar tooltip with a detailed one: rest state, XP and XP left, rested XP and the time to max rested. Rested cap and rate come from the Seamless Tweaks.",
        order = 20,
        options = {
            completedQuests = {
                type = "toggle",
                order = 10,
                width = "full",
                name = "Show completed quests",
                desc = "Adds the number of completed quests in your log and their total XP reward.",
                descStyle = "inline",
            },
        },
        settings = settings,
        toggled = function()
            module:OnProfileRefresh()
        end,
    })
end
