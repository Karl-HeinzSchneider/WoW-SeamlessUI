-- Shared visibility service: persistent pending choices and guarded multi-setting flushes.
local active, combat, failed, writes = false, false, nil, {}
local saved, callbacks = { [24] = 0, [25] = 1 }, {}
local app = { addon = {}, db = { global = {} }, logger = {} }
function app.logger:warn() end
function app.logger:debug() end
app.LibEditMode = {
    RegisterCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
}
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
local events
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
end
loadService()
local core = app.addon
assert(not core:EditModeVisibility(24))
assert(core:EditModeVisibility(25))
core:EditModeVisibility(24, true)
core:EditModeVisibility(25, false)
assert(#writes == 0 and saved[24] == 0 and saved[25] == 1)
assert(core:EditModeVisibility(24) and not core:EditModeVisibility(25))
loadService() -- Same SavedVariables survive a reload/service recreation.
assert(core:EditModeVisibility(24) and not core:EditModeVisibility(25))
core:EditModeVisibility(24, false)
core:EditModeVisibility(24, true) -- Last choice wins.
active = true
callbacks.enter()
assert(#writes == 2 and saved[24] == 1 and saved[25] == 0)
assert(not next(app.db.global.editModeVisibilityPending))
callbacks.enter()
assert(#writes == 2, "Applied choices must not replay on every entry")
core:EditModeVisibility(24, false)
assert(#writes == 3 and saved[24] == 0)
saved[24] = 1
assert(core:EditModeVisibility(24), "Read external changes after the queue is cleared")
combat = true
core:EditModeVisibility(24, false)
assert(#writes == 3 and not core:EditModeVisibility(24))
callbacks.enter()
assert(#writes == 3)
combat, active = false, false
events.callback(events, "PLAYER_REGEN_ENABLED")
assert(#writes == 3, "Combat exit outside Edit Mode must keep the queue")
active, failed = true, 24
core:EditModeVisibility(25, true)
assert(saved[25] == 1 and app.db.global.editModeVisibilityPending[24] == false)
failed = nil
events.callback(events, "PLAYER_REGEN_ENABLED")
assert(saved[24] == 0 and not next(app.db.global.editModeVisibilityPending))
active = false
core:EditModeVisibility(24, true)
combat, active = true, true
callbacks.enter()
assert(app.db.global.editModeVisibilityPending[24] == true)
combat = false
events.callback(events, "PLAYER_REGEN_ENABLED")
assert(saved[24] == 1 and not next(app.db.global.editModeVisibilityPending))
app.db = nil
callbacks.enter() -- Startup before AceDB initializes is harmless.
print("PASS: queued visibility, reloads, batch entry, immediate writes, failures and combat")
