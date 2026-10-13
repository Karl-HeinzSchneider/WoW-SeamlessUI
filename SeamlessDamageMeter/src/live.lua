---@type string, SeamlessDamageMeter
local _, app = ...

app.live = {}
local live = app.live

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
    if not ok or not app.archive:IsTable(sessions) then
        return {}
    end
    local result = {}
    for _, session in ipairs(sessions) do
        local copy =
            app.archive:CopyFields(session, { sessionID = "number", name = "string", durationSeconds = "number" })
        if copy and copy.sessionID then
            copy.name = copy.name or ""
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
    if not ok or not app.archive:IsTable(session) then
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
    local ok, details
    if config.sessionID then
        ok, details = pcall(
            C_DamageMeter.GetCombatSessionSourceFromID,
            config.sessionID,
            meterType,
            source.sourceGUID,
            source.sourceCreatureID
        )
    else
        ok, details = pcall(
            C_DamageMeter.GetCombatSessionSourceFromType,
            Enum.DamageMeterSessionType[config.session] or Enum.DamageMeterSessionType.Current,
            meterType,
            source.sourceGUID,
            source.sourceCreatureID
        )
    end
    if not ok or not app.archive:IsTable(details) then
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
