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

local textFields = {
    "name",
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
}

-- Resolve missing data on returned copies, never fill gaps in the authored VIP records.
local function Resolve(record)
    local character = Copy(record)
    for _, key in ipairs(textFields) do
        character[key] = character[key] or ""
    end
    if character.name == "" then
        character.name = UNKNOWNOBJECT or UNKNOWN or ""
    end
    if character.displayTexture == "" then
        character.displayTexture = nil
    end
    if character.class == "" then
        character.class = nil
    end
    character.healthMax = character.healthMax or math.max(100, character.health or 0)
    character.health = math.min(character.health or character.healthMax, character.healthMax)
    character.powerMax = character.powerMax or math.max(100, character.power or 0)
    character.power = math.min(character.power or character.powerMax, character.powerMax)
    if character.powerType == "" then
        character.powerType = "MANA"
    end
    character.level = character.level or "??"
    character.reaction = character.reaction or 5
    character.targetIcon = character.targetIcon or 0
    return character
end

---Register a flat character record at load time, before Edit Mode opens. Returned records are copies.
function addon:RegisterPreviewCharacter(id, record)
    assert(type(id) == "string" and id ~= "" and not ids[id], "Duplicate or invalid preview character ID")
    assert(type(record) == "table", "Preview needs a record")
    assert(record.class == nil or record.class == "" or classes[record.class], "Invalid preview class token")
    local character = Copy(record)
    for key, value in pairs(character) do
        assert(
            type(value) == "string" or type(value) == "number" or type(value) == "boolean",
            "Preview fields must be scalar"
        )
    end
    for _, key in ipairs(textFields) do
        assert(character[key] == nil or type(character[key]) == "string", "Invalid preview text field: " .. key)
    end
    character.id = id
    Number(character.healthMax, nil, 1)
    Number(character.health, nil, 0)
    Number(character.powerMax, nil, 1)
    Number(character.power, nil, 0)
    if character.level ~= "??" then
        Number(character.level, nil, 1)
    end
    local reaction = Number(character.reaction, 5, 1)
    assert(reaction <= 8 and reaction % 1 == 0, "Invalid preview reaction")
    local targetIcon = Number(character.targetIcon, 0, 0)
    assert(targetIcon <= 8 and targetIcon % 1 == 0, "Invalid preview target icon")
    Number(character.displayID, nil, 1)
    assert(character.female == nil or type(character.female) == "boolean", "Invalid preview sex")
    characters[#characters + 1] = character
    ids[id] = character
    bag = {}
end

---One stable assignment per consumer ID until logout or UI reload. Exhaust the bag before repeats.
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
    return Resolve(assigned[consumer])
end
