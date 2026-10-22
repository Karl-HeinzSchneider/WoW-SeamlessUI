-- Run from the root: lua src/tests/preview-characters.lua
local callbacks = {}
local editing, combat = false, false
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
assert(core:GetPreviewCharacter("tot") ~= nil, "pool exhaustion starts another bag")
first.name = "mutated"
assert(core:GetPreviewCharacter("player").name ~= "mutated", "consumer receives a copy")
for _, record in ipairs({ core:GetPreviewCharacter("player"), core:GetPreviewCharacter("target") }) do
    assert(record.health <= record.healthMax)
    assert(record.name ~= "mutated", "registry owns its input")
    assert(record.level == 85 and record.powerType == "MANA")
end
combat = true
assert(core:GetPreviewCharacter("player") == nil)
combat = false
assert(core:GetPreviewCharacter("player").id == first.id, "combat does not reroll")
editing = false
callbacks.exit()
assert(core:GetPreviewCharacter("player") == nil)
editing = true
callbacks.enter()
local seen = {}
for i = 1, 2 do
    local record = core:GetPreviewCharacter("session2:" .. i)
    assert(not seen[record.id])
    seen[record.id] = true
end
local function Reject(id, record)
    assert(not pcall(core.RegisterPreviewCharacter, core, id, record), "expected rejected record")
end
Reject("one", { name = "Duplicate", class = "MAGE" })
Reject("badclass", { name = "Bad", class = "NOPE" })
Reject("badname", { class = "MAGE" })
Reject("badhealth", { name = "Bad", class = "MAGE", health = 0 / 0 })
Reject("badmax", { name = "Bad", class = "MAGE", healthMax = 0 })
Reject("badpower", { name = "Bad", class = "MAGE", power = -1 })
Reject("badreaction", { name = "Bad", class = "MAGE", reaction = 9 })
Reject("nested", { name = "Bad", class = "MAGE", guild = {} })
Reject("badsurname", { name = "Bad", class = "MAGE", surname = 42 })
print("Preview character catalogue tests passed")
