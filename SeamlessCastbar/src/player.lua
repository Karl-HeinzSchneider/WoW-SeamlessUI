---@type string, SeamlessCastbar
local _, app = ...

local bar

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

function app.RefreshPlayerBar()
    if not bar or not app.addon:IsEnabled() then
        return
    end
    -- Detached player appearance from CastingBarMixin:SetLook in the client source.
    bar:SetLook("CLASSIC")
    app.PlayerSizeLookChanged()
    bar:SetCastTimeTextShown(app.db.profile.player.castTime.enabled)
    bar:SetIconShown(false)
    app.UpdateIcon(bar)
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
    end
    app.RefreshPlayerBar()
    bar:SetUnit("player", true, false)
end

function app.DisablePlayerBar()
    if bar then
        bar:SetUnit(nil, true, false)
        bar:Hide()
    end
end
