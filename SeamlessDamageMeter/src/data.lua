---@type string, SeamlessDamageMeter
local _, app = ...

-- Keep the client API behind this adapter; windows never collect combat logs.
app.statistics = {
    { key = "DamageDone", label = "Damage done" },
    { key = "Dps", label = "Damage per second", rate = true },
    { key = "HealingDone", label = "Healing done" },
    { key = "Hps", label = "Healing per second", rate = true },
    { key = "Absorbs", label = "Absorbs" },
    { key = "Interrupts", label = "Interrupts" },
    { key = "Dispels", label = "Dispels" },
    { key = "DamageTaken", label = "Damage taken" },
    { key = "AvoidableDamageTaken", label = "Avoidable damage taken" },
}

function app:IsAvailable()
    return C_DamageMeter ~= nil and Enum.DamageMeterType ~= nil
end

function app:GetStatistic(key)
    for _, statistic in ipairs(self.statistics) do
        if statistic.key == key then
            return statistic
        end
    end
    return self.statistics[1]
end

function app:GetSession(config)
    if not self:IsAvailable() then
        return nil, "This client does not provide the damage meter API."
    end
    local available, reason = C_DamageMeter.IsDamageMeterAvailable()
    if not available then
        return nil, reason
    end
    if not C_CVar.GetCVarBool("damageMeterEnabled") then
        return nil, "Combat tracking is disabled. Enable it in Seamless > Damage Meter."
    end
    local statistic = self:GetStatistic(config.statistic)
    local meterType = Enum.DamageMeterType[statistic.key]
    if meterType == nil then
        return nil, "This statistic is unavailable on this client."
    end
    -- A saved historical session may disappear when Blizzard clears its history.
    if config.sessionID then
        for _, session in ipairs(C_DamageMeter.GetAvailableCombatSessions()) do
            if session.sessionID == config.sessionID then
                return C_DamageMeter.GetCombatSessionFromID(config.sessionID, meterType)
            end
        end
        return nil, "This fight is no longer available. Select another session."
    end
    return C_DamageMeter.GetCombatSessionFromType(
        Enum.DamageMeterSessionType[config.session] or Enum.DamageMeterSessionType.Current,
        meterType
    )
end
