-- Run from the repository root: lua src/tests/darkmode.lua
unpack = unpack or table.unpack
local root = "SeamlessDarkmode/src/"
local app = {}
local enabled = true
local addon = {}
local hooks = {}
function securecallfunction(fn, ...)
    return fn(...)
end
local function constant(...)
    local values = { ... }
    return function()
        return unpack(values)
    end
end
GetRealmName = constant("Realm")
UnitName = constant("Player")
UnitClass = constant("Mage", "MAGE")
UnitRace = constant("Human", "Human")
UnitFactionGroup = constant("Alliance")
GetLocale = constant("enUS")
GetCurrentRegion = constant(3)
CreateFrame = constant({ RegisterEvent = function() end, SetScript = function() end })
geterrorhandler = constant(error)
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("Seamless/lib/AceDB-3.0/AceDB-3.0.lua")
local AceDB = LibStub("AceDB-3.0")

function addon:RegisterEvent() end
function addon:UnregisterAllEvents() end
function addon:IsHooked(object, method)
    method = method or object
    return hooks[object] and hooks[object][method]
end
function addon:SecureHook(object, method, callback)
    if type(object) == "string" then
        callback, method = method, object
    end
    hooks[object] = hooks[object] or {}
    hooks[object][method] = function()
        self[callback](self)
    end
end
function addon:UnhookAll()
    hooks = {}
end
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
LibStub.libs["LibDBIcon-1.0"] = icons
LibStub.libs["AceAddon-3.0"] = { GetAddon = constant({}), NewAddon = constant(addon) }
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
local resting = false
IsResting = function()
    return resting
end
local statusTexture = texture()
PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture = statusTexture
function PlayerFrame_UpdateStatus()
    if PlayerFrame.inCombat then
        statusTexture:SetVertexColor(1, 0, 0, 1)
    elseif resting then
        statusTexture:SetVertexColor(1, 0.88, 0.25, 1)
    end
end
local function updatePlayerStatus()
    PlayerFrame_UpdateStatus()
    hooks.PlayerFrame_UpdateStatus.PlayerFrame_UpdateStatus()
end
local targetFrame = texture()
local targetCircle = texture()
TargetFrame = {
    TargetFrameContainer = { FrameTexture = targetFrame },
    TargetFrameContent = { TargetFrameContentMain = { LevelBackgroundCircle = targetCircle } },
}
local totPreview = texture()
SeamlessUnitframesTargetFrameToTPreview = { FrameTexture = totPreview }
local focusTotPreview = texture()
SeamlessUnitframesFocusFrameToTPreview = { FrameTexture = focusTotPreview }
MinimapCompassTexture = texture()
MinimapCluster = { ZoneTextButton = {} }
AddonCompartmentFrame = { StateTexture = texture(0.7), AddTexture = texture(), Text = texture() }
local function checkControls(color, context)
    equal(AddonCompartmentFrame.StateTexture.color, { color, color, color, 0.7 }, context)
    equal(AddonCompartmentFrame.AddTexture.color, { 1, 1, 1, 1 }, "interaction highlight untouched")
    equal(AddonCompartmentFrame.Text.color, { 1, 1, 1, 1 }, "button text untouched")
end
local ring = texture()
local iconTexture = texture()
buttons.Seamless = { border = ring, icon = iconTexture }

local slot = texture(0.6)
local slotArt = texture()
local actionIcon = texture()
local flash = texture()
local leftGryphon = texture()
local rightGryphon = texture()
MainActionBar = {
    actionButtons = { { NormalTexture = slot, SlotArt = slotArt, icon = actionIcon, Flash = flash } },
    EndCaps = { LeftEndCap = { Texture = leftGryphon }, RightEndCap = { Texture = rightGryphon } },
}
local extraSlot = texture()
MultiBar7 = { actionButtons = { { NormalTexture = extraSlot } } }
StatusTrackingBarInfo = { BarsEnum = { Experience = 1, Reputation = 2, Honor = 3 } }
MainStatusTrackingBarContainer = { shownBarIndex = 1, BarFrameTexture = texture(0.8) }
SecondaryStatusTrackingBarContainer = { shownBarIndex = 2, BarFrameTexture = texture() }

