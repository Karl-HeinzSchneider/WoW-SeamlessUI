-- Native UI keeps a cache separate from account settings. Only a library refresh
-- and its layout-update event replace it; setting the account flag is insufficient.
local active, combat, failed, applyFails = false, false, nil, false
local saved, cached, preview = { [24] = 0, [25] = 1 }, { [24] = 0, [25] = 1 }, {}
local callbacks, timers, events, writes = {}, {}, nil, {}
local applies, loads = 0, 0
local app = { addon = {}, db = { global = {} }, logger = {} }
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
function lib:LoadLayouts()
    loads = loads + 1
end
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
function lib:ApplyChanges()
    applies = applies + 1
    assert(active and not combat)
    if applyFails then
        error("refresh failed")
    end
    callbacks.enter() -- A refresh may emit callbacks; these must not recurse.
    active = false
    callbacks.exit()
end
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
function ShowUIPanel(frame)
    assert(frame == EditModeManagerFrame and not combat)
    active = true
    preview[24], preview[25] = cached[24], cached[25]
    callbacks.enter()
end
function CreateFrame()
    events = {
        RegisterEvent = function() end,
        SetScript = function(self, _, callback)
            self.callback = callback
        end,
    }
    return events
end
local function layoutUpdated()
    -- Our observer may run before Blizzard's handler; restoration must wait a frame.
    events.callback(events, "EDIT_MODE_LAYOUTS_UPDATED")
    cached[24], cached[25] = saved[24], saved[25]
    tick()
end
local function loadService()
    assert(loadfile("Seamless/src/core/editmodevisibility.lua"))("Seamless", app)
end
loadService()
local core = app.addon
assert(not core:EditModeVisibility(24) and core:EditModeVisibility(25))
core:EditModeVisibility(24, true)
core:EditModeVisibility(25, false)
assert(#writes == 0 and applies == 0)
loadService() -- Queued choices survive a service reload.
assert(core:EditModeVisibility(24) and not core:EditModeVisibility(25))
core:EditModeVisibility(24, false)
core:EditModeVisibility(24, true)
active = true
callbacks.enter()
assert(#writes == 0, "Do not cycle Edit Mode inside its native entry stack")
tick()
assert(#writes == 2 and applies == 1 and loads == 1 and not active)
assert(not next(app.db.global.editModeVisibilityPending))
assert(cached[24] == 0, "Setter success alone has not refreshed native state")
layoutUpdated()
assert(active and preview[24] == 1 and preview[25] == 0)
tick()
assert(applies == 1, "Restoring Edit Mode must not replay the batch")
core:EditModeVisibility(24, false)
assert(applies == 2 and not active)
layoutUpdated()
assert(active and preview[24] == 0)
-- Failed refresh retains choices, even if the setter succeeded.
applyFails = true
core:EditModeVisibility(24, true)
assert(app.db.global.editModeVisibilityPending[24] == true)
applyFails = false
callbacks.enter()
tick()
layoutUpdated()
assert(active and preview[24] == 1 and not next(app.db.global.editModeVisibilityPending))
-- Failure of one setter does not prevent the others from refreshing.
active, failed = false, 24
core:EditModeVisibility(24, false)
core:EditModeVisibility(25, true)
active = true
callbacks.enter()
tick()
layoutUpdated()
assert(app.db.global.editModeVisibilityPending[24] == false and preview[25] == 1)
failed = nil
events.callback(events, "PLAYER_REGEN_ENABLED")
layoutUpdated()
assert(preview[24] == 0 and not next(app.db.global.editModeVisibilityPending))
-- Combat defers writes and restoration, and leaving combat outside Edit Mode stays queued.
combat = true
local before = applies
core:EditModeVisibility(24, true)
callbacks.enter()
tick()
assert(applies == before)
combat, active = false, false
events.callback(events, "PLAYER_REGEN_ENABLED")
assert(applies == before)
active = true
callbacks.enter()
tick()
combat = true
layoutUpdated()
assert(not active)
combat = false
events.callback(events, "PLAYER_REGEN_ENABLED")
tick()
assert(active and preview[24] == 1)
saved[24] = 0
assert(not core:EditModeVisibility(24), "Read external account changes after successful apply")
app.db = nil
callbacks.enter()
tick()
print("PASS: batch library refresh, native cache update, mode restoration, recursion, failures, reloads and combat")
