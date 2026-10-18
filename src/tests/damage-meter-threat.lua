-- Run from the repository root: lua src/tests/damage-meter-threat.lua
local app = { archive = {} }
local secret = setmetatable({}, {
    __lt = function()
        error("Secret comparison")
    end,
    __eq = function()
        error("Secret equality")
    end,
})
function app.archive:IsPublic(value)
    return not rawequal(value, secret)
end
local raid, hostile, restricted, calls = false, true, false, 0
function UnitExists()
    return true
end
function UnitCanAttack()
    return hostile
end
function UnitIsPlayer()
    return false
end
function IsInRaid()
    return raid
end
function GetNumGroupMembers()
    return 3
end
function GetNumSubgroupMembers()
    return 2
end
function UnitClass()
    return "Warrior", "WARRIOR"
end
function GetUnitName(unit)
    return unit
end
function UnitIsUnit(unit)
    return unit == "player" or unit == "raid1"
end
function UnitDetailedThreatSituation(unit, target)
    assert(target == "target")
    calls = calls + 1
    if restricted then
        return secret, secret, secret, secret, secret
    end
    if unit == "party2" or unit == "raid3" then
        return
    end
    return false, 0, 50, 60, unit == "player" and 10 or 20
end
assert(loadfile("SeamlessDamageMeter/src/live.lua"))("test", app)
assert(loadfile("SeamlessDamageMeter/src/data.lua"))("test", app)
assert(loadfile("SeamlessDamageMeter/src/service.lua"))("test", app)
local service = app.combatService
local config = { statistic = "Threat", archiveID = 123, session = "Overall" }
local session = service:GetSession(config, "Threat")
assert(#session.combatSources == 3)
assert(session.combatSources[1].name == "party1")
assert(session.combatSources[2].isLocalPlayer)
assert(session.combatSources[3].totalAmount == 0)
assert(session.combatSources[1].threatPercentage == 50)
assert(service:GetSession(config, "Threat") == session and calls == 3)
assert(service:GetDuration(config, session) == nil)
service:BeginRefresh()
raid, restricted = true, true
session = service:GetSession(config, "Threat")
assert(#session.combatSources == 3 and session.combatSources[1].name == "raid1")
assert(rawequal(session.combatSources[1].totalAmount, secret))
assert(rawequal(session.combatSources[1].threatPercentage, secret))
service:BeginRefresh()
hostile = false
local missing, message = service:GetSession(config, "Threat")
assert(#missing.combatSources == 0 and message == nil)
assert(missing.targetName == "target")
service:BeginRefresh()
function UnitExists()
    return false
end
session, message = service:GetSession(config, "Threat")
assert(#session.combatSources == 0 and session.targetName == nil and message == nil)
function app:IsEditingWindows()
    return true
end
session = service:GetSession(config, "Threat")
assert(session.isPreview and session.combatSources[1].threatPercentage == 100)
assert(calls == 6)
print("Damage meter threat tests passed")