dofile("Seamless/lib/AceLocale-3.0/AceLocale-3.0.lua")
dofile("Seamless/locales/enUS.lua")
assert(loadfile(root .. "frames.lua"))("SeamlessDarkmode", app)
assert(loadfile(root .. "core.lua"))("SeamlessDarkmode", app)
assert(loadfile(root .. "db.lua"))("SeamlessDarkmode", app)
assert(loadfile(root .. "options/general.lua"))("SeamlessDarkmode", app)
local page = app.optionPages.general
local saved = { profiles = { Default = { color = { r = 0.2, g = 0.3, b = 0.4 } } } }
app.db = AceDB:New(saved, page.defaults, true)

addon:OnEnable()
resting = true
updatePlayerStatus()
equal(statusTexture.color, { 0.2, 0.3, 0.4, 1 }, "resting overlay follows player tint")
PlayerFrame.inCombat = true
updatePlayerStatus()
equal(statusTexture.color, { 1, 0, 0, 1 }, "combat indicator keeps native red")
PlayerFrame.inCombat = false
updatePlayerStatus()
app.db.profile.groups.player = false
addon:Refresh()
equal(statusTexture.color, { 1, 0.88, 0.25, 1 }, "player toggle restores native resting gold")
app.db.profile.groups.player = true
app.db.profile.colors.unitframes.enabled = true
app.db.profile.colors.unitframes.color = { r = 0.5, g = 0.4, b = 0.3 }
addon:Refresh()
equal(statusTexture.color, { 0.5, 0.4, 0.3, 1 }, "resting overlay uses category override")
app.db.profile.colors.unitframes.enabled = false
app.db.profile.groups.player = nil
addon:Refresh()
equal(slot.color, { 0.2, 0.3, 0.4, 0.6 }, "action slot tinted with alpha preserved")
equal(slotArt.color, { 1, 1, 1, 1 }, "slot backing untouched")
equal(extraSlot.color, { 0.2, 0.3, 0.4, 1 }, "additional action bar tinted")
equal(actionIcon.color, { 1, 1, 1, 1 }, "action icon untouched")
equal(flash.color, { 1, 1, 1, 1 }, "action flash untouched")
equal(leftGryphon.color, { 0.2, 0.3, 0.4, 1 }, "left gryphon tinted")
equal(rightGryphon.color, { 0.2, 0.3, 0.4, 1 }, "right gryphon tinted")
equal(MainStatusTrackingBarContainer.BarFrameTexture.color, { 0.2, 0.3, 0.4, 0.8 }, "XP border tinted")
equal(SecondaryStatusTrackingBarContainer.BarFrameTexture.color, { 0.2, 0.3, 0.4, 1 }, "reputation border tinted")
app.db.profile.groups.experience = false
app.db.profile.groups.actionbars = false
addon:Refresh()
equal(slot.color, { 1, 1, 1, 0.6 }, "slot option restores border")
equal(leftGryphon.color, { 0.2, 0.3, 0.4, 1 }, "gryphon option independent of slots")
equal(MainStatusTrackingBarContainer.BarFrameTexture.color, { 1, 1, 1, 0.8 }, "XP option restores border")
equal(
    SecondaryStatusTrackingBarContainer.BarFrameTexture.color,
    { 0.2, 0.3, 0.4, 1 },
    "reputation option independent of XP"
)
MainStatusTrackingBarContainer.shownBarIndex = 2
hooks[MainStatusTrackingBarContainer].ApplyPendingBarToShow()
equal(
    MainStatusTrackingBarContainer.BarFrameTexture.color,
    { 0.2, 0.3, 0.4, 0.8 },
    "shared container switches to reputation"
)
SecondaryStatusTrackingBarContainer.shownBarIndex = 3
hooks[SecondaryStatusTrackingBarContainer].ApplyPendingBarToShow()
equal(SecondaryStatusTrackingBarContainer.BarFrameTexture.color, { 1, 1, 1, 1 }, "unrelated bar restores shared border")
app.db.profile.groups.endcaps = false
app.db.profile.groups.reputation = false
addon:Refresh()
equal(rightGryphon.color, { 1, 1, 1, 1 }, "gryphon option restores")
equal(MainStatusTrackingBarContainer.BarFrameTexture.color, { 1, 1, 1, 0.8 }, "reputation option restores")
for _, key in ipairs({ "experience", "reputation", "actionbars", "endcaps" }) do
    app.db.profile.groups[key] = true
