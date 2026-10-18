-- Run from the repository root: lua src/tests/damage-meter-icons.lua
local paths = {}
function GetFileIDFromPath(path)
    paths[#paths + 1] = path
    return #paths
end

local app = {}
assert(loadfile("SeamlessDamageMeter/src/icons.lua"))("SeamlessDamageMeter", app)
assert(#paths == 35, "Only the selected specialization artwork is bundled")
for iconID, path in ipairs(paths) do
    local name = assert(path:match("^Interface\\Icons\\(.+)%.blp$"))
    local replacement = app:GetSpecializationIcon(iconID)
    assert(replacement == "Interface\\AddOns\\SeamlessDamageMeter\\Textures\\Icons\\" .. name .. ".tga")
    local file = assert(io.open("SeamlessDamageMeter/Textures/Icons/" .. name .. ".tga", "rb"))
    local header = file:read(18)
    file:close()
    assert(header:byte(3) == 2, "Replacement must be an uncompressed RGB TGA")
    assert(header:byte(13) == 128 and header:byte(14) == 0, "Replacement width is 128")
    assert(header:byte(15) == 128 and header:byte(16) == 0, "Replacement height is 128")
    assert(header:byte(17) == 32, "Replacement includes an alpha channel")
end
assert(app:GetSpecializationIcon(0) == 0)
assert(app:GetSpecializationIcon(987654321) == 987654321, "Unmapped icons retain their original file ID")

GetFileIDFromPath = function()
    return 0
end
local unavailable = {}
assert(loadfile("SeamlessDamageMeter/src/icons.lua"))("SeamlessDamageMeter", unavailable)
assert(unavailable:GetSpecializationIcon(0) == 0, "Missing client paths never register the invalid file ID")
assert(unavailable:GetSpecializationIcon(1) == 1)
print("PASS: HD specialization mapping, bundled TGA assets and original-icon fallbacks")
