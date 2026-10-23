-- Run from the repository root: lua src/tests/damage-meter-blizzard.lua
-- Blizzard's meter must never run addon code or be touched by it; we only open the game's settings.
unpack = unpack or table.unpack
local function Forbidden(name)
    return function()
        error(name .. " touches Blizzard's meter from addon code")
    end
end
DamageMeter = setmetatable({}, {
    __index = function(_, key)
        return Forbidden("DamageMeter." .. key)
    end,
})
C_CVar = { SetCVar = Forbidden("SetCVar") }
securecallfunction = Forbidden("securecallfunction")
hooksecurefunc = Forbidden("hooksecurefunc")
local opened
Settings = {
    ADVANCED_OPTIONS_CATEGORY_ID = 42,
    OpenToCategory = function(id)
        opened = id
    end,
}
local app = {}
assert(loadfile("SeamlessDamageMeter/src/blizzard.lua"))("SeamlessDamageMeter", app)
app:OpenBlizzardMeterSettings()
assert(opened == 42, "The game's settings own the damageMeterEnabled CVar")
print("PASS: Blizzard's meter is never touched; its on/off setting opens in the game's settings")
