---@type string, SeamlessDamageMeter
local _, app = ...

-- Only public, explicitly supported scalar fields can cross the persistence boundary.
app.archive = { schemaVersion = 1 }
local archive = app.archive

function archive:IsPublic(value)
    return not (issecretvalue and issecretvalue(value))
end

function archive:IsTable(value)
    return self:IsPublic(value) and type(value) == "table" and not (issecrettable and issecrettable(value))
end

local sourceFields = {
    sourceGUID = "string",
    sourceCreatureID = "number",
    name = "string",
    classFilename = "string",
    specIconID = "number",
    totalAmount = "number",
    amountPerSecond = "number",
    isLocalPlayer = "boolean",
    deathRecapID = "number",
    deathTimeSeconds = "number",
    classification = "string",
    sourceDisplayType = "number",
    factionGroup = "string",
}
local spellFields = {
    spellID = "number",
    totalAmount = "number",
    amountPerSecond = "number",
    creatureName = "string",
    overkillAmount = "number",
    isAvoidable = "boolean",
    isDeadly = "boolean",
}
local unitFields = {
    unitName = "string",
    unitClassFilename = "string",
    classification = "string",
    isPet = "boolean",
    isMob = "boolean",
    amount = "number",
    specIconID = "number",
}
local recapFields = {
    spellId = "number",
    spellID = "number",
    spellName = "string",
    event = "string",
    amount = "number",
    sourceName = "string",
    environmentalType = "string",
    timestamp = "number",
    school = "number",
    absorbed = "number",
    resisted = "number",
    blocked = "number",
    overkill = "number",
    critical = "boolean",
}

function archive:CopyFields(record, fields)
    if not self:IsTable(record) then
        return nil
    end
    local result = {}
    for key, kind in pairs(fields) do
        local value = record[key]
        if not self:IsPublic(value) then
            return nil
        end
        if value ~= nil then
            if type(value) ~= kind then
                return nil
            end
            if kind == "number" and (value ~= value or math.abs(value) == math.huge) then
                return nil
            end
            result[key] = value
        end
    end
    return result
end

