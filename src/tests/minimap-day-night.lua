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
    core = { RefreshEditModeSystemOptions = function() end },
    addon = {
        NewModule = function()
            return module
        end,
    },
    db = { profile = { hideMinimapDayNight = false } },
}
assert(loadfile("SeamlessUI/src/features/minimap.lua"))("SeamlessUI", app)
-- Load the real page and verify Edit Mode uses its Style control and callbacks.
function LibStub()
    return {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    }
end
Enum = { EditModeSystem = { Minimap = 42 } }
app.optionPages = {}
app.core.GetEditModeButtonSection = function()
    return {}
end
app.core.GetEditModePositionButton = function()
    return {}
end
app.core.GetNativePositionOptions = function()
    return {}
end
app.addon.IsEnabled = function()
    return true
end
local registration
function app.core:RegisterEditModeSystemOptions(_, spec)
    registration = spec
end
assert(loadfile("SeamlessUI/src/options/minimap.lua"))("SeamlessUI", app)
module:OnInitialize()
assert(registration.system == Enum.EditModeSystem.Minimap and registration.name == "Style")
assert(registration.enabled())
local row = registration.options[1]
assert(row.get == app.optionPages.minimap.config.args.style.args.hideMinimapDayNight.get)
assert(row.default == false and row.type == "toggle")
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
row.set(true)
assert(row.get(), "Edit Mode writes the shared profile preference")
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
