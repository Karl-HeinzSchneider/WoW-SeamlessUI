-- Run from the repository root: lua src/tests/editmode-loading.lua
-- Load the actual vendored library and every widget in two independent namespaces.
LibStub = function()
    error("Namespaced LibEditMode must never use LibStub")
end
EventRegistry = { RegisterCallback = function() end, RegisterFrameEventAndCallback = function() end }
EditModeManagerFrame = { HookScript = function() end }
EditModeSystemSettingsDialog = { HookScript = function() end }
function hooksecurefunc() end
Enum = { EditModeSettingDisplayType = { Checkbox = 1, Slider = 2, Dropdown = 3, Divider = 4, Expander = 5 } }
function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end
function CreateUnsecuredObjectPool()
    return {
        Acquire = function()
            error("No widgets should be acquired during load")
        end,
    }
end
local function loadLibrary()
    local ns = {}
    assert(loadfile("Seamless/lib/LibEditMode/namespaced.lua"))("Seamless", ns)
    local embed = assert(io.open("Seamless/lib/LibEditMode/embed.xml")):read("*a")
    for path in embed:gmatch("file='([^']+)'") do
        assert(loadfile("Seamless/lib/LibEditMode/" .. path:gsub("\\", "/")))("Seamless", ns)
    end
    assert(type(ns.LibEditMode.AddFrame) == "function")
    assert(type(ns.LibEditMode.AddFrameSettings) == "function")
    assert(type(ns.LibEditMode.internal.CreateDialog) == "function")
    return ns
end
local embedsFile = assert(io.open("Seamless/embeds.xml"))
local embeds = embedsFile:read("*a")
embedsFile:close()
local namespacedOffset = assert(embeds:find("lib\\LibEditMode\\namespaced.lua", 1, true))
local embedOffset = assert(embeds:find("lib\\LibEditMode\\embed.xml", 1, true))
assert(namespacedOffset < embedOffset, "Namespaced bootstrap must load before the library")
local suite, other = loadLibrary(), loadLibrary()
assert(suite.LibEditMode ~= other.LibEditMode)
assert(suite.LibEditMode.internal ~= other.LibEditMode.internal)
suite.LibEditMode:RegisterCallback("enter", function() end)
assert(#suite.LibEditMode.anonCallbacksEnter == 1 and #other.LibEditMode.anonCallbacksEnter == 0)
local registeredAddon
LibStub = function(name)
    assert(name == "AceAddon-3.0")
    return {
        NewAddon = function(_, addon)
            registeredAddon = addon
        end,
    }
end
suite.logger = {}
assert(loadfile("Seamless/src/core/ace.lua"))("Seamless", suite)
assert(registeredAddon:GetEditModeLibrary() == suite.LibEditMode)
print("PASS: namespaced embed/widgets, isolated instances, and Core accessor")
