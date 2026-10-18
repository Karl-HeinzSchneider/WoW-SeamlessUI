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
local extras = false
function UnitExists(unit)
    return unit == "target"
        or unit == "player"
        or unit:match("^party%d$")
        or unit:match("^raid%d$")
        or (
            extras
            and (
                unit == "pet"
                or unit == "partypet1"
                or unit == "raidpet1"
                or unit == "nameplate1"
                or unit == "nameplate2"
                or unit == "focus"
                or unit == "mouseover"
            )
        )
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
function UnitIsUnit(unit, other)
    local aliases = { nameplate1 = "pet", raid1 = "player" }
    return (aliases[unit] or unit) == (aliases[other] or other)
end
function UnitDetailedThreatSituation(unit, target)
    assert(target == "target")
    calls = calls + 1
    if restricted then
        return secret, secret, secret, secret, secret
    end
    if unit == "focus" then
        error("Unavailable optional unit")
    end
    if unit == "mouseover" then
        return
    end
    if unit == "pet" or unit == "partypet1" or unit == "raidpet1" or unit == "nameplate2" then
        return false, 0, 75, 80, 30
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
extras = true
session = service:GetSession(config, "Threat")
assert(#session.combatSources == 6, "Pets and discoverable guardians are included without duplicate aliases")
local petCount = 0
for _, source in ipairs(session.combatSources) do
    if source.isPet then
        petCount = petCount + 1
    end
end
assert(petCount == 3)
service:BeginRefresh()
raid = true
session = service:GetSession(config, "Threat")
assert(#session.combatSources == 6, "Raid pets and other accessible actors are included")
extras = false
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
print("Damage meter threat tests passed")

local events, timers = {}, {}
local addon = {}
function LibStub()
    return {
        GetAddon = function()
            return {}
        end,
        NewAddon = function()
            return addon
        end,
    }
end
function addon:RegisterEvent(event, callback)
    events[event] = callback
end
function addon:ScheduleRepeatingTimer(callback, interval)
    timers[interval] = callback
end
assert(loadfile("SeamlessDamageMeter/src/core.lua"))("test", app)
function addon:RefreshProfile() end
function app:IsAvailable()
    return false
end
function service:OnWorld() end
local refreshes = 0
function app:RefreshThreatWindows()
    refreshes = refreshes + 1
end
addon:OnEnable()
assert(events.UNIT_THREAT_LIST_UPDATE and events.UNIT_THREAT_SITUATION_UPDATE)
assert(events.PLAYER_TARGET_CHANGED and events.UNIT_PET and events.GROUP_ROSTER_UPDATE)
assert(events.NAME_PLATE_UNIT_ADDED and events.NAME_PLATE_UNIT_REMOVED)
events.UNIT_THREAT_LIST_UPDATE("UNIT_THREAT_LIST_UPDATE", secret)
events.UNIT_THREAT_SITUATION_UPDATE("UNIT_THREAT_SITUATION_UPDATE", secret)
events.PLAYER_TARGET_CHANGED()
assert(refreshes == 3, "Threat and target events refresh immediately without examining restricted payloads")
function app:RefreshWindows(skipThreat)
    assert(skipThreat == true)
end
addon[timers[0.5]](addon)
assert(refreshes == 3, "The rate timer does not poll threat")
print("Damage meter threat event regressions OK")
