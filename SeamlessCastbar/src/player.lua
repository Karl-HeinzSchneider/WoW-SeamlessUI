---@type string, SeamlessCastbar
local _, app = ...

local bar
local lastLook, lastShowTime
local lastScale

-- Read the shared layout data, never the other bar's fields or event handlers.
-- Checkbox values are raw 0/1 (EditModeSystemMixin:GetSettingValueBool).
local function layoutSettings()
    local layout = EditModeManagerFrame:GetActiveLayoutInfo()
    for _, system in ipairs(layout and layout.systems or {}) do
        if system.system == Enum.EditModeSystem.CastBar then
            local locked, showTime = false, false
            for _, setting in ipairs(system.settings) do
                if setting.setting == Enum.EditModeCastBarSetting.LockToPlayerFrame then
                    locked = setting.value == 1
                elseif setting.setting == Enum.EditModeCastBarSetting.ShowCastTime then
                    showTime = setting.value == 1
                end
            end
            return locked, showTime
        end
    end
end

function app.GetPlayerBar()
    return bar
end

-- Extend methods on our instance only. The template's scripts dispatch to these methods;
-- SetUnit subscribes this frame to the same player spellcast events as the default bar.
local function extend(method, after)
    local native = bar[method]
    bar[method] = function(self, ...)
        native(self, ...)
        after(self)
    end
end

function app.RefreshPlayerBar(force)
    if not bar or not app.addon:IsEnabled() then
        return
    end
    local locked, showTime = layoutSettings()
    if locked == nil then
        return -- Layout initialization has not completed yet.
    end
    -- PlayerFrame_AttachCastBar/DetachCastBar select these looks in the client.
    local look = locked and "UNITFRAME" or "CLASSIC"
    local lookChanged = look ~= lastLook
    if lookChanged then
        bar:SetLook(look)
        app.PlayerSizeLookChanged(bar)
        lastLook = look
    elseif force then
        app.ApplyPlayerSize(bar)
    end
    -- The original inherits PlayerFrame's scale when locked. Our independent UIParent
    -- child applies that same parent-scale rule without reparenting or reading the bar.
    local scale = app.db.profile.player.scale or app.PlayerSizeDefault("scale")
    scale = scale * (locked and PlayerFrame:GetEffectiveScale() / UIParent:GetEffectiveScale() or 1)
    if scale ~= lastScale or force or lookChanged then
        bar:SetScale(scale)
        lastScale = scale
    end
    if showTime ~= lastShowTime then
        bar:SetCastTimeTextShown(showTime)
        lastShowTime = showTime
    end
    if lookChanged or force then
        bar:SetIconShown(true)
        app.UpdateIcon(bar)
    end
end

function app.EnablePlayerBar()
    if not bar then
        -- No Edit Mode registration or managed-frame mixins: placement is temporary.
        bar = CreateFrame("StatusBar", "SeamlessCastbarPlayer", UIParent, "CastingBarFrameTemplate")
        bar:Hide()
        bar:SetFrameStrata("HIGH")
        bar.playCastFX = true
        bar:SetPoint("BOTTOM", PlayerCastingBarFrame, "TOP", 0, 32)
        extend("UpdateCastTimeText", app.UpdateCastTime)
        extend("HandleCastStart", function(self)
            app.UpdateName(self)
            app.UpdateTicks(self)
            app.UpdateCastTime(self)
        end)
        extend("HandleChannelUpdateDelayed", app.UpdateTicks)
        extend("HandleCastDelayed", app.UpdateTicks)
        extend("UpdateIconShown", app.UpdateIcon)
        bar:HookScript("OnHide", app.HideTicks)
        -- Independent subscriptions still come from SetUnit. Refresh from shared settings
        -- before processing our own events, including the first cast after a layout change.
        local onEvent = bar:GetScript("OnEvent")
        bar:SetScript("OnEvent", function(self, ...)
            app.RefreshPlayerBar()
            onEvent(self, ...)
        end)
        bar:HookScript("OnUpdate", function()
            app.RefreshPlayerBar()
        end)
        app.InstallCraftingBar(bar)
    end
    app.RefreshPlayerBar(true)
    bar:SetUnit("player", true, false)
    app.EnableCraftingBar(bar)
end

function app.DisablePlayerBar()
    if bar then
        app.DisableCraftingBar(bar)
        bar:SetUnit(nil, true, false)
        bar:Hide()
    end
end
