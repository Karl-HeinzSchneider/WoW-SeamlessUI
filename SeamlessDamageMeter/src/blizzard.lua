---@type string, SeamlessDamageMeter
local _, app = ...

-- The client only records combat statistics while the damageMeterEnabled CVar is on, and the
-- same CVar also shows the game's own meter window. Turn tracking on for our windows and keep the
-- game's window hidden instead (it still shows in Edit Mode, so its layout stays editable).
local CVAR = "damageMeterEnabled"

function app:EnsureTracking()
    if C_CVar.GetCVar(CVAR) ~= nil and not C_CVar.GetCVarBool(CVAR) then
        self:SetCombatTracking(true)
    end
end

function app:SetCombatTracking(enabled)
    -- The CVar invokes Blizzard callbacks synchronously. Keep those native callbacks
    -- out of addon execution taint; this never grants secret access to addon code.
    securecallfunction(C_CVar.SetCVar, CVAR, enabled and "1" or "0")
end

local hooked = false

function app:UpdateBlizzardMeter()
    local frame = DamageMeter
    if type(frame) ~= "table" or type(frame.UpdateShownState) ~= "function" then
        return
    end
    if not hooked then
        hooked = true
        frame:HookScript("OnShow", function(meter)
            if app:ShouldHideBlizzardMeter() and not (meter.IsEditing and meter:IsEditing()) then
                securecallfunction(meter.Hide, meter)
            end
        end)
    end
    if self:ShouldHideBlizzardMeter() and not (frame.IsEditing and frame:IsEditing()) then
        securecallfunction(frame.Hide, frame)
    else
        -- Only the original Blizzard method runs in the isolated native call. Calling
        -- it directly can taint timer state and break later secret-duration comparisons.
        securecallfunction(frame.UpdateShownState, frame)
    end
end

function app:ShouldHideBlizzardMeter()
    return self.addon:IsEnabled() and self.db.profile.hideBlizzard
end
