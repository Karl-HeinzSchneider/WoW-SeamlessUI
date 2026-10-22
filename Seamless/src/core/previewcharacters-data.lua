---@type string, SeamlessCore
local _, app = ...

-- The shipped VIP catalogue. Add records here; these are character names, not locale keys.
-- Optional portraits must be existing .blp/.tga assets, using a full Interface path.
app.addon:RegisterPreviewCharacter("zimtschnecke", {
    name = "Zimtschnecke",
    titleAfter = ", Death's Demise",
    realm = "Everlook",
    guild = "Zimtschneckendepot",
    guildRank = "Oberschnecke",
    zone = "Stormwind City",
    race = "Human",
    female = true,
    level = 85,
    class = "PALADIN",
    powerType = "MANA",
    health = 100,
    power = 100,
    role = "TANK",
    classification = "worldboss",
    displayID = 176,
    -- displayTexture = "Interface\\AddOns\\Seamless\\assets\\VIP\\zimtschnecke128",
})
