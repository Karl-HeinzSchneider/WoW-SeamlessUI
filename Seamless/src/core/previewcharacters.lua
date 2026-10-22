---@type string, SeamlessCore
local _, app = ...

-- Data only: consumers render these records without replacing unit APIs or secure attributes.
local addon = app.addon
local lib = addon:GetEditModeLibrary()
local characters, ids, bag, assigned = {}, {}, {}, {}
local classes = {
    WARRIOR = true,
    PALADIN = true,
    HUNTER = true,
    ROGUE = true,
    PRIEST = true,
    DEATHKNIGHT = true,
    SHAMAN = true,
    MAGE = true,
    WARLOCK = true,
    DRUID = true,
    MONK = true,
    DEMONHUNTER = true,
    EVOKER = true,
}

local function Copy(record)
    local copy = {}
    for key, value in pairs(record) do
        copy[key] = value
    end
    return copy
end

local function Number(value, fallback, minimum)
    if value == nil then
        return fallback
    end
    assert(
        type(value) == "number" and value == value and value < math.huge and value >= minimum,
        "Invalid preview number"
    )
    return value
end

---Register a flat character record at load time, before Edit Mode opens. Returned records are copies.
function addon:RegisterPreviewCharacter(id, record)
    assert(type(id) == "string" and id ~= "" and not ids[id], "Duplicate or invalid preview character ID")
    assert(type(record) == "table" and type(record.name) == "string" and record.name ~= "", "Preview needs a name")
    assert(classes[record.class], "Preview needs a class token")
    local character = Copy(record)
    for key, value in pairs(character) do
        assert(
            type(value) == "string" or type(value) == "number" or type(value) == "boolean",
            "Preview fields must be scalar"
        )
    end
    for _, key in ipairs({
        "surname",
        "titleBefore",
        "titleAfter",
        "realm",
        "guild",
        "guildRank",
        "zone",
        "race",
        "powerType",
        "role",
        "faction",
        "classification",
        "displayTexture",
    }) do
        assert(character[key] == nil or type(character[key]) == "string", "Invalid preview text field: " .. key)
    end
    character.id = id
    character.healthMax = Number(character.healthMax, 100, 1)
    character.health = math.min(Number(character.health, character.healthMax, 0), character.healthMax)
    character.powerMax = Number(character.powerMax, 100, 1)
    character.power = math.min(Number(character.power, character.powerMax, 0), character.powerMax)
    character.powerType = character.powerType or "MANA"
    character.level = Number(character.level, 85, 1)
    character.reaction = Number(character.reaction, 5, 1)
    assert(character.reaction <= 8, "Invalid preview reaction")
    characters[#characters + 1] = character
    ids[id] = character
    bag = {}
end

---One stable assignment per consumer ID for each Edit Mode session. Exhaust the bag before repeats.
function addon:GetPreviewCharacter(consumer)
    assert(type(consumer) == "string" and consumer ~= "", "Preview consumer ID is required")
    if not lib:IsInEditMode() or InCombatLockdown() or #characters == 0 then
        return nil
    end
    if not assigned[consumer] then
        if #bag == 0 then
            for i = 1, #characters do
                bag[i] = characters[i]
            end
            for i = #bag, 2, -1 do
                local j = math.random(i)
                bag[i], bag[j] = bag[j], bag[i]
            end
        end
        assigned[consumer] = table.remove(bag)
    end
    return Copy(assigned[consumer])
end

local function Reset()
    bag, assigned = {}, {}
end
lib:RegisterCallback("enter", Reset)
lib:RegisterCallback("exit", Reset)
