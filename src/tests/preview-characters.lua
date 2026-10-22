-- Run from the root: lua src/tests/preview-characters.lua
local callbacks = { enter = function() end, exit = function() end }
local editing, combat = false, false
local random = math.random
local draws = 0
math.random = function(...)
    draws = draws + 1
    return random(...)
end
local lib = {}
function lib:IsInEditMode()
    return editing
end
function lib:RegisterCallback(event, callback)
    callbacks[event] = callback
end
InCombatLockdown = function()
    return combat
end
local core = {
    GetEditModeLibrary = function()
        return lib
    end,
}
assert(loadfile("Seamless/src/core/previewcharacters.lua"))("Seamless", { addon = core })
assert(core:GetPreviewCharacter("player") == nil)
editing = true
assert(core:GetPreviewCharacter("player") == nil, "empty catalogue")
local input = { name = "One", class = "PALADIN", health = 200, healthMax = 150 }
core:RegisterPreviewCharacter("one", input)
input.name = "mutated"
core:RegisterPreviewCharacter("two", { name = "Two", surname = "Surname", class = "MAGE", power = 0 })
local first = core:GetPreviewCharacter("player")
local second = core:GetPreviewCharacter("target")
assert(first.id ~= second.id, "no repeats before the bag is exhausted")
first.name = "mutated"
assert(core:GetPreviewCharacter("player").name ~= "mutated", "consumer receives a copy")
for _, record in ipairs({ core:GetPreviewCharacter("player"), core:GetPreviewCharacter("target") }) do
    assert(record.health <= record.healthMax)
    assert(record.name ~= "mutated", "registry owns its input")
    assert(record.level == "??" and record.powerType == "MANA")
end
combat = true
assert(core:GetPreviewCharacter("player") == nil)
combat = false
assert(core:GetPreviewCharacter("player").id == first.id, "combat does not reroll")
editing = false
local previousDraws = draws
callbacks.exit()
assert(core:GetPreviewCharacter("player") == nil)
editing = true
callbacks.enter()
assert(core:GetPreviewCharacter("player").id == first.id, "reopening Edit Mode preserves the player VIP")
assert(core:GetPreviewCharacter("target").id == second.id, "reopening Edit Mode preserves the target VIP")
assert(draws == previousDraws, "reopening Edit Mode does not reshuffle the bag")
local third = core:GetPreviewCharacter("tot")
assert(third ~= nil, "pool exhaustion starts another bag")
for i = 1, 3 do
    editing = false
    callbacks.exit()
    editing = true
    callbacks.enter()
    assert(core:GetPreviewCharacter("player").id == first.id)
    assert(core:GetPreviewCharacter("target").id == second.id)
    assert(core:GetPreviewCharacter("tot").id == third.id)
end
local function Reject(id, record)
    assert(not pcall(core.RegisterPreviewCharacter, core, id, record), "expected rejected record")
end
Reject("one", { name = "Duplicate", class = "MAGE" })
Reject("badclass", { name = "Bad", class = "NOPE" })
Reject("badname", { name = 42 })
Reject("badhealth", { name = "Bad", class = "MAGE", health = 0 / 0 })
Reject("badmax", { name = "Bad", class = "MAGE", healthMax = 0 })
Reject("badpower", { name = "Bad", class = "MAGE", power = -1 })
Reject("badreaction", { name = "Bad", class = "MAGE", reaction = 9 })
Reject("nested", { name = "Bad", class = "MAGE", guild = {} })
Reject("badsurname", { name = "Bad", class = "MAGE", surname = 42 })
-- Missing fields are allowed; fallback data belongs only to returned copies.
local fallbackCore = {
    GetEditModeLibrary = function()
        return lib
    end,
}
assert(loadfile("Seamless/src/core/previewcharacters.lua"))("Seamless", { addon = fallbackCore })
UNKNOWNOBJECT = "Unknown"
local missing = {}
fallbackCore:RegisterPreviewCharacter("missing", missing)
local fallback = fallbackCore:GetPreviewCharacter("missing")
assert(fallback.name == UNKNOWNOBJECT and fallback.guild == "" and fallback.realm == "")
assert(fallback.level == "??" and fallback.class == nil and fallback.displayTexture == nil)
assert(fallback.health == 100 and fallback.power == 100 and fallback.targetIcon == 0)
assert(fallback.female == nil and fallback.displayID == nil, "no invented identity metadata")
assert(next(missing) == nil, "fallbacks never fill the authored record")
fallbackCore:RegisterPreviewCharacter("absolute", { health = 5211, power = 6382, level = "??", female = false })
local absolute = fallbackCore:GetPreviewCharacter("absolute")
if absolute.id ~= "absolute" then
    absolute = fallbackCore:GetPreviewCharacter("absolute:next")
end
assert(absolute.health == 5211 and absolute.healthMax == 5211)
assert(absolute.power == 6382 and absolute.powerMax == 6382 and absolute.female == false)
print("Preview character catalogue and fallback tests passed")
math.random = random
