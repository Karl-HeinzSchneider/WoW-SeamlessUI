-- Native preview lifecycle: lua src/tests/preview-unitframes.lua
local editing, combat, enabled = false, false, true
local callbacks, hooks, events = {}, {}, {}
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
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, callback)
            events[#events + 1] = callback
        end,
    }
end
hooksecurefunc = function(target, method, callback)
    if type(target) == "string" then
        hooks[target] = method
    else
        local original = target[method]
        target[method] = function(...)
            original(...)
            callback(...)
        end
    end
end
local player = { unit = "player", name = "live", portrait = "live", health = 42 }
local pet = { unit = "pet", name = "pet" }
local party1 = {
    unit = "party1",
    GetName = function()
        return "PartyMember1"
    end,
}
local party2 = {
    unit = "party2",
    GetName = function()
        return "PartyMember2"
    end,
}
local app = { core = {}, addon = {}, unitFrames = {}, totMover = { Refresh = function() end } }
function app.addon:IsEnabled()
    return enabled
end
function app.addon:NewModule(_, module)
    -- AceAddon returns a distinct instance inheriting the prototype. Lifecycle methods such as
    -- IsEnabled exist on that instance, not on the prototype captured by file-local callbacks.
    return setmetatable({
        enabled = true,
        IsEnabled = function(self)
            return self.enabled
        end,
    }, { __index = module })
end
function app.core:GetEditModeLibrary()
    return lib
end
local assignments, requests = {}, 0
function app.core:GetPreviewCharacter(id)
    requests = requests + 1
    assignments[id] = assignments[id] or { name = "VIP:" .. id, class = "PALADIN" }
    return assignments[id]
end
function app.unitFrames:All()
    return { player, pet, party1, party2 }
end
function app.unitFrames:KeyOf(frame)
    if frame == player then
        return "player"
    end
    if frame == pet then
        return "pet"
    end
    if frame == party1 or frame == party2 then
        return "party"
    end
end
for _, feature in ipairs({ "nameDisplay", "classIcon", "healthColor", "legacyLayout" }) do
    app[feature] = { Refresh = function() end }
end
function app.nameDisplay:ApplyPreview(frame, key)
    frame.name = app.previewCharacters:Get(frame, key).name
end
function app.classIcon:ApplyPreview(frame, key)
    frame.portrait = app.previewCharacters:Get(frame, key).class
end
function app.healthColor:ApplyPreview() end
local restored = 0
UnitFrame_Update = function(frame)
    frame.name, frame.portrait = "current live", "current portrait"
    restored = restored + 1
    hooks.UnitFrame_Update(frame)
end
securecall = function(name, ...)
    _G[name](...)
end
assert(loadfile("SeamlessUnitframes/src/core/previewcharacters.lua"))("SeamlessUnitframes", app)
local module = app.previewCharacters
module:OnInitialize()
hooks.UnitFramePortrait_Update(pet)
assert(pet.name == "pet", "pet updates before enable must not call lifecycle APIs on the prototype")
module:OnEnable()
assert(player.name == "live" and requests == 0)
editing = true
callbacks.enter()
assert(player.name == "VIP:unitframes:player" and player.portrait == "PALADIN")
assert(player.unit == "player" and player.health == 42, "native gameplay data stays live")
assert(pet.name == "pet", "pets retain native data")
assert(party1.name ~= party2.name, "party members have independent consumer IDs")
assert(module:Get(nil, "player") == nil)
local count = requests
module:Refresh()
hooks.UnitFramePortrait_Update(player)
assert(requests == count, "cached assignment across updates")
UnitFrame_Update(player)
assert(player.name == "VIP:unitframes:player", "native updates reapply preview identity")
combat = true
events[1]()
assert(player.name == "current live" and player.portrait == "current portrait")
assert(module:Get(player) == nil)
combat = false
events[1]()
assert(player.name == "VIP:unitframes:player")
module.enabled = false
module:OnDisable()
assert(player.name == "current live")
module.enabled = true
module:OnEnable()
assert(player.name == "VIP:unitframes:player")
editing = false
callbacks.exit()
assert(player.name == "current live" and restored >= 4)
local atExit = restored
callbacks.exit()
assert(restored == atExit, "restoration runs only for frames we painted")
editing = true
callbacks.enter()
enabled = false
module:Refresh()
assert(player.name == "current live", "parent addon disable restores")
print("Native preview lifecycle tests passed")
