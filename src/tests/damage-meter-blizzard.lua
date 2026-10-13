-- Run from the repository root: lua src/tests/damage-meter-blizzard.lua
unpack = unpack or table.unpack
local tainted, enabled, editing, tracking = true, true, false, false
local hooks, shown, updates, hides, secureCalls = {}, false, 0, 0, 0
local function NativeCallback(callback, ...)
    local before = tainted
    tainted = true -- An addon HookScript callback starts in addon context.
    callback(...)
    tainted = before
end
DamageMeter = {
    HookScript = function(_, event, callback)
        assert(event == "OnShow", "Never hook the native combat/timer updater")
        assert(not hooks[event], "Install the show hook once")
        hooks[event] = callback
    end,
    IsEditing = function()
        return editing
    end,
    Hide = function()
        assert(not tainted, "Native hide scripts must stay outside addon taint")
        shown = false
        hides = hides + 1
    end,
    UpdateShownState = function(self)
        assert(not tainted, "Secret-duration timer comparison must not execute in addon context")
        updates = updates + 1
        shown = tracking or editing
        if shown and hooks.OnShow then
            NativeCallback(hooks.OnShow, self)
        end
        assert(not tainted, "An addon visibility hook must not contaminate the remaining native timer update")
    end,
}
C_CVar = {
    GetCVar = function()
        return tracking and "1" or "0"
    end,
    GetCVarBool = function()
        return tracking
    end,
    SetCVar = function(name, value)
        assert(not tainted and name == "damageMeterEnabled", "CVar callbacks must start without addon taint")
        tracking = value == "1"
        DamageMeter:UpdateShownState()
    end,
}
function securecallfunction(callback, ...)
    assert(
        callback == DamageMeter.Hide or callback == DamageMeter.UpdateShownState or callback == C_CVar.SetCVar,
        "Isolation may call original native functions only, not addon closures"
    )
    secureCalls = secureCalls + 1
    local before = tainted
    tainted = false
    callback(...)
    tainted = before
end
function hooksecurefunc()
    error("Do not hook the Blizzard timer pipeline")
end
local app = {
    db = { profile = { hideBlizzard = true } },
    addon = {
        IsEnabled = function()
            return enabled
        end,
    },
}
assert(loadfile("SeamlessDamageMeter/src/blizzard.lua"))("SeamlessDamageMeter", app)
assert(not tracking, "Loading Seamless preserves the native meter UI setting")
app:SetCombatTracking(true)
assert(tracking, "Explicit native UI toggles use a native-isolated CVar call")
app:UpdateBlizzardMeter()
assert(not shown and hides == 1)
local previousUpdates = updates
app:UpdateBlizzardMeter()
assert(updates == previousUpdates, "Hiding should not enter the native timer pipeline")
-- A clean native combat event can show the frame and invoke its normal timer update.
securecallfunction(DamageMeter.UpdateShownState, DamageMeter)
assert(not shown and tainted, "Hide-on-show preserves the surrounding native context")
editing = true
app:UpdateBlizzardMeter()
assert(shown, "Blizzard Edit Mode must remain visible")
editing = false
app:UpdateBlizzardMeter()
assert(not shown)
app.db.profile.hideBlizzard = false
app:UpdateBlizzardMeter()
assert(shown, "Restoring the native meter uses its own visibility rules in native context")
app.db.profile.hideBlizzard = true
enabled = false
app:UpdateBlizzardMeter()
assert(shown, "Disabling Seamless restores the native meter")
app:SetCombatTracking(false)
assert(not tracking and not shown)
app:SetCombatTracking(true)
assert(tracking and shown)
local original = DamageMeter
DamageMeter = nil
app:UpdateBlizzardMeter()
DamageMeter = original
assert(secureCalls > 0)
print(
    "PASS: isolated native CVar/visibility callbacks, no timer hooks, hidden meter, Edit Mode and disable restoration"
)
