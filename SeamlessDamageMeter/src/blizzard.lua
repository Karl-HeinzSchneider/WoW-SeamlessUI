---@type string, SeamlessDamageMeter
local _, app = ...

-- Blizzard's meter compares secret combat values in its own code (session timer, refresh). Addon
-- code must never run inside it or write its state, or that code runs tainted and errors in
-- combat: no hooks, no calls to its methods, no writes to the damageMeterEnabled CVar (its
-- CVAR_UPDATE callbacks run inside the caller). securecallfunction does not clear the caller's
-- taint, so it is no way around this.
--
-- Hiding only moves the frame under a hidden parent, once per session. Blizzard's own code keeps
-- running untainted; a frame that never becomes visible never runs its OnShow. Showing it again
-- needs a reload, so it is never touched after that.
local hiddenParent

function app:HideBlizzardMeter()
    if hiddenParent or not self.db.profile.hideBlizzard or type(DamageMeter) ~= "table" then
        return
    end
    hiddenParent = CreateFrame("Frame")
    hiddenParent:Hide()
    DamageMeter:SetParent(hiddenParent)
end

function app:IsBlizzardMeterHidden()
    return hiddenParent ~= nil
end

-- The game's own settings page owns the damageMeterEnabled CVar.
function app:OpenBlizzardMeterSettings()
    Settings.OpenToCategory(Settings.ADVANCED_OPTIONS_CATEGORY_ID)
end
