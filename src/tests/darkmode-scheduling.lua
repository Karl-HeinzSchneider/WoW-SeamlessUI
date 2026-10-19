-- Run from the repository root: lua src/tests/darkmode-scheduling.lua
local root = arg[1] or "."
local app = {}
local combat = false
local timers, events, discoveries = {}, {}, {}
local refreshes, scheduled = 0, 0
function InCombatLockdown()
    return combat
end
local addon = {}
function addon:RegisterEvent(event, method)
    events[event] = method
end
function addon:UnregisterAllEvents()
    events = {}
end
function addon:ScheduleTimer(method, delay)
    assert(delay == 0.05)
    scheduled = scheduled + 1
    timers[#timers + 1] = function()
        self[method](self)
    end
    return scheduled
end
function addon:ScheduleRepeatingTimer()
    error("Darkmode must never poll")
end
function addon:CancelAllTimers()
    timers = {}
end
function addon:Refresh()
    refreshes = refreshes + 1
    self.refreshPending = nil
end
function app:DiscoverCategory(category)
    discoveries[category] = (discoveries[category] or 0) + 1
end
function app:Restore() end
function LibStub(library)
    assert(library == "AceAddon-3.0")
    return {
        GetAddon = function()
            return {}
        end,
        NewAddon = function()
            return addon
        end,
    }
end
assert(loadfile(root .. "/SeamlessDarkmode/src/core.lua"))("SeamlessDarkmode", app)
addon:OnEnable()
assert(refreshes == 1 and #timers == 0, "Enable discovers once without scheduling polling")
assert(not events.UNIT_AURA and not events.PLAYER_TARGET_CHANGED, "Ordinary gameplay must not rescan static roots")
for i = 1, 1000 do
    addon:OnDiscoveryEvent("BAG_UPDATE_DELAYED")
end
assert(#timers == 1 and scheduled == 1, "Event burst must coalesce")
table.remove(timers, 1)()
assert(discoveries.bags == 1 and not discoveries.unitframes, "Only affected category is discovered")
for i = 1, 1000 do
    addon:FlushDiscovery()
end
assert(discoveries.bags == 1 and #timers == 0, "Idle flushes must do no discovery or scheduling")
combat = true
addon:OnDiscoveryEvent("GROUP_ROSTER_UPDATE")
assert(#timers == 0 and addon.pendingCategories.unitframes, "Combat must defer traversal")
combat = false
addon:OnCombatEnded()
assert(discoveries.unitframes == 1 and refreshes == 1, "Combat ending must not refresh unchanged settings")
addon:QueueDiscovery("bags")
combat = true
table.remove(timers, 1)()
assert(addon.pendingCategories.bags, "Combat beginning before callback must preserve work")
addon.refreshPending = true
combat = false
addon:OnCombatEnded()
assert(refreshes == 2 and discoveries.bags == 2, "Deferred settings and discovery must apply")
addon:OnDiscoveryEvent("ADDON_LOADED")
addon:OnDiscoveryEvent("PLAYER_ENTERING_WORLD")
assert(#timers == 1)
table.remove(timers, 1)()
for _, category in ipairs(app.categories) do
    assert(discoveries[category.key])
end
addon:QueueDiscovery("bags")
addon:OnDisable()
assert(#timers == 0 and addon.pendingCategories == nil)
addon:QueueDiscovery("bags")
assert(#timers == 0, "Disabled hooks must remain inert")
print("PASS: no polling, no idle discovery, coalesced category events, combat deferral and disable cleanup")
