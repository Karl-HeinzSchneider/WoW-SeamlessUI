-- Run from the repository root: lua src/tests/editmode-trace.lua
unpack = unpack or table.unpack
local active, combat, clock = false, false, 0
local messages, frames = {}, {}
local function object()
    local frame = { scripts = {} }
    function frame:Show()
        self.shown = true
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:SetScript(key, callback)
        self.scripts[key] = callback
    end
    frames[#frames + 1] = frame
    return frame
end
CreateFrame = object
debugprofilestop = function()
    return clock
end
InCombatLockdown = function()
    return combat
end
EditModeManagerFrame = {
    IsEditModeActive = function()
        return active
    end,
}
local addon = {}
local module = {}
local original = function(_, fail)
    clock = clock + 12
    if fail then
        error("trace test error", 0)
    end
    return false, nil, "tail", nil
end
module.Refresh = original
local inherited = {
    Apply = function()
        clock = clock + 3
    end,
}
local mover = setmetatable({}, { __index = inherited })
function addon:IterateModules()
    return pairs({ Example = module })
end
local unrelated = {
    IterateModules = function()
        error("unrelated addons must not be inspected")
    end,
}
local ace = {
    IterateAddons = function()
        return pairs({ Seamless = addon, OtherAddon = unrelated })
    end,
}
LibStub = function(name)
    if name == "AceAddon-3.0" then
        return ace
    end
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
local app = {
    addon = addon,
    framePosition = {},
    LibEditMode = {},
    logger = {
        chat = function(_, fmt, ...)
            messages[#messages + 1] = string.format(fmt, ...)
        end,
    },
}
assert(loadfile("Seamless/src/core/editmodetrace.lua"))("Seamless", app)
addon:RegisterEditModeTraceTarget("Example.Mover", mover, { "Apply" })
-- Duplicate registration must not double-count or leave wrappers installed.
addon:RegisterEditModeTraceTarget("Example.Mover", mover, { "Apply" })
local observer = frames[1]
local function tick(elapsed)
    if observer.shown then
        observer.scripts.OnUpdate(observer, elapsed)
    end
end
assert(module.Refresh == original and not observer.shown, "inactive by default")
addon:OnEditModeTraceCommand("report")
assert(messages[#messages]:find("No Edit Mode trace", 1, true))
addon:OnEditModeTraceCommand("")
assert(module.Refresh ~= original and observer.shown)
module:Refresh() -- Outside Edit Mode: not counted.
local function verifyReturns(...)
    assert(select("#", ...) == 4, "trailing nil returns must survive")
    local first, second, third, fourth = ...
    assert(first == false and second == nil and third == "tail" and fourth == nil)
end
active = true
verifyReturns(module:Refresh())
mover:Apply()
tick(0.1)
tick(0.7)
assert(not observer.shown and module.Refresh == original)
assert(rawget(mover, "Apply") == nil and mover.Apply == inherited.Apply, "restore inherited methods")
local report = table.concat(messages, "\n")
assert(report:find("Seamless.Example.Refresh: 1 calls, 12.00 ms total", 1, true))
assert(report:find("Example.Mover.Apply: 1 calls, 3.00 ms total", 1, true))
assert(report:find("Covered Lua: 15.00 ms total", 1, true))
assert(report:find("first observed frame 100.0 ms; worst frame 700.0 ms", 1, true))
addon:OnEditModeTraceCommand("report")
assert(messages[#messages]:find("Example.Mover.Apply", 1, true))
active = false
local nested = {}
function nested:Inner()
    clock = clock + 3
end
function nested:Outer()
    self:Inner()
    clock = clock + 2
end
addon:RegisterEditModeTraceTarget("Nested", nested, { "Inner", "Outer" })
addon:OnEditModeTraceCommand("")
active = true
nested:Outer()
tick(0.8)
report = table.concat(messages, "\n")
assert(report:find("Nested.Outer: 1 calls, 5.00 ms total", 1, true), "parent timing is inclusive")
assert(report:find("Nested.Inner: 1 calls, 3.00 ms total", 1, true))
assert(report:find("Covered Lua: 5.00 ms total", 1, true), "nested timings must only count once in coverage total")
active = false
addon:OnEditModeTraceCommand("")
tick(60)
assert(module.Refresh == original and not observer.shown, "timeout restores wrappers")
addon:OnEditModeTraceCommand("")
addon:OnEditModeTraceCommand("off")
assert(module.Refresh == original and not observer.shown, "cancel restores wrappers")
combat = true
addon:OnEditModeTraceCommand("")
assert(module.Refresh == original and not observer.shown, "combat guard")
combat = false
active = true
addon:OnEditModeTraceCommand("")
assert(module.Refresh == original and not observer.shown, "already-open guard")
active = false
addon:OnEditModeTraceCommand("")
active = true
local ok, failure = pcall(module.Refresh, module, true)
assert(not ok and failure == "trace test error", "errors must propagate unchanged")
assert(module.Refresh == original and not observer.shown, "error restores wrappers")
print("PASS: Edit Mode trace timing, return values, restoration, guards and error propagation")
