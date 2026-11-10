---@type string, SeamlessCastbar
local _, app = ...

local bar
local lastLook, lastShowTime
local lastScale

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
    app.InitializePlayerSettings()
    local showTime = app.db.profile.player.showCastTime
    -- Standalone player appearance, independent of native lock settings.
    local look = "CLASSIC"
    local lookChanged = look ~= lastLook
    if lookChanged then
        bar:SetLook(look)
        app.PlayerSizeLookChanged(bar)
        lastLook = look
    elseif force then
        app.ApplyPlayerSize(bar)
    end
    -- User scale is applied directly, with no frame-scale inheritance.
    local scale = app.db.profile.player.scale or app.PlayerSizeDefault("scale")
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
        -- Position and Edit Mode selection belong to playerposition.lua, never a native frame.
        bar = CreateFrame("StatusBar", "SeamlessCastbarPlayer", UIParent, "CastingBarFrameTemplate")
        bar:Hide()
        bar:SetFrameStrata("HIGH")
        bar.playCastFX = true
        app.ApplyPlayerPosition()
        local shouldShow = bar.ShouldShowCastBar
        bar.ShouldShowCastBar = function(self)
            return not app.IsPlayerEditMode() and shouldShow(self)
        end
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
            if (...) == "PLAYER_ENTERING_WORLD" then
                C_Timer.After(0, app.RefreshPlayerDefault)
            end
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
