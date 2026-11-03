-- Run from the repository root: lua src/tests/actionbars-lifecycle.lua
local timers, events, hooks = {}, {}, {}
local enabled = true
local addon = {}
function addon:IsEnabled()
    return enabled
end
function addon:RegisterEvent(event, handler)
    events[event] = handler
end
function addon:UnregisterAllEvents()
    events = {}
end
function addon:SecureHook(object, method, handler)
    assert(method ~= "UpdateUsable", "never hook the failing native method")
    if type(object) == "string" then
        hooks[object] = method
    else
        hooks[object] = handler
    end
end
function addon:UnhookAll()
    hooks = {}
end
function wipe(target)
    for key in pairs(target) do
        target[key] = nil
    end
end
C_Timer = {
    After = function(delay, callback)
        assert(delay == 0)
        timers[#timers + 1] = callback
    end,
}
local function flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do
        callback()
    end
end
local core = { RefreshEditModeSystemOptions = function() end }
function LibStub()
    return {
        GetAddon = function()
            return core
        end,
        NewAddon = function()
            return addon
        end,
    }
end
local app = {}
assert(loadfile("SeamlessActionBars/src/core.lua"))("SeamlessActionBars", app)
assert(loadfile("SeamlessActionBars/src/icons.lua"))("SeamlessActionBars", app)
app.db = {
    profile = {
        range = { enabled = true, color = { r = 1, g = 0, b = 0 } },
        mana = { enabled = true, color = { r = 0, g = 0, b = 1 } },
    },
}
local usable, noMana, inRange = false, true, true
C_ActionBar = {
    HasAction = function()
        return true
    end,
    IsUsableAction = function()
        return usable, noMana
    end,
    IsActionInRange = function()
        return inRange
    end,
}
local paints, color = 0
local button = { action = 1, icon = {} }
function button.icon:SetVertexColor(r, g, b)
    paints = paints + 1
    color = { r, g, b }
end
local nativeUsable = function()
    error("addon must never call native UpdateUsable")
end
button.UpdateUsable = nativeUsable
MainActionBar = { actionButtons = { button } }
app.UpdateHotkey, app.RestoreHotkey = function() end, function() end
app.ApplyEndCaps, app.RefreshMicroMenu = function() end, function() end
app.RefreshBarVisibility, app.RefreshBagStyle, app.RefreshStatusBarScale =
    function() end, function() end, function() end
app.xpBarTooltip = { OnProfileRefresh = function() end }
local function event(name, ...)
    assert(events[name], "event registered: " .. name)
    addon[events[name]](addon, name, ...)
end
local function isColor(r, g, b)
    assert(color[1] == r and color[2] == g and color[3] == b)
end

addon:OnEnable()
assert(button.UpdateUsable == nativeUsable)
-- Blizzard may overwrite the initial tint later in PLAYER_ENTERING_WORLD.
event("PLAYER_ENTERING_WORLD")
button.icon:SetVertexColor(0.5, 0.5, 1)
local before = paints
assert(#timers == 1, "startup work is coalesced")
flush()
assert(paints == before + 1)
isColor(0, 0, 1)

-- Every native full-update/usable path schedules a repaint after the native handler.
for _, name in ipairs({
    "ACTION_USABLE_CHANGED",
    "ACTIONBAR_SLOT_CHANGED",
    "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "UPDATE_VEHICLE_ACTIONBAR",
    "SPELL_UPDATE_ICON",
}) do
    event(name)
    event(name)
    assert(#timers == 1, "event bursts coalesce")
    button.icon:SetVertexColor(0.5, 0.5, 1)
    flush()
    isColor(0, 0, 1)
end
usable, noMana = true, false
event("ACTION_USABLE_CHANGED")
flush()
isColor(1, 1, 1)

-- Range updates still apply immediately, and pet buttons remain untouched.
inRange = false
hooks.ActionButton_UpdateRangeIndicator(button)
isColor(1, 0, 0)
before = paints
hooks.ActionButton_UpdateRangeIndicator({ action = 1, icon = button.icon })
assert(paints == before)

-- A queued callback cannot reapply a tint after disable.
event("ACTION_USABLE_CHANGED")
enabled = false
addon:OnDisable()
isColor(1, 1, 1)
before = paints
flush()
assert(paints == before and next(events) == nil and next(hooks) == nil)

-- Old callbacks must not run even if the addon was re-enabled before they fired.
enabled = true
addon:OnEnable()
enabled = false
addon:OnDisable()
enabled = true
addon:OnEnable()
before = paints
flush()
assert(paints == before + 1, "only the latest enable owns pending work")
assert(button.UpdateUsable == nativeUsable)
isColor(1, 0, 0)
print("PASS: action icon event ordering, coalescing, range filtering and lifecycle")
