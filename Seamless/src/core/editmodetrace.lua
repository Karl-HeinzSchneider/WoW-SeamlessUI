---@type string, SeamlessCore
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local addon = app.addon
local targets, installed = {}, {}
local rows, lastReport
local armed, started, waiting, duration, firstFrame, worstFrame
local observer = CreateFrame("Frame")
observer:Hide()

-- Only addon-owned Lua tables are instrumented. Never replace native frame methods.
function addon:RegisterEditModeTraceTarget(label, target, methods)
    targets[#targets + 1] = { label = label, target = target, methods = methods }
end

local function Restore()
    for index = #installed, 1, -1 do
        local entry = installed[index]
        if entry.target[entry.key] == entry.wrapper then
            entry.target[entry.key] = entry.own
        end
    end
    installed = {}
    armed = false
    observer:Hide()
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function Install(label, target, key)
    local original = target[key]
    if type(original) ~= "function" then
        return
    end
    -- A target can be registered explicitly and also discovered as an Ace module.
    for _, entry in ipairs(installed) do
        if entry.target == target and entry.key == key then
            return
        end
    end
    local row = { label = label .. "." .. key, calls = 0, total = 0, maximum = 0 }
    rows[#rows + 1] = row
    local function wrapper(...)
        local manager = EditModeManagerFrame
        if not armed or not manager or not manager:IsEditModeActive() then
            return original(...)
        end
        local before = debugprofilestop()
        local result = Pack(pcall(original, ...))
        local elapsed = debugprofilestop() - before
        row.calls = row.calls + 1
        row.total = row.total + elapsed
        row.maximum = math.max(row.maximum, elapsed)
        if not result[1] then
            Restore()
            error(result[2], 0)
        end
        return unpack(result, 2, result.n)
    end
    installed[#installed + 1] = { target = target, key = key, own = rawget(target, key), wrapper = wrapper }
    target[key] = wrapper
end

local function Report()
    if not lastReport then
        app.logger:chat(L["No Edit Mode trace has been captured."])
        return
    end
    app.logger:chat(
        L["Edit Mode trace: first observed frame %.1f ms; worst frame %.1f ms; capture %.1f ms."],
        lastReport.first,
        lastReport.worst,
        lastReport.duration
    )
    app.logger:chat(
        L["Inclusive Lua timings overlap; do not add them together. Frame times also include native and rendering work."]
    )
    for index = 1, math.min(15, #lastReport.rows) do
        local row = lastReport.rows[index]
        app.logger:chat(
            L["%s: %d calls, %.2f ms total, %.2f ms longest."],
            row.label,
            row.calls,
            row.total,
            row.maximum
        )
    end
end

observer:SetScript("OnUpdate", function(_, elapsed)
    waiting = waiting + elapsed
    local manager = EditModeManagerFrame
    local active = manager and manager:IsEditModeActive()
    if not started and active then
        started = true
        firstFrame = elapsed * 1000
    end
    if started then
        duration = duration + elapsed
        worstFrame = math.max(worstFrame, elapsed * 1000)
        if duration >= 0.75 or not active then
            Restore()
            local captured = {}
            for _, row in ipairs(rows) do
                if row.calls > 0 then
                    captured[#captured + 1] = row
                end
            end
            table.sort(captured, function(a, b)
                if a.total == b.total then
                    return a.label < b.label
                end
                return a.total > b.total
            end)
            lastReport = { first = firstFrame, worst = worstFrame, duration = duration * 1000, rows = captured }
            Report()
        end
    elseif waiting >= 60 then
        Restore()
        app.logger:chat(L["Edit Mode trace cancelled: Edit Mode was not opened within 60 seconds."])
    end
end)

function addon:OnEditModeTraceCommand(command)
    if command == "report" then
        Report()
        return
    end
    Restore()
    if command == "off" then
        app.logger:chat(L["Edit Mode trace stopped."])
        return
    end
    if command and command ~= "" then
        app.logger:chat(L["Commands: /seamless trace, /seamless trace report, /seamless trace off"])
        return
    end
    local manager = EditModeManagerFrame
    if InCombatLockdown() or manager and manager:IsEditModeActive() then
        app.logger:chat(L["Close Edit Mode and leave combat before arming the trace."])
        return
    end
    rows = {}
    started, waiting, duration, firstFrame, worstFrame = false, 0, 0, 0, 0
    local methods = { "Refresh", "RefreshPanel", "Apply", "ApplyAll", "ApplyPreview", "Changed", "OnProfileRefresh" }
    for name, owner in LibStub("AceAddon-3.0"):IterateAddons() do
        if name == appName or name:sub(1, #appName) == appName then
            for moduleName, module in owner:IterateModules() do
                for _, key in ipairs(methods) do
                    Install(name .. "." .. moduleName, module, key)
                end
            end
        end
    end
    for _, key in ipairs({ "RefreshEditModeOptions", "RefreshEditModeSystemOptions", "RefreshOptions", "RefreshConfig" }) do
        Install(appName, addon, key)
    end
    for _, spec in ipairs(targets) do
        for _, key in ipairs(spec.methods) do
            Install(spec.label, spec.target, key)
        end
    end
    armed = true
    observer:Show()
    app.logger:chat(L["Edit Mode trace armed. Open Edit Mode within 60 seconds; a report follows automatically."])
end

addon:RegisterEditModeTraceTarget(
    "Core.FramePosition",
    app.framePosition,
    { "GetAnchorFrames", "IsValidAnchorTarget", "Read" }
)
addon:RegisterEditModeTraceTarget("Core.LibEditMode", app.LibEditMode, { "RefreshFrameSettings" })
