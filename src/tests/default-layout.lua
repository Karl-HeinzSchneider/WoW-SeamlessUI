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
    IsValidLayoutName = function(name)
        return name ~= ""
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
        debug = function(_, text)
            messages[#messages + 1] = "debug: " .. text
        end,
    },
}
assert(loadfile("Seamless/src/core/defaultlayout.lua"))("Seamless", app)
local module = app.defaultLayout

local NAME = "SeamlessUI (Preset)"
local function login()
    module:OnEnable()
    flush()
end

-- Missing on a character with its own layout: added after the account layouts, then the
-- character's layout (shifted by one) is selected again.
reset({ { layoutType = ACCOUNT, layoutName = "Mine" }, { layoutType = CHARACTER, layoutName = "Alt" } }, 4)
login()
assert(saved.layouts[2].layoutName == NAME and saved.layouts[2].layoutType == ACCOUNT)
assert(saved.layouts[3].layoutName == "Alt", "character layouts stay after account layouts")
assert(calls[1] == "save" and calls[2] == "added 4" and calls[3] == "active 5")
assert(saved.activeLayout == 5, "the character keeps its layout")
assert(next(module.events) == nil)

-- On a preset: added, the preset stays active.
reset({}, 2)
login()
assert(saved.layouts[1].layoutName == NAME and calls[2] == "added 3" and saved.activeLayout == 2)

-- Present: nothing changes, also on later logins.
calls = {}
login()
assert(#calls == 0)

-- Deleted: added again on the next login.
reset({ { layoutType = CHARACTER, layoutName = "Alt" } }, 3)
login()
assert(saved.layouts[1].layoutName == NAME and calls[2] == "added 3" and saved.activeLayout == 4)

-- The options button switches to it, adding it if needed.
reset({}, 1)
assert(module:Use())
assert(saved.layouts[1].layoutName == NAME and calls[2] == "added 3" and #calls == 2)
assert(saved.activeLayout == 3)
saved.activeLayout = 1
assert(module:Use())
assert(calls[3] == "active 3")
assert(module:Use(), "already active")
assert(#calls == 3)

-- Combat and Edit Mode postpone the check.
reset({}, 1)
combat = true
login()
assert(#calls == 0 and module.events.PLAYER_REGEN_ENABLED)
assert(not module:Use())
combat = false
editing = true
module:Schedule()
flush()
assert(#calls == 0)
editing = false
module:Schedule()
flush()
assert(calls[2] == "added 3")

-- Full account slots: no layout change; only the options button warns.
local full = {}
for i = 1, 5 do
    full[i] = { layoutType = ACCOUNT, layoutName = "Account " .. i }
end
reset(full, 1)
login()
assert(#calls == 0 and messages[#messages]:find("^debug: All account layout slots"))
local ok, err = module:Use()
assert(not ok and err:find("^All account layout slots"))

print("default-layout: ok")
