-- Run from the repository root: lua src/tests/castbar.lua
local root = "SeamlessCastbar/src/"

-- Locale: the English baseline through the real AceLocale.
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

local spellNames = { [689] = "Drain Life", [5143] = "Arcane Missiles", [10] = "Blizzard" }
local subtexts = { [116] = "Rank 3", [133] = "" }
C_Spell = {
    GetSpellName = function(spellID)
        return spellNames[spellID]
    end,
    GetSpellSubtext = function(spellID)
        return subtexts[spellID]
    end,
}
local channel
UnitChannelInfo = function()
    return channel
end

local function FontString(text)
    local shown = true
    return {
        GetText = function()
            return text
        end,
        SetText = function(_, value)
            text = value
        end,
        SetPoint = function() end,
        Show = function()
            shown = true
        end,
        Hide = function()
            shown = false
        end,
        IsShown = function()
            return shown
        end,
    }
end
local function Texture()
    local texture = FontString()
    texture.points = {}
    texture.SetAtlas = function() end
    texture.SetWidth = function() end
    texture.ClearAllPoints = function(self)
        self.points = {}
    end
    texture.SetPoint = function(self, point, _, _, x)
        self.points[point] = x
    end
    return texture
end
local function Animation(field, value)
    local animation = { [field] = value }
    animation.GetStartDelay = function(self)
        return self.startDelay
    end
    animation.SetStartDelay = function(self, delay)
        self.startDelay = delay
    end
    animation.GetDuration = function(self)
        return self.duration
    end
    animation.SetDuration = function(self, duration)
        self.duration = duration
    end
    return animation
