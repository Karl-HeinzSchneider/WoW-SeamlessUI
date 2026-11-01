---@type string, SeamlessCore
local appName, app = ...

-- Only suite-owned callbacks are timed. Never wrap Blizzard functions or frame scripts.
---@class SeamlessCore.Profiler : AceHook-3.0
local profiler = { enabled = false, records = {} }
app.profiler = profiler

local methods =
    { "OnInitialize", "OnEnable", "OnDisable", "OnProfileRefresh", "RefreshProfile", "Refresh", "ApplySettings" }
local services = { "GetOptionsDefaults", "RegisterAddonDatabase", "RegisterOptions" }
local wrapped = setmetatable({}, { __mode = "k" })

local function finish(record, started, ok, ...)
    local elapsed = debugprofilestop() - started
    record.calls = record.calls + 1
    record.total = record.total + elapsed
    record.maximum = math.max(record.maximum, elapsed)
    if not ok then
        error((...), 0)
    end
    return ...
end

local function wrap(owner, method, name)
    local original = owner[method]
    if type(original) ~= "function" then
        return
    end
    wrapped[owner] = wrapped[owner] or {}
    if wrapped[owner][method] then
        return
    end
    wrapped[owner][method] = true
    local record = { name = name .. ":" .. method, calls = 0, total = 0, maximum = 0 }
    profiler.records[#profiler.records + 1] = record
    owner[method] = function(...)
        local started = debugprofilestop()
        return finish(record, started, pcall(original, ...))
    end
end

local function scan(owner, name)
    for _, method in ipairs(methods) do
        wrap(owner, method, name)
    end
    for key, child in owner:IterateModules() do
        scan(child, name .. "/" .. key)
    end
end

function profiler:Report()
    local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
    if not self.enabled then
        app.logger:chat(L["Enable Performance profiling in General, then /reload."])
        return
    end
    local rows = {}
    for _, record in ipairs(self.records) do
        if record.calls > 0 then
            rows[#rows + 1] = record
        end
    end
    table.sort(rows, function(a, b)
        if a.total == b.total then
            return a.name < b.name
        end
        return a.total > b.total
    end)
    app.logger:chat(
        L["Performance: top %d of %d entries since reload; inclusive times overlap."],
        math.min(20, #rows),
        #rows
    )
    for i = 1, math.min(20, #rows) do
        local row = rows[i]
        app.logger:chat(
            L["%s: %.3f ms total, %d calls, %.3f ms average, %.3f ms maximum"],
            row.name,
            row.total,
            row.calls,
            row.total / row.calls,
            row.maximum
        )
    end
end

local function watch(_, owner)
    local name = owner.name
    local root = name:match("^Seamless[^_]*")
    if not root then
        return
    end
    local ours = root == appName
    if not ours then
        for _, dependency in ipairs({ C_AddOns.GetAddOnDependencies(root) }) do
            ours = ours or dependency == appName
        end
    end
    if ours then
        scan(owner, (name:gsub("_", "/")))
    end
end

-- This one startup trampoline is the only wrapper installed when profiling is off.
-- Start from OnInitialize: SavedVariables are available, even when another addon loaded Ace first.
local initialize = app.addon.OnInitialize
app.addon.OnInitialize = function(...)
    profiler.enabled = type(SeamlessDB) == "table"
        and type(SeamlessDB.global) == "table"
        and SeamlessDB.global.performanceProfiling == true
    if not profiler.enabled then
        return initialize(...)
    end
    local record = { name = appName .. ":OnInitialize", calls = 0, total = 0, maximum = 0 }
    profiler.records[#profiler.records + 1] = record
    wrapped[app.addon] = { OnInitialize = true }
    local ace = LibStub("AceAddon-3.0")
    -- A normal AceHook pre-hook observes dispatch without changing arguments/results.
    -- Only installed when opted in; no vendor source changes or secure-function hooks.
    LibStub("AceHook-3.0"):Embed(profiler)
    profiler:Hook(ace, "InitializeAddon", watch)
    scan(app.addon, appName)
    for _, method in ipairs(services) do
        wrap(app.addon, method, appName)
    end
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        C_Timer.After(1, function()
            profiler:Report()
        end)
    end)
    local started = debugprofilestop()
    return finish(record, started, pcall(initialize, ...))
end
