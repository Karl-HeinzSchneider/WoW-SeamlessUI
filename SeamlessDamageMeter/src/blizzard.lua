---@type string, SeamlessDamageMeter
local _, app = ...

-- The client only records combat statistics while the damageMeterEnabled CVar is on, and the
-- same CVar also shows the game's own meter window. Turn tracking on for our windows and keep the
-- game's window hidden instead (it still shows in Edit Mode, so its layout stays editable).
local CVAR = "damageMeterEnabled"

function app:EnsureTracking()
    if C_CVar.GetCVar(CVAR) ~= nil and not C_CVar.GetCVarBool(CVAR) then
        C_CVar.SetCVar(CVAR, "1")
    end
end

local hooked = false

function app:UpdateBlizzardMeter()
    local frame = DamageMeter
    if type(frame) ~= "table" or type(frame.UpdateShownState) ~= "function" then
        return
    end
    if not hooked then
        hooked = true
        -- Post-hook rather than replacing methods, so the game's frame stays untainted.
        hooksecurefunc(frame, "UpdateShownState", function(meter)
            if app:ShouldHideBlizzardMeter() and not (meter.IsEditing and meter:IsEditing()) then
                meter:Hide()
            end
        end)
    end
    frame:UpdateShownState()
end

function app:ShouldHideBlizzardMeter()
    return self.addon:IsEnabled() and self.db.profile.hideBlizzard
end
