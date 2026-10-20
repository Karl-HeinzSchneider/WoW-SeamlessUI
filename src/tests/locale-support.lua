-- Load the real English catalogue alongside each harness's other library mocks.
local previousStub, previousLocale = LibStub, GetLocale
LibStub = nil
GetLocale = function()
    return "enUS"
end
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/AceLocale-3.0/AceLocale-3.0.lua")
dofile("Seamless/locales/enUS.lua")
local aceLocale = LibStub("AceLocale-3.0")
GetLocale = previousLocale
LibStub = function(name, ...)
    if name == "AceLocale-3.0" then
        return aceLocale
    end
    assert(previousStub, "Unexpected library: " .. name)
    return previousStub(name, ...)
end
