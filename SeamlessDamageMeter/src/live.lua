---@type string, SeamlessDamageMeter
local _, app = ...

app.live = {}
local live = app.live

-- A readable table may contain secret leaves that widgets can display. The archive's
-- stricter IsTable check is for serialization, not for live rendering.
function live:IsReadableTable(value)
    if not app.archive:IsPublic(value) or type(value) ~= "table" then
        return false
    end
    return not canaccesstable or canaccesstable(value)
end

function live:IsAvailable()
    return C_DamageMeter ~= nil and Enum.DamageMeterType ~= nil
end

function live:CanRead()
    if not self:IsAvailable() then
        return false, "This client does not provide the damage meter API."
    end
    local available, reason = C_DamageMeter.IsDamageMeterAvailable()
    if not available then
        return false, reason
    end
    if not C_CVar.GetCVarBool("damageMeterEnabled") then
        return false, "Combat tracking is disabled. Saved fights are still available."
    end
    return true
end

function live:IsRestricted()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
    end
    if C_RestrictedActions and Enum.AddOnRestrictionType then
        local state = C_RestrictedActions.GetAddOnRestrictionState(Enum.AddOnRestrictionType.Combat)
        if not app.archive:IsPublic(state) or (state and state > 0) then
            return true
        end
    end
    return false
end

function live:List()
    if not self:CanRead() then
        return {}
    end
    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or not self:IsReadableTable(sessions) then
        return {}
    end
    local result = {}
    for _, session in ipairs(sessions) do
        if
            self:IsReadableTable(session)
            and app.archive:IsPublic(session.sessionID)
            and type(session.sessionID) == "number"
        then
            local copy = { sessionID = session.sessionID }
            copy.name = app.archive:IsPublic(session.name) and type(session.name) == "string" and session.name or ""
            if app.archive:IsPublic(session.durationSeconds) and type(session.durationSeconds) == "number" then
                copy.durationSeconds = session.durationSeconds
            end
            result[#result + 1] = copy
        end
    end
    return result
end

function live:GetSession(config, key)
    local available, reason = self:CanRead()
    if not available then
        return nil, reason
    end
    local meterType = Enum.DamageMeterType[key]
    if meterType == nil then
        return nil, "This statistic is unavailable on this client."
    end
    local ok, session
    if config.sessionID then
        local found = false
        for _, entry in ipairs(self:List()) do
            if entry.sessionID == config.sessionID then
                found = true
                break
            end
        end
        if not found then
            return nil, "This fight is no longer available. Select another session."
        end
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, config.sessionID, meterType)
    else
        ok, session = pcall(
            C_DamageMeter.GetCombatSessionFromType,
            Enum.DamageMeterSessionType[config.session] or Enum.DamageMeterSessionType.Current,
            meterType
        )
    end
    if not ok or not self:IsReadableTable(session) or not self:IsReadableTable(session.combatSources) then
        return nil, "Combat data is temporarily unavailable."
    end
    return session
end

function live:GetDetails(config, source, key)
    if key == "Deaths" then
        if
            C_DeathRecap
            and app.archive:IsPublic(source.deathRecapID)
            and source.deathRecapID
            and source.deathRecapID ~= 0
        then
            local ok, events = pcall(C_DeathRecap.GetRecapEvents, source.deathRecapID)
            local healthOK, health = pcall(C_DeathRecap.GetRecapMaxHealth, source.deathRecapID)
            if ok and healthOK then
                return { deathEvents = events or {}, maxAmount = health }
            end
            return nil, "Death recap is temporarily unavailable."
        end
        return { deathEvents = {} }, "No death recap available."
    end
    if not self:CanRead() then
        return nil, "Live details are unavailable."
    end
    local meterType = Enum.DamageMeterType[key]
    if meterType == nil then
        return nil, "This statistic is unavailable on this client."
    end
    -- The query APIs accept secret arguments only in untainted code. Never send a
    -- restricted GUID from an addon; the local player's real GUID is already public.
    local guid = source.sourceGUID
    if not app.archive:IsPublic(guid) or type(guid) ~= "string" or guid == "" then
        guid = nil
    end
    if app.archive:IsPublic(source.isLocalPlayer) and source.isLocalPlayer and UnitGUID then
        local playerGUID = UnitGUID("player")
        if app.archive:IsPublic(playerGUID) and type(playerGUID) == "string" and playerGUID ~= "" then
            guid = playerGUID
        end
    end
    local creature = source.sourceCreatureID
    if not app.archive:IsPublic(creature) or type(creature) ~= "number" or creature <= 0 then
        creature = nil
    end
    if not guid and not creature then
        return nil, "This source's identity is restricted in combat."
    end
    local ok, details
    if config.sessionID then
        ok, details = pcall(C_DamageMeter.GetCombatSessionSourceFromID, config.sessionID, meterType, guid, creature)
    else
        ok, details = pcall(
            C_DamageMeter.GetCombatSessionSourceFromType,
            Enum.DamageMeterSessionType[config.session] or Enum.DamageMeterSessionType.Current,
            meterType,
            guid,
            creature
        )
    end
    if not ok or not self:IsReadableTable(details) or not self:IsReadableTable(details.combatSpells) then
        return nil, "Source details are temporarily unavailable."
    end
    return details
end

function live:GetDuration(config, session)
    if
        not config.sessionID
        and self:IsAvailable()
        and self:IsRestricted()
        and C_DamageMeter.GetSessionDurationSeconds
    then
        local ok, duration = pcall(
            C_DamageMeter.GetSessionDurationSeconds,
            Enum.DamageMeterSessionType[config.session] or Enum.DamageMeterSessionType.Current
        )
        if ok then
            return duration
        end
    end
    return session and session.durationSeconds
end
