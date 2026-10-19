---@type string, SeamlessDamageMeter
local _, app = ...

app.combatService = { cache = {}, listeners = {}, runtime = {}, revision = 0, saveSessions = false }
local service = app.combatService

function service:Initialize(character)
    -- Keep existing saved history untouched while using only client sessions.
    app.archive:Initialize(self.saveSessions and character or {})
    self.generation = app.archive.db.generation
    self.reconcileGeneration = self.generation - 1
    self.cache, self.runtime, self.pending = {}, {}, {}
    self.deleted = {}
    -- Unscoped legacy client IDs cannot safely survive a client restart.
    for _, profile in pairs(app.db.sv and app.db.sv.profiles or {}) do
        for _, config in ipairs(profile.windows or {}) do
            if not self.saveSessions then
                config.archiveID, config.sessionID, config.sessionGeneration, config.sessionName = nil, nil, nil, nil
            end
            if config.sessionID and not config.sessionGeneration then
                config.sessionGeneration = 0
            end
        end
    end
    for _, config in ipairs(app.db.profile.windows or {}) do
        if not self.saveSessions then
            config.archiveID, config.sessionID, config.sessionGeneration, config.sessionName = nil, nil, nil, nil
        end
        if config.sessionID and not config.sessionGeneration then
            config.sessionGeneration = 0
        end
    end
end

function service:Subscribe(owner, callback)
    self.listeners[owner] = callback
end

function service:Notify(historyChanged)
    self.revision = self.revision + 1
    for owner, callback in pairs(self.listeners) do
        callback(owner, historyChanged)
    end
end

function service:Invalidate()
    self.cache = {}
end

function service:BeginRefresh()
    -- Rates and live row details can change without a category update event.
    for key in pairs(self.cache) do
        if key:sub(1, 2) == "l:" and not key:find(":enemyIndex", 1, true) then
            self.cache[key] = nil
        end
    end
end

function service:CacheKey(config, key)
    if config.archiveID then
        return "a:" .. config.archiveID .. ":" .. key
    end
    return "l:" .. (config.sessionID or config.session or "Current") .. ":" .. key
end

function service:Resolve(config)
    if config.archiveID then
        return app.archive:Get(config.archiveID), "archived"
    end
    if config.sessionID then
        local entry = self.runtime[config.sessionID]
        if not config.sessionGeneration then
            config.sessionGeneration = 0
        end
        if config.sessionGeneration and config.sessionGeneration ~= self.generation then
            return nil, "expired"
        end
        if self.deleted[config.sessionID] or (entry and entry.archiveID and not app.archive:Get(entry.archiveID)) then
            return nil, "archived"
        end
        if entry and entry.archiveID and app.archive:Get(entry.archiveID) then
            config.archiveID, config.sessionName = entry.archiveID, app.archive:Get(entry.archiveID).name
            config.sessionID, config.sessionGeneration = nil, nil
            return app.archive:Get(config.archiveID), "archived"
        end
    end
    return nil, "live"
end

function service:GetSession(config, key)
    if app.IsEditingWindows and app:IsEditingWindows() then
        return app:GetPreviewSession(config), nil, "preview"
    end
    if key == "Threat" then
        local cacheKey = "l:Threat"
        if not self.cache[cacheKey] then
            self.cache[cacheKey] = { app.live:GetThreatSession() }
        end
        local result = self.cache[cacheKey]
        return result[1], result[2], "live"
    end
    local fight, state = self:Resolve(config)
    if state == "expired" then
        return nil, "This live selection expired. Select a saved fight.", state
    end
    if state == "archived" then
        local category = fight and fight.categories[key]
        if category and category.session then
            return category.session, nil, fight.complete and state or "incomplete"
        end
        return nil,
            fight and "This statistic was not captured for this fight." or "This saved fight was deleted.",
            "unavailable"
    end
    local cacheKey = self:CacheKey(config, key)
    if not self.cache[cacheKey] then
        self.cache[cacheKey] = { app.live:GetSession(config, key) }
    end
    local result = self.cache[cacheKey]
    return result[1], result[2], app.live:IsRestricted() and "restricted" or "live"
end

local function SourceIndex(session, source)
    for index, entry in ipairs(session.combatSources or {}) do
        if entry == source then
            return index
        end
    end
