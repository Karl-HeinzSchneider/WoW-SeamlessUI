-- Run from the repository root: lua src/tests/darkmode.lua
unpack = unpack or table.unpack
local root = "SeamlessDarkmode/src/"
local app = {}
local enabled = true
local addon = {}
function addon:IsEnabled()
    return enabled
end
local iconCallbacks = {}
-- LibDBIcon buttons by name.
local buttons = {}
local icons = {
    GetButtonList = function()
        local names = {}
        for name in pairs(buttons) do
            names[#names + 1] = name
        end
        return names
    end,
    GetMinimapButton = function(_, name)
        return buttons[name]
    end,
    RegisterCallback = function(owner, event, method)
        iconCallbacks[event] = function()
            owner[method](owner)
        end
    end,
    UnregisterCallback = function(_, event)
        iconCallbacks[event] = nil
    end,
}
function LibStub(major)
    if major == "LibDBIcon-1.0" then
        return icons
    end
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
local controls = {}
for i = 1, 3 do
    controls[i] = { StateTexture = texture(0.7), AddTexture = texture(), Text = texture() }
end
GameTimeFrame = controls[1]
MinimapCluster = { ZoneTextButton = {}, Tracking = { Button = controls[2] } }
AddonCompartmentFrame = controls[3]
local function checkControls(color, context)
    for _, control in ipairs(controls) do
        equal(control.StateTexture.color, { color, color, color, 0.7 }, context)
        equal(control.AddTexture.color, { 1, 1, 1, 1 }, "interaction highlight untouched")
        equal(control.Text.color, { 1, 1, 1, 1 }, "button text untouched")
    end
end
local ring = texture()
local iconTexture = texture()
buttons.Seamless = { border = ring, icon = iconTexture }

assert(loadfile(root .. "frames.lua"))("SeamlessDarkmode", app)
assert(loadfile(root .. "core.lua"))("SeamlessDarkmode", app)
app.db = {
    profile = {
        enabled = true,
        color = { r = 0.2, g = 0.3, b = 0.4 },
        groups = { unitframes = true, minimap = true },
    },
}

addon:OnEnable()
equal(frame.color, { 0.2, 0.3, 0.4, 0.5 }, "frame tinted, alpha kept")
equal(circle.color, { 0.2, 0.3, 0.4, 1 }, "player level circle tinted")
equal(portrait.color, { 1, 1, 1, 1 }, "portrait untouched")
equal(targetFrame.color, { 0.2, 0.3, 0.4, 1 }, "target frame tinted")
equal(targetCircle.color, { 0.2, 0.3, 0.4, 1 }, "target level circle tinted")
equal(MinimapCompassTexture.color, { 0.2, 0.3, 0.4, 1 }, "minimap ring tinted")
equal(ring.color, { 0.2, 0.3, 0.4, 1 }, "minimap button border tinted")
equal(iconTexture.color, { 1, 1, 1, 1 }, "minimap button icon untouched")
local lateRing = texture()
buttons.Late = { border = lateRing, icon = texture() }
iconCallbacks.LibDBIcon_IconCreated()
equal(lateRing.color, { 0.2, 0.3, 0.4, 1 }, "later minimap button tinted")

app.db.profile.color = { r = 0.1, g = 0.1, b = 0.1 }
addon:Refresh()
equal(frame.color, { 0.1, 0.1, 0.1, 0.5 }, "color change")
checkControls(0.1, "built-in minimap controls tinted")
app.db.profile.groups.minimap = false
addon:Refresh()
checkControls(1, "minimap group off restores controls")
app.db.profile.groups.minimap = true
addon:Refresh()
checkControls(0.1, "minimap group on tints controls again")

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
checkControls(1, "master switch restores controls")

app.db.profile.enabled = true
addon:Refresh()
addon:OnDisable()
enabled = false
addon:Refresh()
equal(frame.color, { 1, 1, 1, 0.5 }, "addon disable restores")
equal(circle.color, { 1, 1, 1, 1 }, "addon disable restores level circle")
equal(lateRing.color, { 1, 1, 1, 1 }, "addon disable restores minimap buttons")
assert(not iconCallbacks.LibDBIcon_IconCreated, "addon disable drops the button callback")
checkControls(1, "addon disable restores controls")

GameTimeFrame = nil
MinimapCluster = { ZoneTextButton = {}, Tracking = {} }
AddonCompartmentFrame = nil
enabled = true
addon:Refresh()

print("PASS: unit frames, minimap, minimap buttons (later ones too), group/master toggles, disable")
