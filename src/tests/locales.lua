-- Run from the repository root: lua src/tests/locales.lua
local locales = { "enUS", "enGB", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
for _, locale in ipairs(locales) do
    LibStub = nil
    GetLocale = function()
        return locale
    end
    geterrorhandler = function()
        return function(message)
            error(message)
        end
    end
    dofile("Seamless/lib/LibStub/LibStub.lua")
    dofile("Seamless/lib/AceLocale-3.0/AceLocale-3.0.lua")
    dofile("Seamless/locales/enUS.lua")
    dofile("Seamless/locales/" .. locale .. "/strings.lua")
    local ace = LibStub("AceLocale-3.0")
    local L = ace:GetLocale("Seamless")
    assert(L.Open == "Open" and L.Default == "Default" and L.Player == "Player")
    assert(L["Current (short)"] == "C")
    local matching = locale == "enGB" and "enUS" or locale
    local translation = ace:NewLocale("Seamless", matching)
    translation.Open = "translated"
    assert(L.Open == "translated" and L.Default == "Default", "Translation/fallback failed: " .. locale)
    local other = ace:NewLocale("Seamless", matching == "deDE" and "frFR" or "deDE")
    assert(other == nil, "Non-client locale registered: " .. locale)
end
print("PASS: all client locale files, real AceLocale guards, shared table, English fallback and enGB normalization")