end
addon:Refresh()
equal(frame.color, { 0.2, 0.3, 0.4, 0.5 }, "frame tinted, alpha kept")
equal(circle.color, { 0.2, 0.3, 0.4, 1 }, "player level circle tinted")
equal(portrait.color, { 1, 1, 1, 1 }, "portrait untouched")
equal(targetFrame.color, { 0.2, 0.3, 0.4, 1 }, "target frame tinted")
equal(targetCircle.color, { 0.2, 0.3, 0.4, 1 }, "target level circle tinted")
equal(totPreview.color, { 0.2, 0.3, 0.4, 1 }, "ToT Edit Mode preview tinted")
equal(focusTotPreview.color, { 0.2, 0.3, 0.4, 1 }, "focus ToT Edit Mode preview tinted")
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
equal(totPreview.color, { 1, 1, 1, 1 }, "unit frames off restores the ToT preview")
equal(focusTotPreview.color, { 1, 1, 1, 1 }, "unit frames off restores the focus ToT preview")
equal(ring.color, { 0.1, 0.1, 0.1, 1 }, "other groups stay tinted")
app.db.profile.groups.unitframes = true

local minimap = page.config.args.minimap.args
assert(not minimap.customColor.get() and minimap.color.disabled(), "overrides start off with the picker disabled")
assert(not minimap.color.hidden, "the picker stays visible when the override is off")
minimap.customColor.set(nil, true)
assert(not minimap.color.disabled(), "enabling an override activates the picker")
equal({ minimap.color.get() }, { 0.1, 0.1, 0.1 }, "first override starts from the current shared color")
minimap.color.set(nil, 0.6, 0.3, 0.9)
equal(MinimapCompassTexture.color, { 0.6, 0.3, 0.9, 1 }, "override tints the minimap")
equal(ring.color, { 0.6, 0.3, 0.9, 1 }, "override is shared by minimap parts")
equal(frame.color, { 0.1, 0.1, 0.1, 0.5 }, "unit frames still follow the shared color")
minimap.minimapButtons.set(nil, false)
equal(ring.color, { 1, 1, 1, 1 }, "disabling a part restores its original color")
equal(MinimapCompassTexture.color, { 0.6, 0.3, 0.9, 1 }, "sibling parts stay tinted")
minimap.minimapButtons.set(nil, true)
minimap.customColor.set(nil, false)
assert(minimap.color.disabled(), "turning the override off disables the picker again")
equal(ring.color, { 0.1, 0.1, 0.1, 1 }, "disabling the override restores the shared color")
minimap.customColor.set(nil, true)
equal(ring.color, { 0.6, 0.3, 0.9, 1 }, "re-enabling the override recalls the picked color")
page.config.args.color.set(nil, 0.4, 0.4, 0.4)
equal(frame.color, { 0.4, 0.4, 0.4, 0.5 }, "global color changes still reach other categories")
equal(ring.color, { 0.6, 0.3, 0.9, 1 }, "global color changes leave the override in place")

