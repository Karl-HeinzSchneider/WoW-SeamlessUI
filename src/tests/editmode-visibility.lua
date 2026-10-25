-- Visibility choices never open, close or cycle Edit Mode. Only manual entry applies the queue.
local active, combat, failed, updateFails = false, false, nil, false
local saved, preview = { [24] = 0, [25] = 1 }, {}
local callbacks, timers, events, writes = {}, {}, nil, {}
local app = { addon = {}, db = { global = {} }, logger = {} }
local panelRefreshes, panelSnapshot = 0, {}
function app.addon:RefreshEditModeOptions()
    panelRefreshes = panelRefreshes + 1
    panelSnapshot[24], panelSnapshot[25] = preview[24], preview[25]
end
function app.logger:warn() end
function app.logger:debug() end
app.LibEditMode = {
    RegisterCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
}
C_Timer = {
    After = function(_, callback)
        timers[#timers + 1] = callback
    end,
}
local function tick()
    local current = timers
    timers = {}
    for _, callback in ipairs(current) do
        callback()
    end
end
local lib = {}
function lib:GetGlobalSetting(setting)
    return saved[setting]
end
function lib:SetGlobalSetting(setting, value)
    assert(active and not combat)
    if setting == failed then
        error("write failed")
    end
    saved[setting] = value
    writes[#writes + 1] = { setting, value }
end
local function forbidden()
    error("Visibility must never open, close or cycle Edit Mode")
end
lib.ApplyChanges, lib.LoadLayouts, lib.SaveOnly = forbidden, forbidden, forbidden
ShowUIPanel, HideUIPanel = forbidden, forbidden
function LibStub(name)
    if name == "AceLocale-3.0" then
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
    return lib
end
function InCombatLockdown()
    return combat
end
EditModeManagerFrame = {
    IsEditModeActive = function()
        return active
    end,
}
function CreateFrame()
    events = {
        RegisterEvent = function() end,
        SetScript = function(self, _, callback)
            self.callback = callback
        end,
    }
    return events
end
local function loadService()
    assert(loadfile("Seamless/src/core/editmodevisibility.lua"))("Seamless", app)
    for _, setting in ipairs({ 24, 25 }) do
        app.addon:GetEditModeVisibility(setting, function(value)
            assert(active and not combat)
            if updateFails then
                error("preview failed")
            end
            preview[setting] = value
            callbacks.enter() -- Nested notifications cannot recurse.
        end)
    end
end
loadService()
local core = app.addon
assert(not core:EditModeVisibility(24) and core:EditModeVisibility(25))
core:EditModeVisibility(24, true)
core:EditModeVisibility(25, false)
tick()
assert(#writes == 0 and not active and preview[24] == nil)
loadService() -- Pending choices survive reloads.
assert(core:EditModeVisibility(24) and not core:EditModeVisibility(25))
core:EditModeVisibility(24, false)
core:EditModeVisibility(24, true)
active = true -- User manually opens Edit Mode.
callbacks.enter()
assert(#writes == 0)
tick()
assert(active and #writes == 2 and preview[24] == true and preview[25] == false)
assert(
    panelRefreshes == 1 and panelSnapshot[24] == true and panelSnapshot[25] == false,
    "Refresh the shared checkboxes once, after the whole deferred batch"
)
assert(not next(app.db.global.editModeVisibilityPending))
callbacks.enter()
tick()
assert(#writes == 2)
core:EditModeVisibility(24, false)
assert(active and #writes == 3 and preview[24] == false)
assert(panelRefreshes == 2 and panelSnapshot[24] == false, "Immediate changes also refresh the panel")
active = false -- User closes it; events/timers must never reopen it.
callbacks.exit()
events.callback(events, "EDIT_MODE_LAYOUTS_UPDATED")
events.callback(events, "PLAYER_REGEN_ENABLED")
tick()
assert(not active and #writes == 3)
core:EditModeVisibility(24, true)
active = true
callbacks.enter()
active = false -- User closes before the deferred flush.
tick()
assert(not active and #writes == 3 and core:EditModeVisibility(24))
active, updateFails = true, true
callbacks.enter()
tick()
assert(app.db.global.editModeVisibilityPending[24] == true)
updateFails = false
callbacks.enter()
tick()
assert(active and preview[24] == true and not next(app.db.global.editModeVisibilityPending))
active, failed = false, 24
core:EditModeVisibility(24, false)
core:EditModeVisibility(25, true)
active = true
callbacks.enter()
tick()
assert(app.db.global.editModeVisibilityPending[24] == false and preview[25] == true)
failed = nil
events.callback(events, "PLAYER_REGEN_ENABLED")
assert(preview[24] == false and not next(app.db.global.editModeVisibilityPending))
combat = true
local before = #writes
core:EditModeVisibility(24, true)
callbacks.enter()
tick()
assert(#writes == before)
combat, active = false, false
events.callback(events, "PLAYER_REGEN_ENABLED")
assert(not active and #writes == before)
active = true
callbacks.enter()
tick()
assert(active and preview[24] == true)
saved[24] = 0
assert(not core:EditModeVisibility(24))
-- Custom bindings share the same queue, without touching native account flags.
active = false
local customShown, customUpdates = true, 0
local function customGet()
    return customShown
end
local function customSet(value)
    assert(active and not combat)
    customShown = value
    customUpdates = customUpdates + 1
end
local first = core:GetCustomEditModeVisibility("Meter.windows", customGet, customSet)
local second = core:GetCustomEditModeVisibility("Meter.windows", customGet, customSet)
local nativeWrites = #writes
first(false)
assert(not second() and customShown and customUpdates == 0)
core:EditModeVisibility(24, true)
active = true
callbacks.enter()
tick()
assert(not customShown and customUpdates == 1 and #writes == nativeWrites + 1)
assert(not next(app.db.global.editModeVisibilityPending))
second(true)
assert(first() and customShown and customUpdates == 2)
customShown = false -- The existing Frames checkbox can change the same state.
assert(not first() and not second())
active = false
first(true)
loadService()
local reloaded = core:GetCustomEditModeVisibility("Meter.windows", customGet, customSet)
assert(reloaded() and not customShown)
active = true
callbacks.enter()
tick()
assert(customShown and not next(app.db.global.editModeVisibilityPending))
app.db = nil
callbacks.enter()
tick()
print("PASS: manual entry only, no mode opening/closing, queued batches, previews, failures, reloads and combat")
