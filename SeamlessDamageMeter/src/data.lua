---@type string, SeamlessDamageMeter
local _, app = ...

-- Rendering facade. All combat queries belong to the central service.
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
    { key = "EnemyDamageTaken", label = DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN or "Enemy damage taken" },
    { key = "Deaths", label = DAMAGE_METER_TYPE_DEATHS or "Deaths" },
    { key = "Threat", label = "Threat", liveOnly = true },
}

function app:IsAvailable()
    return self.live:IsAvailable()
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
    return self.combatService:GetSession(config, self:GetStatistic(config.statistic).key)
end

function app:GetSourceDetails(config, source)
    return self.combatService:GetDetails(config, source, self:GetStatistic(config.statistic).key)
end

function app:GetTargetBreakdown(config, source)
    return self.combatService:GetPlayerTargets(config, source)
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
                threatPercentage = key == "Threat" and (100 - (index - 1) * 10) or nil,
            }
        end
        session.maxAmount = session.combatSources[1].totalAmount
        previewSessions[key] = session
    end
    return previewSessions[key]
end
