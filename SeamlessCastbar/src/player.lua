---@type string, SeamlessCastbar
local _, app = ...

local bar

-- The client template supplies CastingBarMixin, event/update scripts and FX without
-- Edit Mode or frame management. Keep changes off the native frame and shared mixins.
function app.RefreshPlayerComparison()
    local native = PlayerCastingBarFrame
    if not bar or not app.addon:IsEnabled() then
        return
    end
    bar.classicStyleCastBar = native.classicStyleCastBar
    bar:SetLook(native.look or "CLASSIC")
    bar:SetScale(native:GetEffectiveScale() / UIParent:GetEffectiveScale())
    bar:SetSize(native:GetWidth(), native:GetHeight())
    bar:ClearAllPoints()
    -- Extra space for the spell name below the comparison bar.
    bar:SetPoint("BOTTOM", native, "TOP", 0, 32)
    bar:SetCastTimeTextShown(native.showCastTimeSetting)
end

function app.EnablePlayerComparison()
    if not bar then
        bar = CreateFrame("StatusBar", "SeamlessCastbarPlayerComparison", UIParent, "CastingBarFrameTemplate")
        bar:Hide()
        bar:SetFrameStrata("HIGH")
        -- PlayerCastingBarFrameTemplate enables FX, but also registers with Edit Mode.
        bar.playCastFX = true
        bar:SetIconShown(false)
    end
    app.RefreshPlayerComparison()
    bar:SetUnit("player", true, false)
end

function app.DisablePlayerComparison()
    if bar then
        bar:SetUnit(nil, true, false)
        bar:Hide()
    end
end
