---@type string, SeamlessDamageMeter
local _, app = ...

-- Keep the client API behind this adapter; windows never collect combat logs.
-- Categories and order follow the client's meter; labels use its strings when present.
app.categories = {
    { key = "Damage", label = DAMAGE_METER_CATEGORY_DAMAGE or "Damage" },
    { key = "Healing", label = DAMAGE_METER_CATEGORY_HEALING or "Healing" },
    { key = "Actions", label = DAMAGE_METER_CATEGORY_ACTIONS or "Actions" },
}

app.statistics = {
    { key = "DamageDone", category = "Damage", label = DAMAGE_METER_TYPE_DAMAGE_DONE or "Damage done" },
    { key = "Dps", category = "Damage", label = DAMAGE_METER_TYPE_DPS or "Damage per second", rate = true },
    { key = "DamageTaken", category = "Damage", label = DAMAGE_METER_TYPE_DAMAGE_TAKEN or "Damage taken" },
    {
        key = "AvoidableDamageTaken",
        category = "Damage",
        label = DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN or "Avoidable damage taken",
    },
    {
        key = "EnemyDamageTaken",
        category = "Damage",
        label = DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN or "Enemy damage taken",
        noIcon = true,
    },
    { key = "HealingDone", category = "Healing", label = DAMAGE_METER_TYPE_HEALING_DONE or "Healing done" },
    { key = "Hps", category = "Healing", label = DAMAGE_METER_TYPE_HPS or "Healing per second", rate = true },
    { key = "Absorbs", category = "Healing", label = DAMAGE_METER_TYPE_ABSORBS or "Absorbs" },
    { key = "Interrupts", category = "Actions", label = DAMAGE_METER_TYPE_INTERRUPTS or "Interrupts", count = true },
    { key = "Dispels", category = "Actions", label = DAMAGE_METER_TYPE_DISPELS or "Dispels", count = true },
}

function app:IsAvailable()
    return C_DamageMeter ~= nil and Enum.DamageMeterType ~= nil
end

function app:IsStatisticAvailable(statistic)
    return self:IsAvailable() and Enum.DamageMeterType[statistic.key] ~= nil
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
