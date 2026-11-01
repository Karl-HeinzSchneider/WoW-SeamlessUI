-- Use real AceAddon/AceHook, including the case where Ace loaded before Seamless.
local enabled = ... ~= "off"
unpack = unpack or table.unpack
local originalXpcall = xpcall
xpcall = function(fn, handler, ...)
    local args, count = { ... }, select("#", ...)
    return originalXpcall(function()
        return fn(unpack(args, 1, count))
    end, handler)
end
local frames, timers, messages, errors = {}, {}, {}, {}
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterAllEvents()
        self.events = {}
    end
    function frame:SetScript(_, fn)
        self.callback = fn
    end
    frames[#frames + 1] = frame
    return frame
end
local loggedIn = false
IsLoggedIn = function()
    return loggedIn
end
issecurevariable = function()
    return false
end
geterrorhandler = function()
    return function(err)
        errors[#errors + 1] = err
    end
end
local now = 0
debugprofilestop = function()
    return now
end
C_Timer = {
    After = function(delay, fn)
        assert(delay == 1)
        timers[#timers + 1] = fn
    end,
}
C_AddOns = {
    GetAddOnDependencies = function(name)
        if name == "SeamlessChat" then
            return "OtherDependency", "Seamless"
        end
    end,
}
local function fire(event, name)
    for _, frame in ipairs(frames) do
        if frame.events[event] then
            frame.callback(frame, event, name)
        end
    end
end
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/AceAddon-3.0/AceAddon-3.0.lua")
dofile("Seamless/lib/AceHook-3.0/AceHook-3.0.lua")
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
LibStub:NewLibrary("AceLocale-3.0", 1).GetLocale = function()
    return L
end
local ace = LibStub("AceAddon-3.0")
local dispatcher = ace.InitializeAddon
local core = ace:NewAddon("Seamless")
local app = {
    addon = core,
    logger = {
        chat = function(_, fmt, ...)
            messages[#messages + 1] = fmt:format(...)
        end,
    },
}
local coreModule = core:NewModule("Options")
function coreModule:OnInitialize()
    now = now + 3
end
function core:GetOptionsDefaults(value)
    now = now + 2
    return value
end
function core:OnInitialize()
    assert(self:GetOptionsDefaults(42) == 42)
end
local untouched = coreModule.OnInitialize
-- Deliberately absent until after file load: bootstrap must not read SavedVariables early.
assert(loadfile("Seamless/src/core/profiler.lua"))("Seamless", app)
SeamlessDB = enabled and { global = { performanceProfiling = true } } or nil
fire("ADDON_LOADED", "Seamless")
assert(#errors == 0, errors[1])
assert(app.profiler.enabled == enabled)
if not enabled then
    assert(ace.InitializeAddon == dispatcher, "Disabled mode must not hook shared dispatch")
    assert(coreModule.OnInitialize == untouched, "Disabled mode must not wrap callbacks")
    assert(#frames == 1 and #timers == 0 and #app.profiler.records == 0)
    app.profiler:Report()
    assert(messages[1]:find("then /reload", 1, true))
    print("PASS: disabled profiler leaves dispatch and callbacks untouched")
    return
end
assert(coreModule.OnInitialize ~= untouched)
local feature = ace:NewAddon("SeamlessChat")
local child = feature:NewModule("History")
local unrelated = ace:NewAddon("Unrelated")
local marker = {}
function child:Refresh(...)
    assert(select("#", ...) == 3)
    local first, middle, last = ...
    assert(first == marker and middle == nil and last == false)
    now = now + 5
    return marker, nil, false, nil
end
function feature:RefreshProfile()
    now = now + 2
    return child:Refresh(marker, nil, false)
end
function feature:OnInitialize()
    self:RefreshProfile()
end
function feature:OnEnable()
    now = now + 1
end
function child:ApplySettings()
    now = now + 4
    error(marker, 0)
end
function unrelated:OnInitialize() end
local unrelatedInitialize = unrelated.OnInitialize
fire("ADDON_LOADED", "SeamlessChat")
assert(#errors == 0, errors[1])
assert(unrelated.OnInitialize == unrelatedInitialize, "Other addons must not be instrumented")
local function pack(...)
    return select("#", ...), { ... }
end
local count, values = pack(feature:RefreshProfile())
assert(count == 4 and values[1] == marker and values[2] == nil and values[3] == false and values[4] == nil)
local ok, err = pcall(child.ApplySettings, child)
assert(not ok and err == marker, "Errors must propagate unchanged")
local rows = {}
for _, row in ipairs(app.profiler.records) do
    assert(not rows[row.name], "Callbacks must not be wrapped twice")
    rows[row.name] = row
end
assert(rows["Seamless:OnInitialize"].total == 2)
assert(rows["Seamless:GetOptionsDefaults"].total == 2)
assert(rows["Seamless/Options:OnInitialize"].total == 3)
assert(rows["SeamlessChat:OnInitialize"].total == 7)
assert(rows["SeamlessChat:RefreshProfile"].total == 14)
assert(rows["SeamlessChat/History:Refresh"].calls == 2, tostring(rows["SeamlessChat/History:Refresh"].calls))
assert(rows["SeamlessChat/History:Refresh"].maximum == 5)
assert(rows["SeamlessChat/History:ApplySettings"].total == 4)
-- Repeated initialization dispatch does not rewrap already registered callbacks.
ace:InitializeAddon(feature)
local history = rows["SeamlessChat/History:Refresh"]
assert(history.calls == 3)
loggedIn = true
fire("PLAYER_LOGIN")
assert(rows["SeamlessChat:OnEnable"].total == 1)
fire("PLAYER_ENTERING_WORLD")
fire("PLAYER_ENTERING_WORLD")
assert(#timers == 1 and #messages == 0, "One startup report, no per-call chat spam")
timers[1]()
assert(messages[1]:find("inclusive times overlap", 1, true))
assert(messages[2]:find("SeamlessChat:RefreshProfile", 1, true), "Report must sort by cumulative time")
local previous = #messages
app.profiler:Report()
assert(#messages == previous * 2, "Manual report retains the session measurements")
-- Modules created during initialization are discovered at their own initialization dispatch.
local late = feature:NewModule("Late")
function late:OnInitialize()
    now = now + 6
end
fire("ADDON_LOADED", "SeamlessChat")
local foundLate = false
for _, row in ipairs(app.profiler.records) do
    if row.name == "SeamlessChat/Late:OnInitialize" then
        foundLate = row.total == 6 and row.calls == 1
    end
end
assert(foundLate, "Late-created modules must be discovered")
for i = 1, 25 do
    app.profiler.records[#app.profiler.records + 1] = { name = "Extra" .. i, calls = 1, total = 1, maximum = 1 }
end
previous = #messages
app.profiler:Report()
assert(#messages == previous + 21, "Reports must be capped at twenty timing rows")
print("PASS: lifecycle discovery, inclusive timings, nil returns, errors, isolation and reporting")
