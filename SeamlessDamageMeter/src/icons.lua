---@type string, SeamlessDamageMeter
local _, app = ...

-- Supplied Clean Icons artwork, including classic talent-tree and newer spec variants.
-- Resolve original paths through the client rather than hard-coding file IDs.
local names = {
    "Ability_BackStab",
    "Ability_Druid_CatForm",
    "Ability_Druid_Maul",
    "Ability_Druid_Mangle2",
    "Ability_Hunter_BeastTaming",
    "Ability_Hunter_SwiftStrike",
    "Ability_Marksmanship",
    "Ability_Rogue_Ambush",
    "Ability_Rogue_Eviscerate",
    "Ability_Stealth",
    "Ability_Warrior_DecisiveStrike",
    "Ability_Warrior_DefensiveStance",
    "Ability_Warrior_InnerRage",
    "Ability_Warrior_SavageBlow",
    "Spell_Fire_FireBolt02",
    "Spell_Frost_FrostBolt02",
    "Spell_Holy_AuraOfLight",
    "Spell_Holy_DevotionAura",
    "Spell_Holy_GuardianSpirit",
    "Spell_Holy_HolyBolt",
    "Spell_Holy_MagicalSentry",
    "Spell_Holy_PowerWordShield",
    "Spell_Holy_WordFortitude",
    "Spell_Nature_HealingTouch",
    "Spell_Nature_Lightning",
    "Spell_Nature_LightningShield",
    "Spell_Nature_MagicImmunity",
    "Spell_Nature_Rejuvenation",
    "Spell_Nature_StarFall",
    "Spell_Shadow_DeathCoil",
    "Spell_Shadow_Metamorphosis",
    "Spell_Shadow_RainOfFire",
    "Spell_Shadow_ShadowWordPain",
    "Spell_Shaman_ImprovedStormstrike",
    "Spell_Shaman_SpiritLink",
}

local replacements = {}
for _, name in ipairs(names) do
    local iconID = GetFileIDFromPath("Interface\\Icons\\" .. name .. ".blp")
    if iconID and iconID ~= 0 then
        replacements[iconID] = "Interface\\AddOns\\SeamlessDamageMeter\\Textures\\Icons\\" .. name .. ".tga"
    end
end

function app:GetSpecializationIcon(iconID)
    return replacements[iconID] or iconID
end
