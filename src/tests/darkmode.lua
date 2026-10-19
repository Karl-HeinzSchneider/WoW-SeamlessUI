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
PlayerFrame = { PlayerFrameContainer = { FrameTexture = frame, Portrait = portrait } }
local ring = texture()
ActionButton1 = { NormalTexture = ring, Border = texture() }
local edge = texture()
ContainerFrame1 = { NineSlice = { TopEdge = edge, Center = texture() } }

assert(loadfile(root .. "frames.lua"))("SeamlessDarkmode", app)
assert(loadfile(root .. "core.lua"))("SeamlessDarkmode", app)
app.db = {
    profile = {
        enabled = true,
        color = { r = 0.2, g = 0.3, b = 0.4 },
        groups = { unitframes = true, actionbars = true, minimap = true, bags = true },
    },
}

addon:Refresh()
equal(frame.color, { 0.2, 0.3, 0.4, 0.5 }, "frame tinted, alpha kept")
equal(portrait.color, { 1, 1, 1, 1 }, "portrait untouched")
equal(ring.color, { 0.2, 0.3, 0.4, 1 }, "action button ring tinted")
equal(ActionButton1.Border.color, { 1, 1, 1, 1 }, "proc border untouched")
equal(edge.color, { 0.2, 0.3, 0.4, 1 }, "bag border tinted")
equal(ContainerFrame1.NineSlice.Center.color, { 1, 1, 1, 1 }, "bag background untouched")

app.db.profile.color = { r = 0.1, g = 0.1, b = 0.1 }
addon:Refresh()
equal(frame.color, { 0.1, 0.1, 0.1, 0.5 }, "color change")

app.db.profile.groups.unitframes = false
addon:Refresh()
equal(frame.color, { 1, 1, 1, 0.5 }, "group off restores")
equal(ring.color, { 0.1, 0.1, 0.1, 1 }, "other groups stay tinted")

app.db.profile.enabled = false
addon:Refresh()
equal(ring.color, { 1, 1, 1, 1 }, "master switch restores")

app.db.profile.enabled, app.db.profile.groups.unitframes = true, true
addon:Refresh()
addon:OnDisable()
enabled = false
addon:Refresh()
equal(frame.color, { 1, 1, 1, 0.5 }, "addon disable restores")
equal(edge.color, { 1, 1, 1, 1 }, "addon disable restores bags")

print("PASS: tint, alpha, untouched indicators, color change, group/master toggles, disable")
