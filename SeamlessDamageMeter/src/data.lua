---@type string, SeamlessDamageMeter
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Rendering facade. All combat queries belong to the central service.
app.statistics = {
    {
        key = "DamageDone",
        label = L["Damage done"],
        icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
    },
    {
        key = "Dps",
        label = L["DPS"],
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        rate = true,
    },
    {
        key = "HealingDone",
        label = L["Healing done"],
        icon = "Interface\\Icons\\Spell_Nature_HealingTouch",
    },
    {
        key = "Hps",
        label = L["HPS"],
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        rate = true,
    },
    {
        key = "Absorbs",
        label = L["Absorbs"],
        icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    },
    {
        key = "Interrupts",
        label = L["Interrupts"],
        icon = "Interface\\Icons\\Ability_Kick",
    },
    {
        key = "Dispels",
        label = L["Dispels"],
        icon = "Interface\\Icons\\Spell_Holy_Renew",
    },
    {
        key = "DamageTaken",
        label = L["Damage taken"],
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    },
    {
        key = "AvoidableDamageTaken",
        label = L["Avoidable damage taken"],
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    },
    {
        key = "EnemyDamageTaken",
        label = L["Enemy damage taken"],
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    },
    { key = "Deaths", label = L["Deaths"], icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
    { key = "Threat", label = L["Threat"], icon = "Interface\\Icons\\INV_Misc_QuestionMark", liveOnly = true },
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
        local session = { combatSources = {}, durationSeconds = 60, totalAmount = 0, isPreview = true }
        local counts = key == "Interrupts" or key == "Dispels"
        for index, character in ipairs(previewCharacters) do
            local amount = counts and (30 - index * 3) or character[3]
            session.totalAmount = session.totalAmount + amount
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
