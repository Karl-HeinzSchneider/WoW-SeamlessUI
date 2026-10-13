---@type string, SeamlessDamageMeter
local _, app = ...

-- Keep the client API behind this adapter; windows never collect combat logs.
app.statistics = {
    { key = "DamageDone", label = DAMAGE_METER_TYPE_DAMAGE_DONE or "Damage done" },
    { key = "Dps", label = DAMAGE_METER_TYPE_DPS or "DPS", rate = true },
    { key = "HealingDone", label = DAMAGE_METER_TYPE_HEALING_DONE or "Healing done" },
    { key = "Hps", label = DAMAGE_METER_TYPE_HPS or "HPS", rate = true },
    { key = "Absorbs", label = DAMAGE_METER_TYPE_ABSORBS or "Absorbs" },
    { key = "Interrupts", label = DAMAGE_METER_TYPE_INTERRUPTS or "Interrupts" },
    { key = "Dispels", label = DAMAGE_METER_TYPE_DISPELS or "Dispels" },
    { key = "DamageTaken", label = DAMAGE_METER_TYPE_DAMAGE_TAKEN or "Damage taken" },
    { key = "AvoidableDamageTaken", label = DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN or "Avoidable damage taken" },
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
    if self.IsEditingWindows and self:IsEditingWindows() then
        return self:GetPreviewSession(config)
    end
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

local previewCharacters = {
    { "Jaina", "MAGE", 125000 },
    { "Thrall", "SHAMAN", 112000 },
    { "Grommash", "WARRIOR", 98000 },
    { "Rexxar", "HUNTER", 85000 },
    { "Gul'dan", "WARLOCK", 71000 },
    { "Garona", "ROGUE", 59000 },
    { "Uther", "PALADIN", 46000 },
    { "Malfurion", "DRUID", 33000 },
    { "Tyrande", "PRIEST", 21000 },
}
local previewSessions = {}

function app:GetPreviewSession(config)
    local key = config.statistic
    if not previewSessions[key] then
        local session = { combatSources = {}, durationSeconds = 60, isPreview = true }
        local counts = key == "Interrupts" or key == "Dispels"
        for index, character in ipairs(previewCharacters) do
            local amount = counts and (30 - index * 3) or character[3]
            session.combatSources[index] = {
                name = character[1],
                classFilename = character[2],
                totalAmount = amount,
                amountPerSecond = amount / session.durationSeconds,
            }
        end
        session.maxAmount = session.combatSources[1].totalAmount
        previewSessions[key] = session
    end
    return previewSessions[key]
end