function archive:CopySession(session)
    local result =
        self:CopyFields(session, { maxAmount = "number", totalAmount = "number", durationSeconds = "number" })
    if
        not result
        or type(result.totalAmount) ~= "number"
        or type(result.maxAmount) ~= "number"
        or not self:IsTable(session.combatSources)
    then
        return nil
    end
    result.combatSources = {}
    for _, source in ipairs(session.combatSources) do
        local copy = self:CopyFields(source, sourceFields)
        if
            not copy
            or type(copy.name) ~= "string"
            or type(copy.totalAmount) ~= "number"
            or type(copy.amountPerSecond) ~= "number"
        then
            return nil
        end
        result.combatSources[#result.combatSources + 1] = copy
    end
    return result
end

function archive:CopyDetails(details)
    local result = self:CopyFields(details, { maxAmount = "number", totalAmount = "number" })
    if not result then
        return nil
    end
    if details.deathEvents then
        if not self:IsTable(details.deathEvents) then
            return nil
        end
        result.deathEvents = {}
        for _, event in ipairs(details.deathEvents) do
            local copy = self:CopyFields(event, recapFields)
            if not copy or type(copy.amount) ~= "number" then
                return nil
            end
            result.deathEvents[#result.deathEvents + 1] = copy
        end
    else
        if type(result.totalAmount) ~= "number" or type(result.maxAmount) ~= "number" then
            return nil
        end
        if not self:IsTable(details.combatSpells) then
            return nil
        end
        result.combatSpells = {}
        for _, spell in ipairs(details.combatSpells) do
            local copy = self:CopyFields(spell, spellFields)
            if not copy or type(copy.totalAmount) ~= "number" then
                return nil
            end
            copy.combatSpellDetails = self:CopyFields(spell.combatSpellDetails or {}, unitFields)
            if not copy.combatSpellDetails then
                return nil
            end
            result.combatSpells[#result.combatSpells + 1] = copy
        end
    end
    return result
end

local function PositiveInteger(value, fallback)
    if type(value) ~= "number" or value ~= value or value == math.huge or value < 1 then
        return fallback
    end
    return math.floor(value)
end

function archive:ValidateFight(fight)
    local copy = self:CopyFields(fight, {
        id = "number",
        name = "string",
        capturedAt = "number",
        durationSeconds = "number",
        clientSessionID = "number",
        generation = "number",
        fingerprint = "string",
        clientBuild = "string",
        imported = "boolean",
        pinned = "boolean",
    })
    if
        not copy
        or not PositiveInteger(copy.id)
        or copy.id ~= math.floor(copy.id)
        or not copy.name
        or not copy.capturedAt
        or not self:IsTable(fight.categories)
    then
        return nil
    end
    copy.categories, copy.complete = {}, true
    for _, statistic in ipairs(app.statistics) do
        local category = fight.categories[statistic.key]
        if self:IsTable(category) then
            local session = self:CopySession(category.session)
            if not session or not self:IsTable(category.details) then
                return nil
            end
            local result = { session = session, details = {}, complete = true }
            for index in ipairs(session.combatSources) do
                local detail = self:CopyDetails(category.details[index])
                if detail then
                    result.details[index] = detail
                else
                    result.complete, copy.complete = false, false
                end
            end
            copy.categories[statistic.key] = result
        else
            copy.complete = false
        end
    end
    copy.instance = fight.instance
            and self:CopyFields(
                fight.instance,
                { name = "string", type = "string", difficulty = "string", id = "number" }
            )
        or nil
    copy.encounter = fight.encounter
            and self:CopyFields(fight.encounter, {
                id = "number",
                name = "string",
                difficultyID = "number",
                size = "number",
                startedAt = "number",
                endedAt = "number",
                success = "boolean",
            })
        or nil
    return copy
end

function archive:Initialize(character)
    local history = character.combatHistory
    if type(history) ~= "table" or history.schemaVersion ~= self.schemaVersion then
        if history ~= nil then
            character.previousCombatHistory = history -- Preserve an incompatible schema for recovery.
        end
        history = { schemaVersion = self.schemaVersion, nextID = 1, generation = 0, retention = 50, fights = {} }
        character.combatHistory = history
    end
    history.fights = type(history.fights) == "table" and history.fights or {}
    history.retention = math.min(500, PositiveInteger(history.retention, 50))
    history.nextID = PositiveInteger(history.nextID, 1)
    history.generation = PositiveInteger(history.generation, 0) + 1
    local ignored = {}
    for _, record in ipairs(type(history.ignored) == "table" and history.ignored or {}) do
        local copy = self:CopyFields(
            record,
            { clientSessionID = "number", name = "string", fingerprint = "string", generation = "number" }
        )
        if copy and copy.clientSessionID and copy.name and copy.fingerprint and copy.generation then
            ignored[#ignored + 1] = copy
        end
    end
    history.ignored = ignored
    self.db, self.byID = history, {}
    local valid = {}
    -- Validate restored records too. Quarantine damaged records rather than rendering them.
    for _, fight in ipairs(history.fights) do
        local copy = self:ValidateFight(fight)
        if copy and not self.byID[copy.id] then
            self.byID[copy.id] = copy
            valid[#valid + 1] = copy
            history.nextID = math.max(history.nextID, copy.id + 1)
        else
            history.invalidFights = type(history.invalidFights) == "table" and history.invalidFights or {}
            history.invalidFights[#history.invalidFights + 1] = fight
        end
    end
    history.fights = valid
    self:Prune()
end

function archive:Get(id)
    return self.byID and self.byID[id]
end

function archive:Commit(snapshot, existingID)
    local existing = self:Get(existingID)
    snapshot.id = existing and existing.id or self.db.nextID
    snapshot.pinned = existing and existing.pinned or false
    if existing then
        for index, fight in ipairs(self.db.fights) do
            if fight.id == existing.id then
                self.db.fights[index] = snapshot
                break
            end
        end
    else
        self.db.nextID = self.db.nextID + 1
        table.insert(self.db.fights, 1, snapshot)
    end
    self.byID[snapshot.id] = snapshot
    self:Prune()
    return snapshot.id
end

function archive:Prune()
    local unpinned = 0
    for index = #self.db.fights, 1, -1 do
        -- Count from newest below; remove oldest unpinned records first.
        local fight = self.db.fights[index]
        if self.byID[fight.id] and not fight.pinned then
            unpinned = unpinned + 1
        end
    end
    for index = #self.db.fights, 1, -1 do
        local fight = self.db.fights[index]
        if unpinned > self.db.retention and self.byID[fight.id] and not fight.pinned then
            self.byID[fight.id] = nil
            table.remove(self.db.fights, index)
            unpinned = unpinned - 1
        end
    end
end

function archive:Delete(id)
    self:RememberDeletion(self:Get(id))
    for index, fight in ipairs(self.db.fights) do
        if fight.id == id then
            table.remove(self.db.fights, index)
            break
        end
    end
    self.byID[id] = nil
end

function archive:Clear()
    for _, fight in ipairs(self.db.fights) do
        self:RememberDeletion(fight)
    end
    self.db.fights, self.byID = {}, {}
    self.db.invalidFights = nil
end

function archive:RememberDeletion(fight)
    if not fight or not fight.fingerprint then
        return
    end
    self.db.ignored = self.db.ignored or {}
    self.db.ignored[#self.db.ignored + 1] = {
        clientSessionID = fight.clientSessionID,
        name = fight.name,
        fingerprint = fight.fingerprint,
        generation = self.db.generation,
    }
    if #self.db.ignored > 500 then
        table.remove(self.db.ignored, 1)
    end
end
