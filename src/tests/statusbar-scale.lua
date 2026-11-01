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
app.optionPages = {
    statusBar1 = { config = { name = "XP / reputation bar 1" } },
    statusBar2 = { config = { name = "XP / reputation bar 2" } },
}
local registrations = {}
function app.core:RegisterEditModeSystemOptions(id, spec)
    assert(not registrations[id])
    assert(spec.page.path == nil, "Register the full page through the existing section builder")
    registrations[id] = spec
end
module:OnInitialize()
assert(registrations["SeamlessActionBars:statusBar1"].page.key == "statusBar1")
assert(registrations["SeamlessActionBars:statusBar2"].page.key == "statusBar2")
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

Enum = { EditModeStatusTrackingBarSetting = { Size = 7 } }
local nativeValues = { [MainStatusTrackingBarContainer] = 100, [SecondaryStatusTrackingBarContainer] = 80 }
local service = {}
function service:CanEdit()
    return not combat
end
function service:ReadSetting(target, setting)
    assert(setting == 7)
    return nativeValues[target]
end
function service:GetDefaultSetting(_, setting)
    assert(setting == 7)
    return 100
end
function service:GetSettingRange(_, setting)
    assert(setting == 7)
    return 50, 130, 5
end
function service:ApplySetting(target, setting, value)
    assert(setting == 7)
    if combat then
        return false
    end
    nativeValues[target] = value
    return true
end
function app.core:GetFramePositionService()
    return service
end
local width = app.StatusBarWidthOption(function()
    return MainStatusTrackingBarContainer
end)
assert(width.layoutStored and width.default() == 100)
assert(width.min() == 50 and width.max() == 130 and width.step() == 5)
width.set(nil, 120)
assert(width.get() == 120 and nativeValues[SecondaryStatusTrackingBarContainer] == 80)
nativeValues[MainStatusTrackingBarContainer] = 90
assert(width.get() == 90, "External native draft changes are reflected")
combat = true
assert(width.disabled())
width.set(nil, 130)
assert(width.get() == 90)
print("Native status bar Width range, defaults, draft writes and external updates OK")
