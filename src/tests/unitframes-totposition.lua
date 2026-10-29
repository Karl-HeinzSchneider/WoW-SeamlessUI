-- Run from the repository root: lua src/tests/unitframes-totposition.lua
-- Target of target / target of focus positions: client anchors untouched until moved, per-layout
-- storage, combat queueing, the focus Larger Frame re-anchor and the Edit Mode stand-ins.

GetLocale = function()
    return "enUS"
end
geterrorhandler = function()
    return function(message)
        error(message)
    end
end
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/AceLocale-3.0/AceLocale-3.0.lua")
dofile("Seamless/locales/enUS.lua")

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for k, v in pairs(value) do
        result[k] = copy(v)
    end
    return result
end
CopyTable = copy

local combat = false
function InCombatLockdown()
    return combat
end
EventRegistry = { TriggerEvent = function() end }
function hooksecurefunc(object, method, hook)
    local original = object[method]
    object[method] = function(...)
        local result = original(...)
        hook(...)
        return result
    end
end

-- A frame with a rectangle (screen units at scale 1) and recorded anchors.
local function Frame(name, rect, scale)
    local frame = { name = name, rect = rect, scale = scale or 1, points = {}, setPoints = 0, shown = false }
    function frame:GetName()
        return self.name
    end
    function frame:IsObjectType(kind)
        return kind == "Frame"
    end
    function frame:ClearAllPoints()
        self.points = {}
    end
    function frame:SetPoint(...)
        self.setPoints = self.setPoints + 1
        self.points[#self.points + 1] = { ... }
    end
    function frame:GetEffectiveScale()
        return self.scale
    end
    function frame:SetScale(value)
        self.scale = value
    end
    for _, side in ipairs({ "Left", "Right", "Top", "Bottom" }) do
        frame["Get" .. side] = function(self)
            return self.rect and self.rect[side:lower()]
        end
    end
    function frame:SetShown(value)
        self.shown = value
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:CreateTexture()
        return Frame(nil)
    end
    frame.CreateMaskTexture, frame.CreateFontString = frame.CreateTexture, frame.CreateTexture
    function frame:SetText(value)
        self.text = value
    end
    function frame:SetMinMaxValues(low, high)
        self.range = { low, high }
    end
    function frame:SetValue(value)
        self.value = value
    end
    function frame:SetStatusBarTexture(value)
        self.atlas = value
    end
    function frame:GetStatusBarTexture()
        return self
    end
    function frame:SetScript(event, handler)
        self[event] = handler
    end
    function frame:IsShown()
        return self.shown
    end
    frame.SetAtlas, frame.SetAllPoints, frame.AddMaskTexture, frame.RegisterUnitEvent =
        function() end, function() end, function() end, function() end
    function frame:SetStatusBarColor(r, g, b)
        self.color = { r, g, b }
    end
    frame.SetSize, frame.SetClampedToScreen = function() end, function() end
    return frame
end

Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
local health, power = 450, 35
function UnitName()
    return "First", "Last"
end
function UnitHealth()
    return health
end
function UnitHealthMax()
    return 1000
end
function UnitPower()
    return power
end
function UnitPowerMax()
    return 100
end
function SetPortraitTexture(texture, unit)
    texture.portraitUnit = unit
end
function CreateFrame()
    return Frame(nil)
end

UIParent = Frame("UIParent", { left = 0, right = 1920, top = 1080, bottom = 0 })
TargetFrame = Frame("TargetFrame", { left = 1000, right = 1200, top = 400, bottom = 320 })
FocusFrame = Frame("FocusFrame", { left = 200, right = 400, top = 700, bottom = 620 })
TargetFrameToT, FocusFrameToT = Frame("TargetFrameToT"), Frame("FocusFrameToT")
Minimap = Frame("Minimap")
function FocusFrame:SetSmallSize(small)
    self.smallSize = small
    -- The client adds its anchor without clearing ours (FocusFrameMixin:SetSmallSize).
    FocusFrameToT:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", small and 20 or 12, small and 8 or 10)
end

-- LibEditMode: the active layout, Edit Mode state, registered stand-ins and callbacks.
local layout, editing = nil, false
local callbacks, registeredFrames = {}, {}
local lib = { SettingType = { Header = "header", Dropdown = "dropdown" } }
function lib:GetActiveLayoutName()
    return layout
end
function lib:IsInEditMode()
    return editing
end
function lib:RegisterCallback(event, callback)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], callback)
end
function lib:AddFrame(frame, callback, default, name)
    registeredFrames[name] = { frame = frame, callback = callback, default = default }