end

function service:GetDetails(config, source, key)
    if app.IsEditingWindows and app:IsEditingWindows() then
        return nil, "Preview"
    end
    local session, reason = self:GetSession(config, key)
    if not session then
        return nil, reason
    end
    local index = SourceIndex(session, source)
    if not index then
        return nil, "This row is no longer current."
    end
    local fight, state = self:Resolve(config)
    if state == "archived" then
        local category = fight and fight.categories[key]
        local details = category and category.details[index]
        return details, not details and "Details were not captured for this source." or nil
    end
    local cacheKey = self:CacheKey(config, key) .. ":s:" .. index
    if not self.cache[cacheKey] then
        self.cache[cacheKey] = { app.live:GetDetails(config, source, key) }
    end
    local result = self.cache[cacheKey]
    return result[1], result[2]
end

function service:GetDuration(config, session)
    if config.statistic == "Threat" then
        return nil
    end
    if session and session.isPreview then
        return session.durationSeconds
    end
    if config.archiveID then
        return session and session.durationSeconds
    end
    local key = self:CacheKey(config, "duration")
    if not self.cache[key] then
        self.cache[key] = { app.live:GetDuration(config, session) }
    end
    return self.cache[key][1]
end

function service:ListSessions()
    local result = {}
    if app.IsEditingWindows and app:IsEditingWindows() then
        return result
    end
    for _, entry in ipairs(app.live:List()) do
        local runtime = self.runtime[entry.sessionID]
        if not self.deleted[entry.sessionID] and not (runtime and runtime.archiveID) then
            entry.state = self.pending and self.pending[entry.sessionID] and "pending" or "live"
            entry.sessionGeneration = self.generation
            result[#result + 1] = entry
        end
    end
    if app.archive.db then
        for _, fight in ipairs(app.archive.db.fights) do
            if app.archive:Get(fight.id) then
                result[#result + 1] = {
                    archiveID = fight.id,
                    name = fight.name,
                    durationSeconds = fight.durationSeconds,
                    capturedAt = fight.capturedAt,
                    encounter = fight.encounter,
                    pinned = fight.pinned,
                    state = fight.complete and "archived" or "incomplete",
                }
            end
        end
    end
    return result
end

function service:Describe(entry, menu)
    local text = entry.name ~= "" and entry.name or ("Combat " .. (entry.archiveID or entry.sessionID))
    if menu then
        text = text .. " (" .. entry.state .. ")"
    end
    if not menu and entry.capturedAt and date then
        text = date("%d %b %H:%M", entry.capturedAt) .. " - " .. text
    end
    if not menu and entry.durationSeconds then
        text = text .. " [" .. SecondsToClock(entry.durationSeconds) .. "]"
    end
    if entry.encounter and entry.encounter.success ~= nil then
        text = text .. (entry.encounter.success and " - Kill" or " - Wipe")
    end
    if entry.pinned then
        text = "* " .. text
    end
    return menu and text or text .. " (" .. entry.state .. ")"
end

function service:Pin(id)
    local fight = app.archive:Get(id)
    if fight then
        fight.pinned = not fight.pinned
        app.archive:Prune()
        self:Notify(true)
    end
end

function service:Delete(id)
    for sessionID, entry in pairs(self.runtime) do
        if entry.archiveID == id then
            self.deleted[sessionID] = true
            if self.pending then
                self.pending[sessionID] = nil
            end
        end
    end
    app.archive:Delete(id)
    self:Invalidate()
    self:Notify(true)
end

function service:ClearHistory()
    for sessionID in pairs(self.runtime) do
        self.deleted[sessionID] = true
    end
    self.pending = {}
    app.archive:Clear()
    self:Invalidate()
    self:Notify(true)
end

function service:SetSegmentLimit(value)
    app.archive.db.retention = value
    app.archive:Prune()
    self:Invalidate()
    self:Notify(true)
end

function service:DeleteOlderSegments(id)
    local older, ids = false, {}
    for _, fight in ipairs(app.archive.db.fights) do
        if older then
            ids[#ids + 1] = fight.id
        elseif fight.id == id then
            older = true
        end
    end
    for _, olderID in ipairs(ids) do
        self:Delete(olderID)
    end
end
