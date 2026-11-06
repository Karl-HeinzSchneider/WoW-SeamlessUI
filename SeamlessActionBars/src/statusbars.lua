---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local module = app.addon:NewModule("StatusBarScale", "AceEvent-3.0", "AceHook-3.0")
local frames = { statusBar1 = "MainStatusTrackingBarContainer", statusBar2 = "SecondaryStatusTrackingBarContainer" }
local original = {}
local xpBars = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function()
    app.RefreshStatusBarScale()
end)

function app.RefreshStatusBarScale()
    if InCombatLockdown() then
        return
    end
    for key, name in pairs(frames) do
        local frame = _G[name]
        if frame then
            if module:IsEnabled() and app.addon:IsEnabled() then
                original[frame] = original[frame] or frame:GetScale()
                frame:SetScale(app.db.profile[key].scale)
            elseif original[frame] then
                frame:SetScale(original[frame])
                original[frame] = nil
            end
        end
    end
    if not module:IsEnabled() and not next(original) then
        events:UnregisterAllEvents()
    end
end

function module:OnInitialize()
    for key, name in pairs(frames) do
        local frame = _G[name]
        if frame then
            app.core:RegisterEditModeSystemOptions(appName .. ":" .. key, {
                system = frame.system,
                systemIndex = frame.systemIndex,
                name = app.optionPages[key].config.name,
                page = { addon = appName, key = key },
                enabled = function()
                    return app.addon:IsEnabled()
                end,
            })
        end
    end
end

function module:OnEnable()
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        app.RefreshStatusBarScale()
        self:HookXPText()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", app.RefreshStatusBarScale)
    self:RegisterEvent("ADDON_LOADED", "HookXPText")
    app.RefreshStatusBarScale()
    self:HookXPText()
end

local function updateXPText(bar, showPercent)
    local xp, maxXP = bar.currXP, bar.maxBar
    if not xp or not maxXP then
        return
    end

    local text = XP_STATUS_BAR_TEXT:format(xp, maxXP)
    if showPercent and maxXP > 0 then
        text = L["%s (%.2f%%)"]:format(text, xp / maxXP * 100)
    end
    bar.OverlayFrame.Text:SetText(text)
end

local function showXPPercent(bar)
    updateXPText(bar, true)
end

function module:HookXPText()
    local info = StatusTrackingBarInfo
    if not info then
        return
    end
    for _, name in pairs(frames) do
        local container = _G[name]
        local bar = container and container.bars and container.bars[info.BarsEnum.Experience]
        if bar and not xpBars[bar] then
            xpBars[bar] = true
            self:SecureHook(bar, "UpdateCurrentText", showXPPercent)
            showXPPercent(bar)
        end
    end
end

function module:OnDisable()
    self:UnhookAll()
    for bar in pairs(xpBars) do
        updateXPText(bar, false)
        xpBars[bar] = nil
    end
    app.RefreshStatusBarScale()
end

function app.StatusBarTextOptions()
    return {
        type = "group",
        inline = true,
        name = L["Style"],
        order = 15,
        args = {
            alwaysShowText = {
                type = "toggle",
                name = L["Always show status bar text"],
                order = 10,
                default = function()
                    return app.core:GetCVarOptionInfo("xpBarText")
                end,
                get = function()
                    return GetCVarBool("xpBarText")
                end,
                set = function(_, value)
                    SetCVar("xpBarText", value)
                end,
            },
        },
    }
end

function app.StatusBarScaleOption(key)
    return {
        type = "range",
        name = L["Scale"],
        order = 0,
        min = 0.5,
        max = 2,
        step = 0.05,
        -- Blizzard_StatusTrackingBar/Mainline/StatusTrackingBar.xml: containers have no scale override.
        default = 1,
        disabled = InCombatLockdown,
        get = function()
            return app.db.profile[key].scale
        end,
        set = function(_, value)
            if InCombatLockdown() then
                return
            end
            app.db.profile[key].scale = value
            app.RefreshStatusBarScale()
            app.core:RefreshOptions(appName)
        end,
    }
end

-- Mirror the client's Width (Size) setting in display units, using its layout draft.
function app.StatusBarWidthOption(getFrame)
    local service = app.core:GetFramePositionService()
    local setting = Enum.EditModeStatusTrackingBarSetting and Enum.EditModeStatusTrackingBarSetting.Size
    return {
        type = "range",
        name = L["Width"],
        order = 1,
        layoutStored = true,
        default = function()
            return setting and service:GetDefaultSetting(getFrame(), setting)
        end,
        min = function()
            local min = service:GetSettingRange(getFrame(), setting)
            return min
        end,
        max = function()
            local _, max = service:GetSettingRange(getFrame(), setting)
            return max
        end,
        step = function()
            local _, _, step = service:GetSettingRange(getFrame(), setting)
            return step
        end,
        disabled = function()
            return not setting or not service:CanEdit(getFrame()) or service:ReadSetting(getFrame(), setting) == nil
        end,
        get = function()
            return setting and service:ReadSetting(getFrame(), setting)
        end,
        set = function(_, value)
            local ok, err = service:ApplySetting(getFrame(), setting, value)
            if not ok and err then
                app.core.logger:warn("%s", err)
            end
            app.core:RefreshOptions(appName)
        end,
    }
end