end
function lib:AddFrameSettings(frame, settings)
    for _, entry in pairs(registeredFrames) do
        if entry.frame == frame then
            entry.settings = settings
        end
    end
end
lib.RefreshFrameSettings = function() end
local function fire(event, ...)
    for _, callback in ipairs(callbacks[event] or {}) do
        callback(...)
    end
end

local refreshes, editModeGroups = 0, {}
local events = {}
local modules = {}
local profiles = {
    Default = {
        totPositions = setmetatable({}, {
            __index = function(self, key)
                rawset(self, key, {})
                return self[key]
            end,
        }),
    },
}
local app = {
    db = { profile = profiles.Default, profiles = profiles },
    core = {
        GetEditModeLibrary = function()
            return lib
        end,
        RefreshOptions = function()
            refreshes = refreshes + 1
        end,
        GetFramePositionService = function()
            return {
                IsValidAnchorTarget = function(_, target, frame)
                    return target ~= frame
                end,
                GetAnchorFrames = function(_, frame)
                    return { { value = "UIParent", text = "UIParent" }, { value = frame:GetName(), text = "self" } }
                end,
            }
        end,
        GetPositionOptions = function(_, spec)
            return { type = "group", spec = spec }
        end,
        GetEditModePositionSetting = function(_, spec)
            return { spec = spec }
        end,
        RegisterEditModeOptions = function(_, id, spec)
            editModeGroups[id] = spec
        end,
    },
    addon = {
        NewModule = function(_, name, module)
            function module:RegisterEvent(event, handler)
                events[event] = handler
            end
            modules[name] = module
            return module
        end,
    },
}
local function load(file)
    assert(loadfile("SeamlessUnitframes/src/" .. file))("SeamlessUnitframes", app)
end
load("core/unitframes.lua")
app.StyleOptions = function(entry)
    return {
        {
            type = "select",
            name = "Name display",
            default = function()
                return "full"
            end,
            get = function()
                return "full"
            end,
            set = function() end,
        },
    }
end
local previewCalls = {}
for _, name in ipairs({ "legacyLayout", "healthColor", "nameDisplay", "classIcon" }) do
    app[name] = {
        Refresh = function() end,
        ApplyPreview = function(_, frame, key)
            previewCalls[name] = { frame = frame, key = key }
        end,
        ApplyToTPreview = function(_, frame, powerType)
            frame.previewLayout = app.db.profile.layout
            frame.previewPowerType = powerType
        end,
    }
end
load("totposition/totposition.lua")
app.optionPages = {}
for _, key in ipairs({ "targettarget", "focustarget" }) do
    app.optionPages[key] = { config = { buttonSection = { kind = "buttons", options = {} } } }
end
load("totposition/mover.lua")
local position, mover = app.totPosition, app.totMover

