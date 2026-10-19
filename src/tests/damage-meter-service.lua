-- Run from the repository root: lua src/tests/damage-meter-service.lua
unpack = unpack or table.unpack
local clock, combat, tracking, restrictedState = 0, false, true, 0
local secret = setmetatable({}, {
    __lt = function()
        error("Secret comparison")
    end,
    __add = function()
        error("Secret arithmetic")
    end,
    __concat = function()
        error("Secret concatenation")
    end,
    __tostring = function()
        error("Secret serialization")
    end,
})
function issecretvalue(value)
    return rawequal(value, secret)
end
function issecrettable(value)
    return type(value) == "table" and rawget(value, "secretTable") == true
end
function canaccesstable(value)
    return type(value) == "table" and not issecretvalue(value) and not rawget(value, "opaque")
end
function UnitGUID(unit)
    assert(unit == "player")
    return "Player-1"
end
function GetTime()
    return clock
end
function time()
    return 1700000000 + math.floor(clock)
end
function date(_, timestamp)
    return tostring(timestamp)
end
function SecondsToClock(value)
    return tostring(value)
end
function AbbreviateLargeNumbers(value)
    assert(value ~= secret)
    return tostring(value)
end
function UnitAffectingCombat()
    return combat
end
function InCombatLockdown()
    return combat
end
function GetInstanceInfo()
    return "Test dungeon", "party", 1, "Normal", 5, false, false, 33
end
C_CVar = {
    GetCVarBool = function()
        return tracking
    end,
}
Enum = {
    DamageMeterSessionType = { Overall = 0, Current = 1, Expired = 2 },
    DamageMeterType = {},
    AddOnRestrictionType = { Combat = 0 },
}
C_RestrictedActions = {
    GetAddOnRestrictionState = function()
        return restrictedState
    end,
}
local keys = {
    "DamageDone",
    "Dps",
    "HealingDone",
    "Hps",
    "Absorbs",
    "Interrupts",
    "Dispels",
    "DamageTaken",
    "AvoidableDamageTaken",
    "Deaths",
    "EnemyDamageTaken",
}
for index, key in ipairs(keys) do
    Enum.DamageMeterType[key] = index - 1
end
local sessions, details, available = {}, {}, {}
local reads, detailReads = 0, 0
local function Empty()
    return { combatSources = {}, maxAmount = 0, totalAmount = 0, durationSeconds = 10 }
end
local function Player(amount)
    return {
        sourceGUID = "Player-1",
        name = "Mage",
        classFilename = "MAGE",
        specIconID = 1,
        totalAmount = amount,
        amountPerSecond = amount / 10,
        isLocalPlayer = true,
    }
end
local function Fight(id, amount)
    local categories = {}
    for index = 0, 10 do
        categories[index] = Empty()
    end
    categories[0] =
        { combatSources = { Player(amount) }, totalAmount = amount, maxAmount = amount, durationSeconds = 10 }
    categories[1] = categories[0]
    categories[10] = {
        totalAmount = amount + 50,
        maxAmount = amount,
        durationSeconds = 10,
        combatSources = {
            { name = "Wolf", sourceCreatureID = 10, totalAmount = amount, amountPerSecond = amount / 10 },
            { name = "Wolf", sourceCreatureID = 20, totalAmount = 50, amountPerSecond = 5 },
        },
    }
    sessions[id] = categories
    details[id] = {
        player = {
            totalAmount = amount,
            maxAmount = amount,
            combatSpells = {
                {
                    spellID = 1,
                    totalAmount = amount,
                    amountPerSecond = amount / 10,
                    isAvoidable = true,
                    combatSpellDetails = { unitName = "Wolf", amount = amount },
                },
            },
        },
        [10] = {
            totalAmount = amount,
            maxAmount = amount / 2,
            combatSpells = {
                {
                    spellID = 1,
                    totalAmount = amount / 2,
                    amountPerSecond = amount / 20,
                    combatSpellDetails = { unitName = "Mage", amount = amount / 2 },
                },
                {
                    spellID = 2,
                    totalAmount = amount / 2,
                    amountPerSecond = amount / 20,
                    combatSpellDetails = { unitName = "Mage", amount = amount / 2 },
                },
            },
        },
        [20] = {
            totalAmount = 50,
            maxAmount = 50,
            combatSpells = {
                {
                    spellID = 1,
                    totalAmount = 50,
                    amountPerSecond = 5,
                    combatSpellDetails = { unitName = "Warrior", amount = 50 },
                },
            },
        },
    }
