-- lua src/tests/preview-catalogue.lua [path-to-original-VIP-Lua]
local records, order = {}, {}
local core = {}
function core:RegisterPreviewCharacter(id, record)
    assert(not records[id], "duplicate VIP ID")
    records[id] = record
    order[#order + 1] = id
end
assert(loadfile("Seamless/src/core/previewcharacters-data.lua"))("Seamless", { addon = core })
assert(#order == 15)
for _, record in pairs(records) do
    if record.displayTexture then
        local relative = assert(record.displayTexture:match("^Interface/AddOns/(.+)$"))
        local file = assert(io.open(relative .. ".blp", "rb"))
        assert(file:read(4) == "BLP2", "portrait is a bundled BLP")
        file:close()
    end
end
assert(records.dratini.level == "??" and records.norbert.level == "??")
assert(records.matada.displayTexture == nil)
assert(records.marnik.realm == nil and records.marnik.guild == nil and records.marnik.race == nil)
assert(records.baldvin.female == nil and records.theodore.female == nil)
assert(records.turqoise.displayID == nil and records.turqoise.displayTexture == records.jagrune.displayTexture)
assert(records.theunder.name == "Theunder ", "preserve the supplied name verbatim")
assert(records.theodore.health == 5211 and records.theodore.power == 6382)
assert(records.theodore.healthMax == nil and records.theodore.powerMax == nil, "missing maxima stay absent")

-- Optional migration audit compares actual active Lua values, ignoring old commented-out guesses.
if arg[1] then
    local original = {}
    LibStub = function()
        return {
            GetAddon = function()
                return original
            end,
        }
    end
    assert(loadfile(arg[1]))()
    assert(#original.VIPTable == #order)
    local rename = { hpAmount = "health", energyAmount = "power", extra = "classification" }
    for i, old in ipairs(original.VIPTable) do
        local migrated = records[order[i]]
        local expected = {}
        for key, value in pairs(old) do
            local newKey = rename[key] or key
            if key == "level" then
                value = tonumber(value) or value
            end
            if key == "displayTexture" then
                value = "Interface/AddOns/Seamless/assets/VIP/" .. value
            end
            if value == "" then
                value = nil -- Empty source fields remain commented out, not fabricated.
            end
            expected[newKey] = value
            assert(migrated[newKey] == value, order[i] .. ": changed source value " .. key)
        end
        for key, value in pairs(migrated) do
            assert(expected[key] == value, order[i] .. ": invented field " .. key)
        end
    end
end
-- Exercise the real validator and resolver with every shipped record, not only the data loader.
local lib = {
    IsInEditMode = function()
        return true
    end,
    RegisterCallback = function() end,
}
local runtime = {
    GetEditModeLibrary = function()
        return lib
    end,
}
InCombatLockdown = function()
    return false
end
assert(loadfile("Seamless/src/core/previewcharacters.lua"))("Seamless", { addon = runtime })
assert(loadfile("Seamless/src/core/previewcharacters-data.lua"))("Seamless", { addon = runtime })
local seen = {}
for i = 1, #order do
    local character = assert(runtime:GetPreviewCharacter("audit:" .. i))
    assert(not seen[character.id], "all VIPs occur before a repeat")
    seen[character.id] = true
    if character.id == "theodore" then
        assert(character.health == 5211 and character.power == 6382, "absolute values survive resolution")
    end
end
print("VIP catalogue assets and migration tests passed")
