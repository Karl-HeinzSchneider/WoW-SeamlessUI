-- Run from the repository root: lua src/tests/minimap-day-night.lua
local module = { hooks = {} }
function module:IsEnabled()
    return true
end
function module:IsHooked(frame)
    return self.hooks[frame] ~= nil
end
function module:SecureHookScript(frame, _, method)
    self.hooks[frame] = method
end
function module:RegisterEvent() end
function module:UnregisterAllEvents() end
function module:UnhookAll()
    self.hooks = {}
end
function IsLoggedIn()
    return true
end
local app = {
    addon = {
        NewModule = function()
            return module
        end,
    },
    db = { profile = { hideMinimapDayNight = false } },
}
assert(loadfile("SeamlessUI/src/features/minimap.lua"))("SeamlessUI", app)
module:OnEnable() -- Also safe before Blizzard_Minimap loads.
local frame = { shown = true }
function frame:IsShown()
    return self.shown
end
function frame:Hide()
    self.shown = false
end
function frame:Show()
    self.shown = true
    if module.hooks[self] then
        module[module.hooks[self]](module)
    end
end
MinimapCluster = { DielFrame = frame }
module:Apply()
assert(frame.shown, "visible by default")
app.db.profile.hideMinimapDayNight = true
module:OnProfileRefresh()
assert(not frame.shown, "toggle hides the indicator")
frame:Show()
assert(not frame.shown, "native Show cannot undo the preference")
app.db.profile = { hideMinimapDayNight = false }
module:OnProfileRefresh()
assert(frame.shown, "profile change restores the indicator")
app.db.profile.hideMinimapDayNight = true
module:OnProfileRefresh()
module:OnDisable()
assert(frame.shown, "addon disable restores the indicator")
module:OnEnable()
assert(not frame.shown, "re-enable reapplies the preference")
print("Minimap day/night visibility OK")