end
local function Bar(name, ownCastTime)
    local value, max = 0, 0
    local bar = {
        unit = name,
        Text = FontString("Frostbolt"),
        Icon = FontString(),
        CastTimeText = ownCastTime and FontString() or nil,
        textures = {},
        GetValue = function()
            return value
        end,
        SetValue = function(_, v)
            value = v
        end,
        GetMinMaxValues = function()
            return 0, max
        end,
        SetMinMaxValues = function(_, _, m)
            max = m
        end,
        GetWidth = function()
            return 100
        end,
        CreateFontString = function(self)
            self.ownText = FontString()
            return self.ownText
        end,
        CreateTexture = function(self)
            local texture = Texture()
            self.textures[#self.textures + 1] = texture
            return texture
        end,
    }
    local fade, hold = Animation("startDelay", 0.2), Animation("duration", 1)
    bar.FadeOutAnim = {
        GetAnimations = function()
            return fade
        end,
    }
    bar.HoldFadeOutAnim = {
        GetAnimations = function()
            return hold
        end,
    }
    return bar, fade, hold
end

local app = {}
local function load(file)
    assert(loadfile(root .. file))("SeamlessCastbar", app)
end
load("text.lua")
load("ticks.lua")
load("hold.lua")
local function barSettings()
    return {
        enabled = true,
        castTime = { enabled = true, format = "ELAPSED_TOTAL", decimals = 1 },
        rank = { enabled = true },
        ticks = { enabled = true },
        icon = { enabled = true },
        hold = { enabled = true, success = 0.5, interrupt = 2 },
    }
end
app.db = { profile = { player = barSettings(), target = barSettings(), focus = barSettings() } }
local keys = {}
app.BarKey = function(bar)
    return keys[bar]
end
app.Settings = function(bar)
    return keys[bar] and app.db.profile[keys[bar]]
end
app.Active = function(bar)
    return keys[bar] ~= nil and app.db.profile[keys[bar]].enabled
end

-- Formats
assert(app.FormatCastTime(1.23, 2.5, "ELAPSED_TOTAL", 1) == "1.2 / 2.5")
assert(app.FormatCastTime(1.23, 2.5, "REMAINING_TOTAL", 1) == "1.3 / 2.5")
assert(app.FormatCastTime(1.23, 2.5, "REMAINING", 2) == "1.27")
assert(app.FormatCastTime(4, 3, "ELAPSED_TOTAL", 0) == "3 / 3", "clamped, no decimals")

-- Target: our own text; a channel's value is the time left.
local target = Bar("target")
keys[target] = "target"
target:SetMinMaxValues(0, 2.5)
target:SetValue(1.23)
target.casting = true
app.UpdateCastTime(target)
assert(target.ownText:GetText() == "1.2 / 2.5")
target.casting, target.channeling = nil, true
target:SetValue(2)
app.UpdateCastTime(target)
assert(target.ownText:GetText() == "0.5 / 2.5", "channel elapsed")
app.db.profile.target.enabled = false
app.UpdateCastTime(target)
assert(not target.ownText:IsShown(), "hidden when the bar is switched off")
app.db.profile.target.enabled = true

-- Player: the game's own text is reformatted, nothing created.
local player = Bar("player", true)
keys[player] = "player"
player:SetMinMaxValues(0, 2)
player:SetValue(0.5)
player.casting = true
app.UpdateCastTime(player)
assert(player.CastTimeText:GetText() == "0.5 / 2.0" and not player.ownText)

-- Rank, idempotent and restored.
player.spellID = 116
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt (Rank 3)")
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt (Rank 3)", "idempotent")
app.db.profile.player.rank.enabled = false
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt", "restored")
app.db.profile.player.rank.enabled = true
player.spellID = 133
app.UpdateName(player)
assert(player.Text:GetText() == "Frostbolt", "no rank")

-- Icon: only on the detached player bar.
player.look = "CLASSIC"
player.Icon:Hide()
app.UpdateIcon(player)
assert(player.Icon:IsShown())
app.db.profile.player.icon.enabled = false
app.UpdateIcon(player)
assert(not player.Icon:IsShown(), "icon restored")
target.look = "UNITFRAME"
target.Icon:Hide()
app.UpdateIcon(target)
assert(not target.Icon:IsShown(), "target icon left alone")

-- Ticks
local times = app.TickTimes(1, 5)
assert(#times == 4 and times[1] == 1 and times[4] == 4)
assert(#app.TickTimes(1, 3) == 2, "Arcane Missiles rank 1")
assert(#app.TickTimes(3, 15) == 4, "Drain Soul")
assert(#app.TickTimes(1, 4.3) == 4, "pushed back")
channel = "Drain Life"
target:SetMinMaxValues(0, 5)
app.UpdateTicks(target)
assert(#target.textures == 4)
assert(math.abs(target.textures[1].points.TOP - 80) < 1e-6, "first tick near the full end")
target.channeling = nil
target.casting = true
app.UpdateTicks(target)
assert(not target.textures[1]:IsShown(), "hidden on casts")
channel = "Mind Control"
target.channeling = true
app.UpdateTicks(target)
assert(not target.textures[1]:IsShown(), "unknown channel")

-- Hold
local focus, fade, hold = Bar("focus")
keys[focus] = "focus"
app.ApplyHold(focus)
assert(fade.startDelay == 0.5 and hold.duration == 2)
app.ApplyHold(focus)
app.db.profile.focus.hold.enabled = false
app.ApplyHold(focus)
assert(fade.startDelay == 0.2 and hold.duration == 1, "hold restored")

print("PASS: cast time formats, rank, icon, channel ticks and hold time")

-- Edit Mode: a Style section in the extended window of the cast bar system, writing the player profile.
local registered, registrations, refreshes, optionRefreshes, enabled = nil, 0, 0, 0, true
local editLib = { SettingType = { Checkbox = 1, Dropdown = 2, Slider = 3, Header = "header" } }
app.core = {
    GetEditModeLibrary = function()
        return editLib
    end,
    RegisterEditModeSystemOptions = function(_, id, spec)
        registered, registrations = spec, registrations + 1
        assert(id == "SeamlessCastbar")
    end,
    RefreshOptions = function()
        optionRefreshes = optionRefreshes + 1
    end,
}
app.addon = {
    Refresh = function()
        refreshes = refreshes + 1
    end,
    IsEnabled = function()
        return enabled
    end,
}
Enum = { EditModeSystem = { CastBar = 11 } }
load("editmode.lua")
app.RegisterEditMode()
app.RegisterEditMode()
assert(registrations == 1 and registered.system == 11, "registered once for the cast bar system")
assert(registered.name == "Style" and registered.enabled())
local rows, keys = {}, {}
for _, row in ipairs(registered.options) do
    rows[row.name] = row
    assert(not keys[row.key], "unique row keys")
    keys[row.key] = true
end
local player = app.db.profile.player
rows["Spell rank"].set(false)
assert(player.rank.enabled == false and refreshes == 1 and optionRefreshes == 1)
assert(rows["Spell rank"].get() == false)
rows["Cast time format"].set("REMAINING")
assert(player.castTime.format == "REMAINING" and #rows["Cast time format"].values == 3)
rows["After a finished cast"].set(0.30000000000000004)
assert(player.hold.success == 0.3 and rows["After a finished cast"].format(0.3) == "0.3")
player.hold.enabled = false
assert(rows["After a finished cast"].disabled(), "hold sliders follow their switch")
rows["Enable"].set(false)
assert(player.enabled == false and rows["Spell rank"].disabled() and not rows["Enable"].disabled)
enabled = false
assert(not registered.enabled(), "the section leaves while the addon is disabled")
print("PASS: player cast bar Style section in Edit Mode")

-- Target and focus previews: movable anchors; real bar coordinates are never read.
local function Frame()
    local frame = { shown = false, level = 1 }
    setmetatable(frame, {
        __index = function()
            return function() end
        end,
    })
    function frame:Show()
        self.shown = true
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:SetShown(value)
        self.shown = value
    end
    function frame:GetFrameLevel()
        return 1
    end
    function frame:GetEffectiveScale()
        return 1
    end
    function frame:GetScale()
        return rawget(self, "scale") or 1
    end
    function frame:SetScale(value)
        self.scale = value
    end
    function frame:SetScript(event, callback)
        self.scripts = rawget(self, "scripts") or {}
        self.scripts[event] = callback
    end
    function frame:HookScript(event, callback)
        self:SetScript(event, callback)
    end
    function frame:SetPoint(...)
        self.point = { ... }
    end
    function frame:CreateTexture()
        return Frame()
    end
    function frame:CreateFontString()
        local text = Frame()
        function text:SetText(value)
            self.text = value
        end
        return text
    end
    function frame:GetParent()
        return self.parent
    end
    return frame
end
function CreateFrame(_, _, parent)
    local frame = Frame()
    frame.parent = parent
    return frame
end
TargetFrame, FocusFrame = Frame(), Frame()
TargetFrame.smallSize, TargetFrame.haveToT, FocusFrame.smallSize, FocusFrame.haveToT = false, false, true, false
UIParent = Frame()
TargetFrameSpellBar, FocusFrameSpellBar = Frame(), Frame()
local hooks = {}
function app.addon:SecureHook(bar, method, callback)
    hooks[bar] = callback
end
for _, bar in ipairs({ TargetFrameSpellBar, FocusFrameSpellBar }) do
    function bar:AdjustPosition()
        self:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", 43, 5)
        hooks[self]()
    end
    function bar:GetPoint()
        error("must not read real castbar coordinates")
    end
    function bar:GetWidth()
        error("must not read real castbar geometry")
    end
end
C_Spell.GetSpellTexture = function()
    return 135846
end
EventRegistry = { TriggerEvent = function() end }
local editMode, added, fixed, frameSettings, libCallbacks, previewOptions = true, {}, {}, {}, {}, nil
local moveCallbacks = {}
function editLib:AddFrame(frame, callback, _, name)
    added[name] = frame
    moveCallbacks[frame] = callback
end
function editLib:AddFrameSettings(frame, settings)
    frameSettings[frame] = settings
end
function editLib:RefreshFrameSettings() end
function editLib:IsInEditMode()
    return editMode
end
function editLib:RegisterCallback(event, callback)
    libCallbacks[event] = callback
end
app.core.SetEditModeFrameFixed = function(_, frame)
    fixed[frame] = true
end
app.core.RegisterEditModeOptions = function(_, _, spec)
    previewOptions = spec.options
end
local combat = false
InCombatLockdown = function()
    return combat
end
app.core.GetEditModePositionSettings = function(_, spec)
    return {
        { kind = "header", name = "Position" },
        {
            name = "X",
            get = function()
                return spec.get("x")
            end,
            set = function(_, value)
                spec.set("x", value)
            end,
        },
    }
end
app.core.GetFramePositionService = function()
    return {
        GetAnchorFrames = function()
            return { { value = "UIParent", text = "UIParent" } }
        end,
    }
end
enabled = true
app.db.profile.player.enabled = true
load("position.lua")
load("preview.lua")
app.RegisterPreviews()
local target, focus = added["Target cast bar"], added["Focus cast bar"]
assert(target and focus and not fixed[target] and not fixed[focus] and #previewOptions == 2)
assert(target:GetParent() == UIParent, "preview stays visible without a target")
libCallbacks.enter()
assert(target.shown and focus.shown and target.point[2] == TargetFrame and target.point[4] == 43)
assert(focus.point[4] == 38 and focus.point[5] == 3, "small focus frame spot")
assert(target.Time.text == "1.2 / 2.5" and target.Text.text == "Target cast bar (Rank 3)")
-- The preview's dialog shows the target bar's Style rows, writing the target profile.
local settings = frameSettings[target]
assert(settings[1].kind == "header" and settings[1].name == "Style")
local byName = {}
for _, setting in ipairs(settings) do
    byName[setting.name] = setting
end
assert(not byName["Spell icon"], "only the player bar has the icon option")
app.db.profile.player.castTime.format = "ELAPSED_TOTAL"
byName["Cast time format"].set("Modern", "REMAINING")
assert(app.db.profile.target.castTime.format == "REMAINING" and app.db.profile.player.castTime.format ~= "REMAINING")
byName["After an interrupt"].set("Modern", 0.30000000000000004)
assert(app.db.profile.target.hold.interrupt == 0.3 and byName["After an interrupt"].formatter(0.3) == "0.3")
assert(byName["Decimals"].formatter(1) == "1" and byName["Cast time"].default == true)
app.UpdatePreviews()
assert(target.Time.text == "1.3", "the preview follows the Style options")
previewOptions[1].set(false)
assert(not target.shown and focus.shown, "the Frames checkbox hides a preview")
editMode = false
libCallbacks.exit()
assert(not focus.shown, "hidden outside Edit Mode")
-- Dragging persists only addon-owned coordinates, including while real geometry is secret.
moveCallbacks[target](target, "Modern", "TOPLEFT", 120, -80)
assert(app.db.profile.target.position.x == 120 and target.point[2] == UIParent)
assert(TargetFrameSpellBar.point[2] == target)
-- Combat callbacks follow exactly the same path; there is no geometry read or deferral.
combat = true
TargetFrameSpellBar:AdjustPosition()
assert(TargetFrameSpellBar.point[2] == target, "client reposition is post-hooked")
TargetFrameSpellBar.scripts.OnShow()
assert(TargetFrameSpellBar.point[2] == target, "show reanchors the real bar")
assert(not target.shown, "hidden artwork still anchors the live bar outside Edit Mode")
combat = false
-- Animation demonstrates ranks and tick settings with localized game spell names.
editMode = true
previewOptions[1].set(true)
app.UpdatePreviews()
target.scripts.OnUpdate(target, 2)
assert(target.Text.text == "Arcane Missiles" and target.Ticks[1].shown)
app.db.profile.target.ticks.enabled = false
app.UpdatePreviews()
assert(not target.Ticks[1].shown)
app.db.profile.target.enabled = false
app.UpdatePreviews()
assert(TargetFrameSpellBar.point[2] == TargetFrame, "disabling restores native placement")
app.db.profile.target.enabled = true
app.UpdatePreviews()
assert(TargetFrameSpellBar.point[2] == target, "reenabling restores saved placement")
local savedProfile = app.db.profile.target
app.db.profile.target = {
    enabled = true,
    castTime = savedProfile.castTime,
    rank = savedProfile.rank,
    ticks = savedProfile.ticks,
    hold = savedProfile.hold,
}
app.UpdatePreviews()
assert(TargetFrameSpellBar.point[2] == TargetFrame, "profile without a position restores native placement")
app.db.profile.target = savedProfile
app.UpdatePreviews()
assert(TargetFrameSpellBar.point[2] == target, "profile switch restores that profile's saved anchor")
moveCallbacks[target](target, "Modern", "CENTER", 0, 0)
assert(
    not app.db.profile.target.position and TargetFrameSpellBar.point[2] == TargetFrame,
    "reset restores client placement"
)
app.db.profile.target.position = { point = "CENTER", x = 50, y = 60 }
app.UpdatePreviews()
enabled = false
app.UpdatePreviews()
assert(not target.shown and TargetFrameSpellBar.point[2] == TargetFrame, "addon disable restores placement")
print("PASS: animated castbar movers, persistence, combat hooks, reset and disable")

-- Both settings panels consume the same standard position declaration as Edit Mode.
enabled = true
app.db.profile.target.position = nil
app.UpdatePreviews()
local modules, config = {}, nil
function app.addon:NewModule(name)
    local module = {}
    modules[name] = module
    return module
end
app.core.FeatureGroup = function(spec)
    return {
        type = "group",
        args = spec.options or {},
        disabled = function()
            return false
        end,
    }
end
app.core.RegisterOptions = function(_, _, spec)
    config = spec
end
assert(loadfile("Seamless/src/config/position.lua"))("Seamless", { addon = app.core })
function UIParent:GetWidth()
    return 1920
end
function UIParent:GetHeight()
    return 1080
end
load("options.lua")
modules.Options:OnInitialize()
local position = config.tabs.target.args.position.args
assert(position.x.get() == 43 and position.relativeTo.get() == "TargetFrame")
position.x.set(nil, 70)
assert(app.db.profile.target.position.x == 70 and target.point[2] == TargetFrame)
assert(byName.X.get() == 70, "Edit Mode reflects config changes")
byName.X.set(nil, 80)
assert(position.x.get() == 80 and target.point[4] == 80, "config reflects Edit Mode changes")
position.scale.set(nil, 1.5)
assert(TargetFrameSpellBar:GetScale() == 1.5 and target:GetScale() == 1.5)
assert(byName.Scale.get() == 1.5 and app.db.profile.focus.scale == nil)
app.UpdatePreviews()
TargetFrameSpellBar.scripts.OnShow()
assert(TargetFrameSpellBar:GetScale() == 1.5, "scale is not multiplied on repeated refresh/show")
byName.Scale.set(nil, 1.75)
assert(position.scale.get() == 1.75 and TargetFrameSpellBar:GetScale() == 1.75)
position.relativeTo.set(nil, "UIParent")
position.relativePoint.set(nil, "BOTTOMRIGHT")
position.point.set(nil, "TOPRIGHT")
assert(target.point[2] == UIParent and target.point[3] == "BOTTOMRIGHT")
combat = true
byName.Scale.set(nil, 2)
byName.X.set(nil, 999)
assert(position.scale.get() == 1.75 and position.x.get() == 80, "no settings edits in combat")
combat = false
position.reset.func()
assert(not app.db.profile.target.position and TargetFrameSpellBar.point[2] == TargetFrame)
assert(position.scale.get() == 1.75, "Reset Position preserves scale")
enabled = false
app.UpdatePreviews()
assert(TargetFrameSpellBar:GetScale() == 1 and target:GetScale() == 1, "disable restores original scale")
enabled = true
app.UpdatePreviews()
assert(TargetFrameSpellBar:GetScale() == 1.75, "reenable reapplies scale without requiring a moved position")
app.db.profile.target.scale = nil
app.UpdatePreviews()
assert(TargetFrameSpellBar:GetScale() == 1, "profile reset restores native scale")
assert(not config.tabs.player.args.position, "player continues using native Edit Mode positioning")
print("PASS: shared position/scale controls, legacy positions, combat guards and scale restoration")

-- Dragging retains the chosen anchor points, with offsets measured in preview coordinates.
local dragSpec = app.CastbarPositionSpec("target")
dragSpec.set("relativeTo", "UIParent")
dragSpec.set("point", "TOPRIGHT")
dragSpec.set("relativePoint", "BOTTOMRIGHT")
function target:GetLeft()
    return 100
end
function target:GetRight()
    return 250
end
function target:GetTop()
    return 210
end
function target:GetBottom()
    return 200
end
function UIParent:GetLeft()
    return 0
end
function UIParent:GetRight()
    return 1920
end
function UIParent:GetTop()
    return 1080
end
function UIParent:GetBottom()
    return 0
end
app.SaveCastbarDrag("target", "CENTER", 7, 8)
local dragged = app.CastbarPosition("target")
assert(dragged.point == "TOPRIGHT" and dragged.relativePoint == "BOTTOMRIGHT")
assert(dragged.x == -1670 and dragged.y == 210 and dragged.relativeTo == "UIParent")
print("PASS: drag preserves configured anchors")
