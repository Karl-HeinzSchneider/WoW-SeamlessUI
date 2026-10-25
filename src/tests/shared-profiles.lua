-- Exercise the real AceDB implementation, including namespace propagation and serialization.
unpack = unpack or table.unpack
securecallfunction = function(fn, ...)
    return fn(...)
end
GetRealmName = function()
    return "Realm"
end
UnitName = function()
    return "Player"
end
UnitClass = function()
    return "Mage", "MAGE"
end
UnitRace = function()
    return "Human", "Human"
end
UnitFactionGroup = function()
    return "Alliance"
end
GetLocale = function()
    return "enUS"
end
GetCurrentRegion = function()
    return 3
end
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
geterrorhandler = function()
    return error
end
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("Seamless/lib/AceDB-3.0/AceDB-3.0.lua")
local AceDB = LibStub("AceDB-3.0")
local core = { db = AceDB:New({}, { profile = { coreSetting = true } }, true) }
assert(loadfile("Seamless/src/core/profiles.lua"))("Seamless", { addon = core })
local defaults = { profile = { value = 10 }, char = {}, global = {} }
LegacyTestDB = {
    profileKeys = { ["Player - Realm"] = "Custom" },
    profiles = { Default = { value = 20 }, Custom = { value = 42 }, Other = { value = 99 } },
    char = { ["Player - Realm"] = { history = { "saved" } } },
    global = { restoredCVar = "old" },
}
local count = 0
local owner = {
    Refresh = function()
        count = count + 1
    end,
}
local feature = core:RegisterAddonDatabase("Feature", defaults, owner, "Refresh", "LegacyTestDB")
local second = core:RegisterAddonDatabase("Second", defaults, { Refresh = function() end }, "Refresh")
assert(feature.parent == core.db and second.parent == core.db)
assert(feature.profile.value == 42 and feature.profiles.Custom.value == 42)
assert(feature.profiles["Feature/Default"].value == 20, "Same-named legacy profiles must survive migration")
assert(feature.char.history[1] == "saved" and feature.global.restoredCVar == "old")
feature.char.history[1] = "updated"
assert(LegacyTestDB.char["Player - Realm"].history[1] == "saved", "Migration must deep copy")
assert(core.db.profiles.Other, "Imported profiles must be selectable in the parent")
-- Parent callbacks must observe every namespace in its final state.
owner.Refresh = function()
    assert(feature.keys.profile == core.db:GetCurrentProfile())
    assert(second.keys.profile == core.db:GetCurrentProfile())
    count = count + 1
end
core.db:SetProfile("Other")
assert(count == 1 and feature.profile.value == 99 and second.profile.value == 10)
second.profile.value = 77
core.db:SetProfile("New")
core.db:CopyProfile("Other")
assert(count == 3 and feature.profile.value == 99 and second.profile.value == 77)
core.db:ResetProfile()
assert(count == 4 and feature.profile.value == 10 and second.profile.value == 10)
assert(feature.char.history[1] == "updated", "Profile operations must preserve character data")
core.db:SetProfile("Default")
assert(feature.profile.value == 42)
-- Registering again after reload must not import stale standalone settings over shared settings.
local saved = core.db.sv
feature.profile.value = 55
core.db = AceDB:New(saved, { profile = { coreSetting = true } }, true)
feature = core:RegisterAddonDatabase("Feature", defaults, {}, "Unused", "LegacyTestDB")
assert(feature.profile.value == 55)
-- Real addon defaults, including dynamically inherited frame/group values.
for _, name in ipairs({ "ActionBars", "Castbar", "Chat", "DamageMeter", "Darkmode", "Tooltip", "UI", "Unitframes" }) do
    local app = {}
    local folder = "Seamless" .. name
    local file = (name == "Chat" or name == "Tooltip" or name == "UI" or name == "Unitframes") and "src/core/db.lua"
        or "src/db.lua"
    assert(loadfile(folder .. "/" .. file))(folder, app)
    dofile("src/tests/settings-support.lua").defaults(folder, app)
    assert(type(app.dbDefaults.profile) == "table", folder .. " needs explicit defaults")
end
print("PASS: shared profiles, migration, copy/reset, character data and reload")
