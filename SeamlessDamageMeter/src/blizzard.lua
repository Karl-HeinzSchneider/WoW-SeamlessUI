---@type string, SeamlessDamageMeter
local _, app = ...

-- Blizzard's meter compares secret combat values in its own code (session timer, refresh). Addon
-- code must never run inside it or write its state, or that code runs tainted and errors in
-- combat: no hooks, no calls to its methods, no reparenting, no writes to the damageMeterEnabled
-- CVar (its CVAR_UPDATE callbacks run inside the caller). securecallfunction does not clear the
-- caller's taint. Players turn it off in the game's own settings, which we only open.
function app:OpenBlizzardMeterSettings()
    Settings.OpenToCategory(Settings.ADVANCED_OPTIONS_CATEGORY_ID)
end