saved.profiles.Legacy = { groups = { minimap = false, unitframes = false } }
app.db:SetProfile("Legacy")
addon:Refresh()
assert(not minimap.minimapButtons.get() and not minimap.minimapBorder.get(), "old disabled group applies to its parts")
equal(ring.color, { 1, 1, 1, 1 }, "legacy profile disables tint")
minimap.minimapButtons.set(nil, true)
equal(ring.color, { 0.22, 0.22, 0.22, 1 }, "a part can opt in when its old group was disabled")
equal(MinimapCompassTexture.color, { 1, 1, 1, 1 }, "untouched parts still follow the legacy group")
app.db:SetProfile("Default")
addon:Refresh()
equal(ring.color, { 0.6, 0.3, 0.9, 1 }, "overrides survive switching profiles")

local status = page.config.args.statusbars.args
status.customColor.set(nil, true)
status.color.set(nil, 0.8, 0.3, 0.2)
MainStatusTrackingBarContainer.shownBarIndex = 1
hooks[MainStatusTrackingBarContainer].ApplyPendingBarToShow()
equal(MainStatusTrackingBarContainer.BarFrameTexture.color, { 0.8, 0.3, 0.2, 0.8 }, "XP uses status color")
MainStatusTrackingBarContainer.shownBarIndex = 2
hooks[MainStatusTrackingBarContainer].ApplyPendingBarToShow()
equal(MainStatusTrackingBarContainer.BarFrameTexture.color, { 0.8, 0.3, 0.2, 0.8 }, "reputation shares status color")

app.db.profile.enabled = false
addon:Refresh()
assert(minimap.customColor.get() and minimap.color.disabled(), "master switch disables an active override picker")
equal(slot.color, { 1, 1, 1, 0.6 }, "master switch restores slots")
equal(rightGryphon.color, { 1, 1, 1, 1 }, "master switch restores gryphons")
equal(MainStatusTrackingBarContainer.BarFrameTexture.color, { 1, 1, 1, 0.8 }, "master switch restores reputation")
equal(frame.color, { 1, 1, 1, 0.5 }, "master switch restores")
equal(statusTexture.color, { 1, 0.88, 0.25, 1 }, "master switch restores resting overlay")
equal(MinimapCompassTexture.color, { 1, 1, 1, 1 }, "master switch restores minimap")
equal(targetCircle.color, { 1, 1, 1, 1 }, "master switch restores target")
checkControls(1, "master switch restores controls")

app.db.profile.enabled = true
addon:Refresh()
addon:OnDisable()
equal(statusTexture.color, { 1, 0.88, 0.25, 1 }, "disable restores resting overlay")
equal(slot.color, { 1, 1, 1, 0.6 }, "disable restores slots")
equal(leftGryphon.color, { 1, 1, 1, 1 }, "disable restores gryphons")
equal(MainStatusTrackingBarContainer.BarFrameTexture.color, { 1, 1, 1, 0.8 }, "disable restores status border")
assert(not next(hooks), "disable removes status hooks")
enabled = false
addon:Refresh()
equal(frame.color, { 1, 1, 1, 0.5 }, "addon disable restores")
equal(circle.color, { 1, 1, 1, 1 }, "addon disable restores level circle")
equal(lateRing.color, { 1, 1, 1, 1 }, "addon disable restores minimap buttons")
assert(not iconCallbacks.LibDBIcon_IconCreated, "addon disable drops the button callback")
checkControls(1, "addon disable restores controls")

MinimapCluster = { ZoneTextButton = {} }
AddonCompartmentFrame = nil
MainActionBar = nil
MultiBar7 = nil
MainStatusTrackingBarContainer = nil
SecondaryStatusTrackingBarContainer = nil
enabled = true
addon:Refresh()

print(
    "PASS: frame tints, status bar swaps, part/master toggles, category color overrides, legacy and switched profiles"
)
