---@type string, SeamlessDamageMeter
local _, app = ...
local service, archive = app.combatService, app.archive
local RETRY_SECONDS, MAX_ATTEMPTS = 2, 30

local function Now()
    return GetTime()
end

-- The fingerprint is public data, not a client ID. API list order is not significant.
local function SessionSignature(session)
    local rows = {}
    for _, source in ipairs(session.combatSources) do
        local identity = source.sourceGUID or source.name
        rows[#rows + 1] = #identity
            .. ":"
            .. identity
            .. ":"
            .. tostring(source.sourceCreatureID or "")
            .. ":"
            .. tostring(source.totalAmount)
            .. ":"
            .. tostring(source.amountPerSecond)
    end
    table.sort(rows)
    return tostring(session.totalAmount) .. "/" .. tostring(session.durationSeconds) .. "/" .. table.concat(rows, "|")
end

local function SnapshotSignature(snapshot)
    local signature = {}
    for _, statistic in ipairs(app.statistics) do
        local category = snapshot.categories[statistic.key]
        if category then
            signature[#signature + 1] = statistic.key .. "=" .. SessionSignature(category.session)
        end
    end
    return #signature > 0 and table.concat(signature, "\n") or nil
end

function service:Discover()
    if not self.pending then
        return
    end
    local sessions, present = app.live:List(), {}
    local latest
    for _, session in ipairs(sessions) do
        present[session.sessionID] = true
        if not latest or session.sessionID > latest then
            latest = session.sessionID
        end
        local entry = self.runtime[session.sessionID]
        if not entry then
            entry = { sessionID = session.sessionID, firstSeen = time(), imported = not app.live:IsRestricted() }
            self.runtime[session.sessionID] = entry
            local ok, name, instanceType, _, difficulty, _, _, _, instanceID = pcall(GetInstanceInfo)
            if ok then
                entry.instance = archive:CopyFields(
                    { name = name, type = instanceType, difficulty = difficulty, id = instanceID },
                    { name = "string", type = "string", difficulty = "string", id = "number" }
                )
            end
        end
        entry.name, entry.durationSeconds = session.name or "", session.durationSeconds
        if entry.archiveID and not archive:Get(entry.archiveID) then
            self.deleted[session.sessionID] = true
            self.pending[session.sessionID] = nil
        end
        if not entry.archiveID and not self.pending[session.sessionID] and not self.deleted[session.sessionID] then
            self.pending[session.sessionID] = { entry = entry, readyAt = Now() + RETRY_SECONDS, attempts = 0 }
        end
    end
    if app.live:IsRestricted() and latest then
        self.activeSessionID = latest
        local entry = self.runtime[latest]
        entry.imported = false
        if self.encounter then
            entry.encounter = self.encounter
        end
    end
    for id, job in pairs(self.pending) do
        if not present[id] then
            self.pending[id] = nil
            self.runtime[id].expired = true
        elseif app.live:IsRestricted() then
            job.readyAt = Now() + RETRY_SECONDS
        end
    end
end

function service:OnMeterEvent(event, _, sessionID)
    self:Invalidate()
    if event == "DAMAGE_METER_RESET" then
        archive.db.generation = archive.db.generation + 1
        self.generation = archive.db.generation
        self.pending, self.runtime, self.deleted = {}, {}, {}
        self.reconcileGeneration = nil
        self.activeSessionID = nil
    else
        self:Discover()
        if sessionID and self.runtime[sessionID] and not self.deleted[sessionID] then
            local entry = self.runtime[sessionID]
            self.pending[sessionID] = { entry = entry, readyAt = Now() + RETRY_SECONDS, attempts = 0 }
            if app.live:IsRestricted() then
                self.activeSessionID = sessionID
                if self.encounter then
                    entry.encounter = self.encounter
                end
            end
        end
        -- A current update can arrive between source reads. Restart any in-flight capture.
        if event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
            for _, job in pairs(self.pending) do
                job.snapshot, job.categoryIndex, job.sourceIndex = nil, nil, nil
                job.readyAt = Now() + RETRY_SECONDS
            end
        end
    end
    self:Notify()
end

function service:OnEncounter(event, encounterID, name, difficultyID, size, success)
    if event == "ENCOUNTER_START" then
        self.encounter = archive:CopyFields(
            { id = encounterID, name = name, difficultyID = difficultyID, size = size, startedAt = time() },
            { id = "number", name = "string", difficultyID = "number", size = "number", startedAt = "number" }
        )
        self:Discover()
    else
        local encounter = self.encounter
        if encounter and archive:IsPublic(success) then
            encounter.success, encounter.endedAt = success == 1, time()
            local entry = self.runtime[self.activeSessionID]
            if entry and entry.encounter == encounter then
                local fight = archive:Get(entry.archiveID)
                if fight then
                    fight.encounter = encounter
                end
            end
        end
        self.encounter = nil
        self:Discover()
    end
    self:Notify()
end

function service:StartSnapshot(job)
    local entry = job.entry
    job.snapshot = {
        name = entry.name ~= "" and entry.name or ("Combat " .. entry.sessionID),
        clientSessionID = entry.sessionID,
        generation = self.generation,
        capturedAt = entry.firstSeen,
        imported = entry.imported,
        durationSeconds = entry.durationSeconds,
        instance = entry.instance,
        encounter = entry.encounter,
        categories = {},
        complete = true,
    }
    if GetBuildInfo then
        local ok, _, build = pcall(GetBuildInfo)
        if ok and archive:IsPublic(build) and type(build) == "string" then
            job.snapshot.clientBuild = build
        end
    end
    job.categoryIndex, job.sourceIndex = 1, nil
end

function service:FinishSnapshot(job)
    local snapshot, entry = job.snapshot, job.entry
    if self.deleted[entry.sessionID] or (entry.archiveID and not archive:Get(entry.archiveID)) then
        self.deleted[entry.sessionID] = true
        return false
    end
    snapshot.fingerprint = SnapshotSignature(snapshot)
    if not snapshot.fingerprint then
        return false
    end
    for _, ignored in ipairs(archive.db.ignored or {}) do
        if
            (ignored.generation == self.reconcileGeneration or ignored.generation == self.generation)
            and ignored.clientSessionID == snapshot.clientSessionID
            and ignored.name == snapshot.name
            and ignored.fingerprint == snapshot.fingerprint
        then
            ignored.generation = self.generation
            self.deleted[entry.sessionID] = true
            return false
        end
    end
    local existingID = entry.archiveID
    -- Reconcile a surviving client session after reload only when its public contents match.
    if not existingID and self.reconcileGeneration then
        for _, fight in ipairs(archive.db.fights) do
            if
                fight.clientSessionID == snapshot.clientSessionID
                and fight.generation == self.reconcileGeneration
                and fight.name == snapshot.name
                and fight.fingerprint == snapshot.fingerprint
            then
                existingID = fight.id
                snapshot.capturedAt, snapshot.instance, snapshot.encounter =
                    fight.capturedAt, fight.instance, fight.encounter
                break
            end
        end
    end
    if not snapshot.complete then
        -- Keep usable categories immediately, while retrying unavailable details.
        local previous = archive:Get(existingID)
        if previous then
            for key, category in pairs(previous.categories) do
                local newer = snapshot.categories[key]
                if
                    category.complete
                    and not (newer and newer.complete)
                    and (not newer or SessionSignature(newer.session) == SessionSignature(category.session))
                then
                    snapshot.categories[key] = category
                end
            end
        end
    end
    snapshot.fingerprint = SnapshotSignature(snapshot)
    entry.archiveID = archive:Commit(snapshot, existingID)
    for _, profile in pairs(app.db.sv and app.db.sv.profiles or {}) do
        self:BindSelections(profile, entry)
    end
    self:BindSelections(app.db.profile, entry)
    self:Invalidate()
    self:Notify(true)
    return true
end

function service:BindSelections(profile, entry)
    for _, config in ipairs(profile.windows or {}) do
        if
            not config.archiveID
            and config.sessionID == entry.sessionID
            and config.sessionGeneration == self.generation
        then
            config.archiveID, config.sessionName = entry.archiveID, entry.name
            config.sessionID, config.sessionGeneration = nil, nil
        end
    end
end

-- One step reads a category or a source; the timer bounds work independently of window visibility.
function service:CaptureStep(job)
    if not job.snapshot then
        self:StartSnapshot(job)
    end
    local statistic = app.statistics[job.categoryIndex]
    if not statistic then
        return true
    end
    local key, snapshot = statistic.key, job.snapshot
    local config = { sessionID = job.entry.sessionID, statistic = key }
    local category = snapshot.categories[key]
    if not job.sourceIndex then
        if Enum.DamageMeterType[key] == nil then
            job.categoryIndex = job.categoryIndex + 1
            return false
        end
        local session = app.live:GetSession(config, key)
        local copy = session and archive:CopySession(session)
        if not copy then
            snapshot.complete = false
            job.categoryIndex = job.categoryIndex + 1
            return false
        end
        category = { session = copy, details = {}, complete = true }
        snapshot.durationSeconds = snapshot.durationSeconds or copy.durationSeconds
        snapshot.categories[key] = category
        job.sourceIndex = 1
    else
        local source = category.session.combatSources[job.sourceIndex]
        if source then
            local details = app.live:GetDetails(config, source, key)
            local copy = details and archive:CopyDetails(details)
            if key == "Deaths" and source.totalAmount > 0 and (not copy or #(copy.deathEvents or {}) == 0) then
                copy = nil
            end
            if copy then
                category.details[job.sourceIndex] = copy
            else
                category.complete, snapshot.complete = false, false
            end
            job.sourceIndex = job.sourceIndex + 1
        else
            local final = app.live:GetSession(config, key)
            local finalCopy = final and archive:CopySession(final)
            if not finalCopy or SessionSignature(finalCopy) ~= SessionSignature(category.session) then
                -- Never save mixed totals and details from a changing session.
                snapshot.categories[key], snapshot.complete = nil, false
            end
            job.categoryIndex, job.sourceIndex = job.categoryIndex + 1, nil
        end
    end
    return false
end

function service:Tick(budget)
    if not self.pending or not app.live:CanRead() or app.live:IsRestricted() then
        return
    end
    if app.IsEditingWindows and app:IsEditingWindows() then
        return
    end
    local ids = {}
    for id in pairs(self.pending) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local remaining = budget or 8
    for _, id in ipairs(ids) do
        local job = self.pending[id]
        while remaining > 0 and job and job.readyAt <= Now() do
            remaining = remaining - 1
            if self:CaptureStep(job) then
                job.attempts = job.attempts + 1
                local committed = self:FinishSnapshot(job)
                if self.deleted[id] or (committed and job.snapshot.complete) or job.attempts >= MAX_ATTEMPTS then
                    self.pending[id] = nil
                    if not committed then
                        self.deleted[id] = true
                    end
                    break
                end
                job.snapshot, job.sourceIndex, job.categoryIndex = nil, nil, nil
                job.readyAt = Now() + RETRY_SECONDS
                break
            end
        end
        if remaining == 0 then
            break
        end
    end
end

function service:OnWorld()
    self:Invalidate()
    self:Discover()
    self:Notify()
end

function service:OnCombatEnd()
    self:Invalidate()
    self:Discover()
    for _, job in pairs(self.pending) do
        job.readyAt = Now() + RETRY_SECONDS
    end
    self:Notify()
end

function service:OnLogout()
    if app.live:IsRestricted() then
        return
    end
    self:Discover()
    -- A bounded final attempt; complete snapshots are already in SavedVariables.
    self:Tick(256)
end