end
C_DamageMeter = {
    IsDamageMeterAvailable = function()
        return true, ""
    end,
    GetAvailableCombatSessions = function()
        return available
    end,
    GetCombatSessionFromID = function(id, kind)
        reads = reads + 1
        return sessions[id] and sessions[id][kind]
    end,
    GetCombatSessionFromType = function(_, kind)
        reads = reads + 1
        return sessions[1] and sessions[1][kind]
    end,
    GetCombatSessionSourceFromID = function(id, kind, _, creature)
        detailReads = detailReads + 1
        return kind == 10 and details[id][creature] or details[id].player
    end,
    GetCombatSessionSourceFromType = function(_, kind, _, creature)
        detailReads = detailReads + 1
        return kind == 10 and details[1][creature] or details[1].player
    end,
}
local function Load(character, apiOnly)
    local app = { db = { char = character or {}, profile = { windows = {} } } }
    for _, name in ipairs({ "data", "archive", "live", "service", "breakdowns", "capture" }) do
        assert(loadfile("SeamlessDamageMeter/src/" .. name .. ".lua"))("SeamlessDamageMeter", app)
    end
    if not apiOnly then
        app.combatService.saveSessions = true
    else
        app.db.profile.windows = { { session = "Current", archiveID = 123, sessionID = 1, sessionGeneration = 1 } }
    end
    app.combatService:Initialize(app.db.char)
    return app
