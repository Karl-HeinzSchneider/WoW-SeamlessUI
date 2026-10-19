-- Run from the repository root: lua src/tests/darkmode.lua
unpack = unpack or table.unpack
local root = "SeamlessDarkmode/src/"
local app = {}
local enabled = true
local addon = {}
function addon:IsEnabled()
    return enabled
end
function LibStub()
    return {
        GetAddon = function()
            return {}
        end,
        NewAddon = function()
            return addon
        end,
    }
end
local function texture(alpha)
    local t = { color = { 1, 1, 1, alpha or 1 } }
    function t:GetVertexColor()
        return unpack(self.color)
    end
    function t:SetVertexColor(r, g, b, a)
        self.color = { r, g, b, a or 1 }
    end
    return t
end
local function equal(actual, expected, context)
    for i, v in ipairs(expected) do
        assert(math.abs(actual[i] - v) < 1e-6, context .. " component " .. i .. ": " .. tostring(actual[i]))
    end
end

-- Only the frames a function names exist; everything else must be skipped as nil.
local frame = texture(0.5)
local portrait = texture()
local circle = texture()
PlayerFrame = {
    PlayerFrameContainer = { FrameTexture = frame, Portrait = portrait },
    PlayerFrameContent = { PlayerFrameContentMain = { LevelBackgroundCircle = circle } },
}
local targetFrame = texture()
local targetCircle = texture()
TargetFrame = {
    TargetFrameContainer = { FrameTexture = targetFrame },
    TargetFrameContent = { TargetFrameContentMain = { LevelBackgroundCircle = targetCircle } },
}
MinimapCompassTexture = texture()
local ring = texture()
local slot = texture()
local procBorder = texture()
MainActionBar = {
    BorderArt = texture(),
    EndCaps = { LeftEndCap = { Texture = texture() }, RightEndCap = { Texture = texture() } },
    actionButtons = { { NormalTexture = ring, SlotArt = slot, Border = procBorder } },
}

assert(loadfile(root .. "frames.lua"))("SeamlessDarkmode", app)
assert(loadfile(root .. "core.lua"))("SeamlessDarkmode", app)
app.db = {
    profile = {
        enabled = true,
        color = { r = 0.2, g = 0.3, b = 0.4 },
        groups = { unitframes = true, minimap = true, actionbars = true },
    },
}

addon:Refresh()
equal(frame.color, { 0.2, 0.3, 0.4, 0.5 }, "frame tinted, alpha kept")
equal(circle.color, { 0.2, 0.3, 0.4, 1 }, "player level circle tinted")
equal(portrait.color, { 1, 1, 1, 1 }, "portrait untouched")
equal(targetFrame.color, { 0.2, 0.3, 0.4, 1 }, "target frame tinted")
equal(targetCircle.color, { 0.2, 0.3, 0.4, 1 }, "target level circle tinted")
equal(MinimapCompassTexture.color, { 0.2, 0.3, 0.4, 1 }, "minimap ring tinted")
equal(ring.color, { 0.2, 0.3, 0.4, 1 }, "action button ring tinted")
equal(slot.color, { 0.2, 0.3, 0.4, 1 }, "action button slot tinted")
equal(MainActionBar.EndCaps.LeftEndCap.Texture.color, { 0.2, 0.3, 0.4, 1 }, "end cap tinted")
equal(procBorder.color, { 1, 1, 1, 1 }, "proc border untouched")

app.db.profile.color = { r = 0.1, g = 0.1, b = 0.1 }
addon:Refresh()
equal(frame.color, { 0.1, 0.1, 0.1, 0.5 }, "color change")

app.db.profile.groups.unitframes = false
addon:Refresh()
equal(frame.color, { 1, 1, 1, 0.5 }, "unit frames off restores")
equal(ring.color, { 0.1, 0.1, 0.1, 1 }, "other groups stay tinted")
app.db.profile.groups.unitframes = true

app.db.profile.enabled = false
addon:Refresh()
equal(frame.color, { 1, 1, 1, 0.5 }, "master switch restores")
equal(MinimapCompassTexture.color, { 1, 1, 1, 1 }, "master switch restores minimap")
equal(targetCircle.color, { 1, 1, 1, 1 }, "master switch restores target")

app.db.profile.enabled = true
addon:Refresh()
addon:OnDisable()
enabled = false
addon:Refresh()
equal(frame.color, { 1, 1, 1, 0.5 }, "addon disable restores")
equal(circle.color, { 1, 1, 1, 1 }, "addon disable restores level circle")
equal(ring.color, { 1, 1, 1, 1 }, "addon disable restores action buttons")

print("PASS: unit frames, minimap, action buttons, untouched indicators, group/master toggles, disable")
