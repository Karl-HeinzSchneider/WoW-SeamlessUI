-- Run from the repository root: lua src/tests/statusbar-scale.lua
local combat = false
InCombatLockdown = function()
    return combat
end
LibStub = function()
    return {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, k)
                    return k
                end,
            })
        end,
    }
end
local eventFrame = {}
function eventFrame:SetScript(_, callback)
    self.callback = callback
end
function eventFrame:RegisterEvent() end
function eventFrame:UnregisterAllEvents() end
CreateFrame = function()
    return eventFrame
end
local module = { enabled = true }
function module:IsEnabled()
    return self.enabled
end
function module:RegisterEvent() end
local app = { addon = {}, core = {}, db = { profile = { statusBar1 = { scale = 1 }, statusBar2 = { scale = 1 } } } }
function app.addon:NewModule()
    return module
end
function app.addon:IsEnabled()
    return true
end
function app.core:RefreshOptions() end
local function frame()
    return {
        scale = 1,
        GetScale = function(self)
            return self.scale
        end,
        SetScale = function(self, value)
            assert(not combat, "Scale written in combat")
            self.scale = value
        end,
    }
end
MainStatusTrackingBarContainer = frame()
SecondaryStatusTrackingBarContainer = frame()
assert(loadfile("SeamlessActionBars/src/statusbars.lua"))("SeamlessActionBars", app)
module:OnEnable()
local slider = app.StatusBarScaleOption("statusBar1")
slider.set(nil, 1.5)
assert(MainStatusTrackingBarContainer:GetScale() == 1.5)
assert(SecondaryStatusTrackingBarContainer:GetScale() == 1)
combat = true
slider.set(nil, 2)
assert(app.db.profile.statusBar1.scale == 1.5)
app.db.profile = { statusBar1 = { scale = 0.75 }, statusBar2 = { scale = 1.25 } }
app.RefreshStatusBarScale()
assert(MainStatusTrackingBarContainer:GetScale() == 1.5)
combat = false
eventFrame.callback()
assert(MainStatusTrackingBarContainer:GetScale() == 0.75)
assert(SecondaryStatusTrackingBarContainer:GetScale() == 1.25)
combat = true
module.enabled = false
module:OnDisable()
combat = false
eventFrame.callback()
assert(MainStatusTrackingBarContainer:GetScale() == 1)
assert(SecondaryStatusTrackingBarContainer:GetScale() == 1)
print("Status bar frame scaling, independent values, profiles and combat-deferred restore OK")