end
local saved = { combatHistory = { preserved = true } }
available = { { sessionID = 42, name = "Client fight" } }
local apiOnly = Load(saved, true)
apiOnly.combatService:OnWorld()
apiOnly.combatService:OnCombatEnd()
apiOnly.combatService:OnLogout()
assert(saved.combatHistory.preserved and saved.combatHistory.fights == nil, "Existing history must stay untouched")
assert(#apiOnly.archive.db.fights == 0 and next(apiOnly.combatService.pending) == nil, "API-only mode must not capture")
assert(#apiOnly.combatService:ListSessions() == #available, "Only client sessions must be listed")
assert(apiOnly.combatService:ListSessions()[1].sessionID == 42, "Client session identity must be preserved")
assert(apiOnly.db.profile.windows[1].archiveID == nil and apiOnly.db.profile.windows[1].sessionID == nil)
available = {}
local app = Load()
local service, archive = app.combatService, app.archive
local changed = 0
service:Subscribe({}, function()
    changed = changed + 1
end)
Fight(1, 100)
available = { { sessionID = 1, name = "First fight", durationSeconds = 10 } }
local config = { session = "Current", statistic = "DamageDone" }
local session = service:GetSession(config, "DamageDone")
tracking = false
service:Invalidate()
assert(
    service:GetSession(config, "DamageDone").totalAmount == session.totalAmount,
    "Native UI off does not block API reads"
)
assert(
    app.live:GetDetails(config, session.combatSources[1], "DamageDone"),
    "Native UI off does not block spell queries"
)
tracking = true
local before = reads
assert(service:GetSession(config, "DamageDone") == session and reads == before, "Matching windows share reads")
local player = session.combatSources[1]
-- Reproduce readable API tables whose leaves become secret in combat. Such tables
-- are suitable for widgets, but must never pass the snapshot validator.
local flags = {
    session,
    player,
    details[1].player,
    details[1].player.combatSpells,
    details[1].player.combatSpells[1],
    details[1].player.combatSpells[1].combatSpellDetails,
}
for _, value in ipairs(flags) do
    value.secretTable = true
end
player.sourceGUID = secret
details[1].player.totalAmount, details[1].player.maxAmount = secret, secret
details[1].player.combatSpells[1].totalAmount, details[1].player.combatSpells[1].amountPerSecond = secret, secret
local originalGetter = C_DamageMeter.GetCombatSessionSourceFromType
local safeQueries = 0
C_DamageMeter.GetCombatSessionSourceFromType = function(kind, meterType, guid, creature)
    assert(
        guid ~= secret and (guid == "Player-1" or (guid == nil and creature == 42)),
        "Never forward a secret GUID to an addon-tainted API call"
    )
    safeQueries = safeQueries + 1
    return originalGetter(kind, meterType, guid, creature)
end
combat = true
service:Invalidate()
assert(service:GetSession(config, "DamageDone") == session, "Secret-bearing readable tables remain displayable")
local combatDetails = service:GetDetails(config, player, "DamageDone")
assert(
    not app.live:IsReadableTable({ opaque = true }) and not app.live:IsReadableTable(secret),
    "Opaque tables and secret table values are still rejected"
)
assert(
    combatDetails and combatDetails.combatSpells[1].totalAmount == secret and safeQueries == 1,
    "Local-player hover uses the public UnitGUID and returns secret amounts unchanged"
)
assert(
    not archive:CopySession(session) and not archive:CopyDetails(combatDetails),
    "Live rendering does not relax persistence"
)
player.isLocalPlayer = false
assert(
    not app.live:GetDetails(config, player, "DamageDone") and safeQueries == 1,
    "A restricted other-player identity is not guessed or sent to the API"
)
player.sourceCreatureID = 42
assert(
    app.live:GetDetails(config, player, "DamageDone") and safeQueries == 2,
    "Creature queries use the public creature ID without a secret GUID"
)
player.isLocalPlayer, player.sourceCreatureID = true, nil
-- Secret optional history metadata must not invalidate a public session ID.
available[1].name, available[1].durationSeconds, available[1].secretTable = secret, secret, true
assert(
    service:GetSession({ sessionID = 1, sessionGeneration = service.generation }, "DamageDone"),
    "History lookups retain public IDs while omitting restricted labels and duration"
)
available[1].name, available[1].durationSeconds, available[1].secretTable = "First fight", 10, nil
for _, value in ipairs(flags) do
    value.secretTable = nil
end
player.sourceGUID = "Player-1"
details[1].player.totalAmount, details[1].player.maxAmount = 100, 100
details[1].player.combatSpells[1].totalAmount, details[1].player.combatSpells[1].amountPerSecond = 100, 10
C_DamageMeter.GetCombatSessionSourceFromType = originalGetter
combat = false
service:Invalidate()
local targets = service:GetPlayerTargets(config, player)
assert(targets.complete and #targets.entries == 1 and targets.entries[1].totalAmount == 100)
assert(targets.entries[1].enemyShare == 100 and targets.entries[1].sourceCreatureID == 10)
combat = true
sessions[1][10].combatSources[1].sourceGUID = secret
details[1][10].combatSpells[1].spellID = secret
details[1][10].combatSpells[1].amountPerSecond = secret
service:Invalidate()
local liveTargets = service:GetPlayerTargets(config, player)
assert(
    liveTargets
        and liveTargets.complete
        and liveTargets.entries[1].totalAmount == 100
        and liveTargets.entries[1].amountPerSecond == nil,
    "Public target contributions can be shown during combat; optional secret IDs/rates are omitted"
)
sessions[1][10].combatSources[1].sourceGUID = nil
details[1][10].combatSpells[1].spellID, details[1][10].combatSpells[1].amountPerSecond = 1, 5
combat = false
service:Invalidate()
local enemySession = service:GetSession(config, "EnemyDamageTaken")
local contributors = service:GetEnemyContributors(config, enemySession.combatSources[1])
assert(#contributors.entries == 1 and contributors.entries[1].totalAmount == 100, "Repeated contributor rows aggregate")
assert(enemySession.combatSources[2].sourceCreatureID == 20, "Same names retain client creature identities")
local stale = Player(100)
assert(not service:GetDetails(config, stale, "DamageDone"), "Stale pooled sources are rejected")
local saved = sessions[1][0].combatSources[1].totalAmount
sessions[1][0].combatSources[1].totalAmount = secret
assert(not archive:CopySession(sessions[1][0]), "Secret totals never enter snapshots")
sessions[1][0].combatSources[1].totalAmount = saved
details[1].player.combatSpells[1].combatSpellDetails.unitName = secret
assert(not archive:CopyDetails(details[1].player), "Nested secrets never enter snapshots")
details[1].player.combatSpells[1].combatSpellDetails.unitName = "Wolf"
local secretSession = Empty()
secretSession.secretTable = true
assert(not archive:CopySession(secretSession), "Secret tables are rejected")
local copy = archive:CopySession(sessions[1][0])
copy.combatSources[1].totalAmount = 900
assert(sessions[1][0].combatSources[1].totalAmount == 100, "Snapshots own their data")
combat = true
service:OnWorld()
clock = 10
service:Tick(1000)
assert(#archive.db.fights == 0, "Active fights are never captured")
combat = false
restrictedState = 1
service:OnCombatEnd()
clock = 13
service:Tick(1000)
assert(#archive.db.fights == 0, "Server restrictions can outlive player combat")
restrictedState = 0
app.db.profile.windows[1] = { sessionID = 1, sessionGeneration = service.generation }
service:Tick(1000)
assert(#archive.db.fights == 1 and archive.db.fights[1].complete)
local firstID = archive.db.fights[1].id
assert(app.db.profile.windows[1].archiveID == firstID, "Selected live fights bind to permanent IDs")
service:OnMeterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
clock = 16
service:Tick(1000)
assert(#archive.db.fights == 1 and archive.db.fights[1].id == firstID, "Duplicate events replace rather than append")
local oldChar = app.db.char
app = Load(oldChar)
service, archive = app.combatService, app.archive
service:OnWorld()
clock = 19
service:Tick(1000)
assert(#archive.db.fights == 1, "Reload reconciles surviving client history by contents")
local archivedConfig = { archiveID = firstID, statistic = "DamageDone" }
available, tracking = {}, false
local oldAPI = C_DamageMeter
C_DamageMeter = nil
local archivedSession = service:GetSession(archivedConfig, "DamageDone")
assert(archivedSession.combatSources[1].totalAmount == 100, "Archives work without client APIs or tracking")
local archivedDetails = service:GetDetails(archivedConfig, archivedSession.combatSources[1], "DamageDone")
assert(archivedDetails.combatSpells[1].isAvoidable)
combat = true
assert(
    service:GetPlayerTargets(archivedConfig, archivedSession.combatSources[1]).complete,
    "Public archives remain analyzable during combat"
)
combat = false
C_DamageMeter, tracking = oldAPI, true
app.db.profile = { windows = {} }
assert(archive:Get(firstID), "Appearance profile changes preserve history")
Fight(1, 200)
available = { { sessionID = 1, name = "Second fight", durationSeconds = 10 } }
local oldGeneration = service.generation
service:OnMeterEvent("DAMAGE_METER_RESET")
assert(
    not service:GetSession({ sessionID = 1, sessionGeneration = oldGeneration }, "DamageDone"),
    "Reused client IDs cannot revive old selections"
)
service:OnWorld()
clock = 22
service:Tick(1000)
assert(#archive.db.fights == 2 and archive.db.fights[1].id ~= firstID, "Reused IDs create new archive identities")
local secondID = archive.db.fights[1].id
-- Capture public totals even when a detail category remains restricted, then upgrade in place.
Fight(2, 300)
available[#available + 1] = { sessionID = 2, name = "Partial", durationSeconds = 10 }
details[2].player.totalAmount = secret
service:OnWorld()
clock = 25
service:Tick(1000)
local partial = archive.db.fights[1]
assert(not partial.complete and partial.categories.DamageDone.session.totalAmount == 300)
local partialID = partial.id
details[2].player.totalAmount = 300
clock = 28
service:Tick(1000)
assert(archive:Get(partialID).complete and #archive.db.fights == 3, "Retries upgrade one saved fight")
-- Death recap contents must survive invalidation of the client's recap identifier.
Fight(3, 400)
available[#available + 1] = { sessionID = 3, name = "Death", durationSeconds = 10 }
sessions[3][9] = { combatSources = { Player(1) }, totalAmount = 1, maxAmount = 1, durationSeconds = 10 }
sessions[3][9].combatSources[1].deathRecapID = 77
C_DeathRecap = {
    GetRecapEvents = function()
        return { { event = "SWING_DAMAGE", amount = 400, sourceName = "Wolf" } }
    end,
    GetRecapMaxHealth = function()
        return 1000
    end,
}
service:OnWorld()
clock = 31
service:Tick(1000)
local deathID = archive.db.fights[1].id
C_DeathRecap = nil
local deathSession = service:GetSession({ archiveID = deathID }, "Deaths")
assert(
    service:GetDetails({ archiveID = deathID }, deathSession.combatSources[1], "Deaths").deathEvents[1].amount == 400
)
-- All segments count toward retention, including pinned fights.
service:Pin(firstID)
archive.db.retention = 1
archive:Prune()
assert(not archive:Get(firstID) and archive:Get(deathID) and not archive:Get(secondID))
service:Delete(deathID)
service:OnWorld()
clock = 34
service:Tick(1000)
assert(not archive:Get(deathID) and #archive.db.fights == 0)
assert(#service:ListSessions() == 0, "Removed segments never reappear as live menu entries")
service:ClearHistory()
service:OnWorld()
clock = 37
service:Tick(1000)
assert(#archive.db.fights == 0, "Clearing the archive does not immediately recapture the same runtime sessions")
assert(not service:GetSession({ archiveID = firstID }, "DamageDone"), "Deleted archives show unavailable")
-- A newer client update during capture restarts the draft, avoiding mixed records.
Fight(4, 500)
available[#available + 1] = { sessionID = 4, name = "Changing", durationSeconds = 10 }
service:OnWorld()
clock = 40
service:Tick(1)
Fight(4, 600)
service:OnMeterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
clock = 43
service:Tick(1000)
assert(archive.db.fights[1].categories.DamageDone.session.totalAmount == 600)
assert(changed > 0)
-- Simulate the plain-table serialization performed by SavedVariables, without runtime references.
local function Serialize(value)
    if type(value) == "table" then
        local entries = {}
        for key, member in pairs(value) do
            entries[#entries + 1] = "[" .. Serialize(key) .. "]=" .. Serialize(member)
        end
        return "{" .. table.concat(entries, ",") .. "}"
    elseif type(value) == "string" then
        return string.format("%q", value)
    elseif type(value) == "number" or type(value) == "boolean" then
        return tostring(value)
    else
        error("SavedVariables contain unsupported values")
    end
end
local compiler = loadstring or load
local restored = assert(compiler("return " .. Serialize(app.db.char)))()
app = Load(restored)
service, archive = app.combatService, app.archive
local serializedID = archive.db.fights[1].id
assert(service:GetSession({ archiveID = serializedID }, "DamageDone").totalAmount == 600)
-- Explicit deletion survives reload even when client history is still present.
service:Delete(serializedID)
app = Load(app.db.char)
service, archive = app.combatService, app.archive
service:OnWorld()
clock = 46
service:Tick(1000)
assert(not archive:Get(serializedID))
for _, fight in ipairs(archive.db.fights) do
    assert(fight.name ~= "Changing", "Deleted history must not be imported after reload")
end
-- Identical contents after an explicit reset are still a new fight.
service:OnMeterEvent("DAMAGE_METER_RESET")
available = { { sessionID = 4, name = "Changing", durationSeconds = 10 } }
service:OnWorld()
clock = 49
service:Tick(1000)
assert(archive.db.fights[1].name == "Changing" and archive.db.fights[1].id ~= serializedID)
local resetID = archive.db.fights[1].id
service:OnMeterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 4)
assert(service.pending[4])
service:Delete(resetID)
assert(not service.pending[4], "Deleting an incomplete recapture cancels its pending job")
-- Encounter metadata is recorded separately from combat amounts.
Fight(5, 700)
available = { { sessionID = 5, name = "Boss", durationSeconds = 10 } }
combat = true
service:OnEncounter("ENCOUNTER_START", 123, "Boss", 1, 5)
service:OnEncounter("ENCOUNTER_END", 123, "Boss", 1, 5, 1)
combat = false
service:OnCombatEnd()
clock = 52
service:Tick(1000)
local bossID = archive.db.fights[1].id
assert(archive:Get(bossID).encounter.success and archive:Get(bossID).encounter.id == 123)
-- Restored data is validated before renderers can see it.
local damaged = app.db.char
damaged.combatHistory.fights[#damaged.combatHistory.fights + 1] = 5
damaged.combatHistory.fights[#damaged.combatHistory.fights + 1] = {
    id = 999,
    name = "Damaged",
    capturedAt = time(),
    categories = { DamageDone = { session = "not a session", details = {} } },
}
app = Load(damaged)
assert(not app.archive:Get(999) and app.archive:Get(bossID))
assert(#app.archive.db.invalidFights == 2, "Damaged records remain recoverable outside rendered history")
local incompatible = { combatHistory = { schemaVersion = 999, fights = {} } }
local migrated = Load(incompatible)
assert(migrated.archive.db.schemaVersion == 1 and incompatible.previousCombatHistory.schemaVersion == 999)
-- Retention is a total bound, including pins, and applies before new insertion.
local bounded = Load({})
local store, manager = bounded.archive, bounded.combatService
manager:SetSegmentLimit(3)
local ids = {}
for index = 1, 4 do
    ids[index] = store:Commit({ name = "Segment " .. index, capturedAt = index, categories = {} })
end
assert(#store.db.fights == 3 and not store:Get(ids[1]) and store:Get(ids[4]))
manager:Pin(ids[2])
manager:SetSegmentLimit(2)
assert(#store.db.fights == 2 and not store:Get(ids[2]), "Pinned oldest segments count toward the limit")
manager.runtime[123] = { sessionID = 123, archiveID = ids[2] }
assert(not manager:GetSession({ sessionID = 123, sessionGeneration = manager.generation }, "DamageDone"))
assert(
    not manager:FinishSnapshot({ entry = manager.runtime[123], snapshot = {} }) and manager.deleted[123],
    "An in-flight update cannot restore an evicted segment"
)
store:Commit({ name = "Updated", capturedAt = 4, categories = {} }, ids[4])
assert(#store.db.fights == 2 and store:Get(ids[3]), "Updates do not evict another segment")
manager:DeleteOlderSegments(ids[4])
assert(#store.db.fights == 1 and store:Get(ids[4]))
manager:DeleteOlderSegments(-1)
assert(#store.db.fights == 1, "A stale selection never deletes unrelated segments")
manager:SetSegmentLimit(math.huge)
assert(store.db.retention == 50)
manager:SetSegmentLimit(100000)
assert(store.db.retention == 1000)
for index = 1, 1001 do
    local id = store:Commit({ name = "Bounded", capturedAt = index + 4, categories = {} })
    store:Get(id).pinned = true
    assert(#store.db.fights <= 1000)
end
local boundedSave = assert(compiler("return " .. Serialize(bounded.db.char)))()
boundedSave.combatHistory.retention = 100000
table.insert(boundedSave.combatHistory.fights, {
    id = 9999,
    name = "Old overflow",
    capturedAt = 0,
    categories = {},
    pinned = true,
})
local boundedReload = Load(boundedSave)
assert(boundedReload.archive.db.retention == 1000 and #boundedReload.archive.db.fights == 1000)
assert(not boundedReload.archive:Get(9999), "Restored saves obey the hard cap, including pins")
print(
    "PASS: shared queries, secret boundaries, enemy contributors, snapshots, reload reconciliation, offline history, reset generations, retries, recaps, retention and deletion"
)