local function last(frame)
    return frame.points[#frame.points]
end

-- Enabled before the layouts load: nothing is touched.
position:OnEnable()
assert(TargetFrameToT.setPoints == 0 and FocusFrameToT.setPoints == 0, "client anchors stay until moved")
layout = "Custom"
fire("layout", "Custom")
assert(TargetFrameToT.setPoints == 0, "a layout without a position keeps the client's anchor")

-- The options show the client's anchor as the default.
local options = position:GetOptions("targettarget").spec
assert(position:GetOptions("pet") == nil and position:GetOptions("target") == nil, "only the ToT frames")
assert(options.default("point") == "TOPRIGHT" and options.default("relativeTo") == "TargetFrame")
assert(options.default("x") == 12 and options.default("y") == 10 and options.isDefault())
assert(options.get("relativePoint") == "BOTTOMRIGHT" and not options.disabled())

-- Changing a field stores the active layout's position and moves the real frame.
local before = refreshes
options.set("x", 50)
local stored = app.db.profile.totPositions.targettarget.Custom
assert(stored and stored.x == 50 and stored.y == 10 and stored.relativeTo == "TargetFrame")
local point = last(TargetFrameToT)
assert(#TargetFrameToT.points == 1 and point[1] == "TOPRIGHT" and point[2] == TargetFrame)
assert(point[3] == "BOTTOMRIGHT" and point[4] == 50 and point[5] == 10)
assert(refreshes > before and not options.isDefault())

-- Missing or cyclic anchor frames fall back to the unit frame.
options.set("relativeTo", "TargetFrameToT")
assert(last(TargetFrameToT)[2] == TargetFrame)
options.set("relativeTo", "Minimap")
assert(last(TargetFrameToT)[2] == Minimap)
options.set("relativeTo", "NoSuchFrame")
assert(last(TargetFrameToT)[2] == TargetFrame)
options.set("relativeTo", "TargetFrame")

-- Nothing moves in combat; a layout switch waits for combat to end.
combat = true
local count = TargetFrameToT.setPoints
options.set("x", 99)
assert(app.db.profile.totPositions.targettarget.Custom.x == 50 and TargetFrameToT.setPoints == count)
app.db.profile.totPositions.targettarget.Other =
    { point = "LEFT", relativeTo = "UIParent", relativePoint = "LEFT", x = 5, y = 6 }
layout = "Other"
fire("layout", "Other")
assert(TargetFrameToT.setPoints == count and position.pending)
combat = false
events.PLAYER_REGEN_ENABLED()
assert(last(TargetFrameToT)[1] == "LEFT" and last(TargetFrameToT)[2] == UIParent and not position.pending)
layout = "Custom"
fire("layout", "Custom")
assert(last(TargetFrameToT)[4] == 50)

-- Reset restores the client's anchor once, then leaves the frame alone again.
options.reset()
assert(app.db.profile.totPositions.targettarget.Custom == nil and options.isDefault())
point = last(TargetFrameToT)
assert(point[1] == "TOPRIGHT" and point[2] == TargetFrame and point[4] == 12 and point[5] == 10)
count = TargetFrameToT.setPoints
fire("layout", "Custom")
assert(TargetFrameToT.setPoints == count, "a reset frame is the client's again")
print("PASS: ToT positions per layout, combat queue and reset")

-- Focus: the default follows Larger Frame, and the client's re-anchor is undone for a moved frame.
FocusFrame.smallSize = true
local focus = position:GetOptions("focustarget").spec
assert(focus.default("x") == 20 and focus.default("y") == 8)
focus.set("point", "TOPLEFT")
FocusFrame:SetSmallSize(false)
assert(#FocusFrameToT.points == 1 and last(FocusFrameToT)[1] == "TOPLEFT", "ours replaces the client's")
assert(last(FocusFrameToT)[4] == 20, "the stored offsets, not the new default")
focus.reset()
assert(last(FocusFrameToT)[4] == 12 and last(FocusFrameToT)[5] == 10, "default of the large frame")
count = FocusFrameToT.setPoints
FocusFrame:SetSmallSize(true)
assert(FocusFrameToT.setPoints == count + 1, "an unmoved frame keeps the client's anchors")
print("PASS: focus ToT follows Larger Frame")

-- Edit Mode stand-ins: one per frame, Frames checkboxes, shown only in Edit Mode.
local targetMover = registeredFrames["Target of Target"]
local focusMover = registeredFrames["Target of Focus"]
assert(targetMover and focusMover and targetMover.settings[1].spec, "registered with LibEditMode and Position rows")
assert(targetMover.settings[2].kind == "header" and targetMover.settings[2].name == "Style")
assert(targetMover.settings[3].kind == "dropdown" and targetMover.settings[3].default == "full")
assert(targetMover.settings[4] == app.optionPages.targettarget.config.buttonSection)
assert(focusMover.settings[4] == app.optionPages.focustarget.config.buttonSection)
local frames = editModeGroups["SeamlessUnitframes.ToT"]
assert(frames.section == "frames" and #frames.options == 2 and frames.options[1].get() == true)
assert(not targetMover.frame.shown)
editing = true
TargetFrameToT.scale = 0.8
fire("enter")
assert(targetMover.frame.shown and targetMover.frame.scale == 0.8, "the real frame's effective scale")
assert(targetMover.frame.name.text == "First Last" and targetMover.frame.portrait.portraitUnit == "player")
assert(targetMover.frame.HealthBar.value == 450 and targetMover.frame.HealthBar.range[2] == 1000)
assert(targetMover.frame.ManaBar.value == 35 and targetMover.frame.ManaBar.range[2] == 100)
for _, name in ipairs({ "healthColor", "nameDisplay", "classIcon" }) do
    local call = previewCalls[name]
    assert(mover.movers[call.key] == call.frame, "preview styling uses the ToT's own settings key")
end
app.db.profile.layout = "legacy"
app.legacyLayout:Refresh()
assert(targetMover.frame.previewLayout == "legacy" and focusMover.frame.previewLayout == "legacy")
app.db.profile.layout = "current"
app.legacyLayout:Refresh()
assert(targetMover.frame.previewLayout == "current")
health, power = 250, 12
targetMover.frame:OnEvent("UNIT_HEALTH", "player")
assert(targetMover.frame.HealthBar.value == 250 and targetMover.frame.ManaBar.value == 12)
local placed = last(targetMover.frame)
assert(placed[1] == "TOPRIGHT" and placed[2] == TargetFrame and placed[4] == 12)
frames.options[1].set(false)
assert(not targetMover.frame.shown)
frames.options[1].set(true)

-- A drag releases the anchor frame: the ToT is stored where LibEditMode placed it on UIParent.
targetMover.callback(targetMover.frame, "Custom", "BOTTOMLEFT", 40, 30)
stored = app.db.profile.totPositions.targettarget.Custom
assert(stored.point == "BOTTOMLEFT" and stored.relativeTo == "UIParent" and stored.relativePoint == "BOTTOMLEFT")
assert(stored.x == 40 and stored.y == 30)
assert(last(TargetFrameToT)[2] == UIParent and last(TargetFrameToT)[4] == 40, "the real frame follows")

-- Reset Position reports LibEditMode's default: back to the client's anchor.
local reset = targetMover.default
targetMover.callback(targetMover.frame, "Custom", reset.point, reset.x, reset.y)
assert(app.db.profile.totPositions.targettarget.Custom == nil)
assert(last(TargetFrameToT)[2] == TargetFrame and last(TargetFrameToT)[4] == 12)
editing = false
fire("exit")
assert(not targetMover.frame.shown)
print("PASS: Edit Mode stand-ins")

-- Only the addon-owned previews use catalogue health/power; they never rebind the real unit.
PowerBarColor = nil -- The preview must reuse colored artwork, never apply an extra power tint.
app.previewCharacters = {
    Get = function()
        return { health = 75, healthMax = 150, power = 20, powerMax = 80, powerType = "MANA" }
    end,
}
editing = true
fire("enter")
assert(targetMover.frame.HealthBar.value == 75 and targetMover.frame.HealthBar.range[2] == 150)
assert(targetMover.frame.ManaBar.value == 20 and targetMover.frame.ManaBar.range[2] == 80)
assert(targetMover.frame.previewPowerType == "MANA")
assert(
    targetMover.frame.ManaBar.color[1] == 1
        and targetMover.frame.ManaBar.color[2] == 1
        and targetMover.frame.ManaBar.color[3] == 1
)
app.previewCharacters = nil
mover:Refresh()
assert(targetMover.frame.HealthBar.value == health and targetMover.frame.ManaBar.value == power)
assert(targetMover.frame.previewPowerType == nil, "live fallback uses the existing unit power selection")
editing = false
fire("exit")
print("PASS: VIP ToT bar values and live fallback")

-- Layout copies, renames and deletes follow the game's layouts.
options.set("x", 70)
fire("create", "Copy", 3, "Custom")
assert(app.db.profile.totPositions.targettarget.Copy.x == 70)
app.db.profile.totPositions.targettarget.Copy.x = 71
assert(app.db.profile.totPositions.targettarget.Custom.x == 70, "a copy, not the same table")
fire("rename", "Copy", "Renamed")
assert(app.db.profile.totPositions.targettarget.Renamed.x == 71 and not app.db.profile.totPositions.targettarget.Copy)
fire("delete", "Renamed")
assert(app.db.profile.totPositions.targettarget.Renamed == nil)

-- Disabling puts the client's anchor back on moved frames.
position:OnDisable()
assert(last(TargetFrameToT)[4] == 12 and last(TargetFrameToT)[2] == TargetFrame)
count = TargetFrameToT.setPoints
position:OnProfileRefresh()
assert(TargetFrameToT.setPoints == count)
print("PASS: layout bookkeeping and disabling")
