-- Run from the root: lua src/tests/default-layout.lua
local PRESET, ACCOUNT, CHARACTER = 0, 1, 2
Enum = { EditModeLayoutType = { Preset = PRESET, Account = ACCOUNT, Character = CHARACTER } }
Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 5 } }
ERR_NOT_IN_COMBAT = "combat"
LibStub = function()
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
function tAppendAll(target, source)
    for _, value in ipairs(source) do
        target[#target + 1] = value
    end
end
local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, inner in pairs(value) do
        result[key] = copy(inner)
    end
    return result
end
local timers = {}
C_Timer = {
    After = function(_, callback)
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
local combat, editing = false, false
InCombatLockdown = function()
    return combat
end
EditModeManagerFrame = {
    IsInitialized = function()
        return true
    end,
    IsEditModeActive = function()
        return editing
    end,
}
local presets = { { layoutType = PRESET, layoutName = "Modern" }, { layoutType = PRESET, layoutName = "Classic" } }
EditModePresetLayoutManager = {
    GetCopyOfPresetLayouts = function()
        return copy(presets)
    end,
}

-- Saved state as the client keeps it: layouts without presets, active index counting presets.
local saved, calls
local function reset(layouts, active)
    saved = { layouts = layouts, activeLayout = active }
    calls = {}
end
C_EditMode = {
    GetLayouts = function()
        return copy(saved)
    end,
    ConvertStringToLayoutInfo = function(text)
        assert(text == "EXPORT")
        return { systems = {} }
    end,
    SaveLayouts = function(info)
        local layouts = {}
        for _, layout in ipairs(info.layouts) do
            if layout.layoutType ~= PRESET then
                layouts[#layouts + 1] = layout
            end
        end
        saved.layouts = layouts
        calls[#calls + 1] = "save"
    end,
    OnLayoutAdded = function(index, activate, imported)
        assert(activate and imported)
        saved.activeLayout = index
        calls[#calls + 1] = "added " .. index
    end,
    SetActiveLayout = function(index)
        saved.activeLayout = index
        calls[#calls + 1] = "active " .. index
    end,
}

local messages = {}
local db = { char = {}, global = {} }
local function newModule(_, _, module)
    module.events = {}
    function module:RegisterEvent(event, handler)
        self.events[event] = handler
    end
    function module:UnregisterAllEvents()
        self.events = {}
    end
    return module
end
local app = {
    db = db,
    defaultLayoutString = "EXPORT",
    addon = { NewModule = newModule },
    logger = {
        info = function(_, text)
            messages[#messages + 1] = text
        end,
        warn = function(_, text)
            messages[#messages + 1] = "warn: " .. text
        end,
    },
}
assert(loadfile("Seamless/src/core/defaultlayout.lua"))("Seamless", app)
local module = app.defaultLayout

local function login()
    db.char = {}
    module:OnEnable()
    flush()
end

-- First character on a preset: the layout is added after the account layouts and activated.
reset({ { layoutType = ACCOUNT, layoutName = "Mine" }, { layoutType = CHARACTER, layoutName = "Alt" } }, 1)
login()
assert(saved.layouts[2].layoutName == "Seamless" and saved.layouts[2].layoutType == ACCOUNT)
assert(saved.layouts[3].layoutName == "Alt", "character layouts stay after account layouts")
assert(calls[1] == "save" and calls[2] == "added 4" and saved.activeLayout == 4)
assert(db.char.defaultLayoutChecked and db.global.defaultLayoutCreated)
assert(next(module.events) == nil)

-- Checked characters are left alone.
saved.activeLayout = 2
calls = {}
module:OnEnable()
flush()
assert(#calls == 0)

-- Another character on a preset switches to the existing layout.
login()
assert(#calls == 1 and calls[1] == "active 4")

-- A character on its own layout keeps it.
reset({ { layoutType = ACCOUNT, layoutName = "Seamless" }, { layoutType = CHARACTER, layoutName = "Alt" } }, 4)
login()
assert(#calls == 0 and db.char.defaultLayoutChecked)

-- Deleted after creation: not added again on login, but the options button restores it.
reset({}, 1)
login()
assert(#calls == 0)
assert(module:Use())
assert(saved.layouts[1].layoutName == "Seamless" and calls[2] == "added 3")
assert(module:Use(), "already active")
assert(#calls == 2)

-- Combat and Edit Mode postpone the first-login check.
db.global = {}
reset({}, 1)
combat = true
login()
assert(#calls == 0 and not db.char.defaultLayoutChecked and module.events.PLAYER_REGEN_ENABLED)
assert(not module:Use())
combat = false
editing = true
module:Schedule()
flush()
assert(#calls == 0 and not db.char.defaultLayoutChecked)
editing = false
module:Schedule()
flush()
assert(calls[2] == "added 3")

-- Full account slots: warn and leave the layouts unchanged.
local full = {}
for i = 1, 5 do
    full[i] = { layoutType = ACCOUNT, layoutName = "Account " .. i }
end
db.global = {}
reset(full, 1)
login()
assert(#calls == 0 and messages[#messages]:find("^warn: All account layout slots"))

print("default-layout: ok")
