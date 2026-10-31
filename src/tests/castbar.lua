-- Run from the repository root: lua src/tests/castbar.lua
local root = "SeamlessCastbar/src/"
unpack = unpack or table.unpack

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
    local texture
    return {
        GetTexture = function()
            return texture
        end,
        SetTexture = function(_, value)
            texture = value
        end,
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
assert(target.ownText:IsShown(), "obsolete per-bar enable values do not disable addon behavior")
app.db.profile.target.castTime.enabled = false
app.UpdateCastTime(target)
assert(not target.ownText:IsShown(), "the cast time feature can still be switched off")
app.db.profile.target.castTime.enabled = true

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
assert(
    player.Icon:GetTexture() == "Interface\\Icons\\INV_Misc_QuestionMark",
    "empty icon has a texture before the first cast"
)
app.db.profile.player.icon.enabled = false
app.UpdateIcon(player)
assert(not player.Icon:IsShown(), "icon restored")
assert(player.Icon:GetTexture() == nil, "disabling removes the fallback texture")
app.db.profile.player.icon.enabled = true
app.UpdateIcon(player)
player.Icon:SetTexture(12345)
app.UpdateIcon(player)
assert(player.Icon:GetTexture() == 12345, "a real cast replaces the fallback and is preserved")
app.RestoreIcon(player)
assert(player.Icon:GetTexture() == 12345, "restoring never clears a real spell texture")
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
local registeredSize
local editLib = { SettingType = { Checkbox = 1, Dropdown = 2, Slider = 3, Header = "header" } }
local sizeEditMode = false
function editLib:IsInEditMode()
    return sizeEditMode
end
app.core = {
    GetCustomEditModeVisibility = dofile("src/tests/settings-support.lua").customVisibility,
    GetEditModeLibrary = function()
        return editLib
    end,
    RegisterEditModeSystemOptions = function(_, id, spec)
        registrations = registrations + 1
        if id == "SeamlessCastbarSize" then
            registeredSize = spec
        else
            assert(id == "SeamlessCastbar")
            registered = spec
        end
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
-- Player dimensions: exact frame sizes, native look changes and profile restoration.
local dimensions = { width = 208, height = 11, scale = 1 }
local iconSize = { width = 20, height = 20 }
PlayerCastingBarFrame = {
    Icon = {
        GetWidth = function()
            return iconSize.width
        end,
        GetHeight = function()
            return iconSize.height
        end,
        SetSize = function(_, width, height)
            iconSize.width, iconSize.height = width, height
        end,
    },
    GetScale = function()
        return dimensions.scale
    end,
    SetScale = function(_, value)
        dimensions.scale = value
    end,
    GetWidth = function()
        return dimensions.width
    end,
    GetHeight = function()
        return dimensions.height
    end,
    SetWidth = function(_, value)
        dimensions.width = value
    end,
    SetHeight = function(_, value)
        dimensions.height = value
    end,
}
local textPoints = { { "TOP", PlayerCastingBarFrame, "TOP", 0, -10 } }
PlayerCastingBarFrame.Text = {
    GetNumPoints = function()
        return #textPoints
    end,
    GetPoint = function(_, index)
        return unpack(textPoints[index])
    end,
    ClearAllPoints = function()
        textPoints = {}
    end,
    SetPoint = function(_, ...)
        textPoints[#textPoints + 1] = { ... }
    end,
}
app.dbDefaults = {}
dofile("src/tests/settings-support.lua").defaults("SeamlessCastbar", app)
load("size.lua")
dimensions.width, dimensions.height = 207.99998474121, 11.00000095367
assert(
    app.PlayerSizeDefault("width") == 208 and app.PlayerSizeDefault("height") == 11,
    "declared size defaults are independent of live frame geometry"
)
dimensions.width, dimensions.height = 208, 11
app.db.profile.player.height = 22
app.ApplyPlayerSize()
assert(iconSize.width == 20 and iconSize.height == 20, "bar height does not resize the icon")
app.db.profile.player.iconSize = 40
app.ApplyPlayerSize()
assert(iconSize.width == 40 and iconSize.height == 40, "manual icon size sets both dimensions")
app.ApplyPlayerSize()
assert(iconSize.width == 40, "repeated refreshes preserve manual icon size")
app.db.profile.player.height = 11
app.ApplyPlayerSize()
assert(iconSize.width == 40 and iconSize.height == 40, "manual icon size is independent of bar height")
app.db.profile.player.width, app.db.profile.player.height = 300, 50
app.db.profile.player.scale = 3
app.ApplyPlayerSize()
assert(
    textPoints[1][1] == "TOP" and textPoints[1][3] == "BOTTOM" and textPoints[1][5] == 1,
    "text keeps its native bottom-relative position as height increases"
)
app.ApplyPlayerSize()
assert(textPoints[1][5] == 1, "repeated refreshes do not shift the text")
assert(dimensions.scale == 3)
dimensions.scale = 1.5
app.PlayerScaleChanged()
assert(dimensions.scale == 3 and app.PlayerSizeDefault("scale") == 1, "native scale updates cannot change the default")
assert(dimensions.width == 300 and dimensions.height == 50)
dimensions.width, dimensions.height = 150, 10
textPoints = {
    { "TOPLEFT", PlayerCastingBarFrame, "TOPLEFT", 0, 3 },
    { "TOPRIGHT", PlayerCastingBarFrame, "TOPRIGHT", 0, 3 },
}
app.PlayerSizeLookChanged()
assert(
    #textPoints == 2
        and textPoints[1][3] == "BOTTOMLEFT"
        and textPoints[2][3] == "BOTTOMRIGHT"
        and textPoints[1][5] == 13
        and textPoints[2][5] == 13,
    "locked bar retains both horizontal anchors"
)
assert(dimensions.width == 300 and dimensions.height == 50, "sizes survive a native look change")
assert(app.PlayerSizeDefault("width") == 208 and app.PlayerSizeDefault("height") == 11)
assert(app.PlayerSizeDefault("iconSize") == 16, "icon defaults come from the client template, not the live icon")
local originalProfile = app.db.profile
app.db.profile = { player = {} }
app.ApplyPlayerSize()
assert(dimensions.width == 150 and dimensions.height == 10, "removing overrides restores native dimensions")
assert(dimensions.scale == 1.5, "removing overrides restores native scale")
assert(iconSize.width == 20 and iconSize.height == 20, "removing overrides restores native icon size")
assert(textPoints[1][3] == "TOPLEFT" and textPoints[1][5] == 3, "removing overrides restores native text anchors")
app.db.profile = originalProfile
app.ApplyPlayerSize()
enabled = false
app.ApplyPlayerSize()
assert(dimensions.width == 150 and dimensions.height == 10, "addon disable restores native dimensions")
assert(dimensions.scale == 1.5, "addon disable restores native scale")
assert(iconSize.width == 20 and iconSize.height == 20, "disabling restores native icon size")
assert(textPoints[2][3] == "TOPRIGHT" and textPoints[2][5] == 3, "disabling restores native text anchors")
enabled = true
app.db.profile.player.width, app.db.profile.player.height = nil, nil
app.db.profile.player.scale = nil
app.db.profile.player.iconSize = nil
Enum = { EditModeSystem = { CastBar = 11 } }
local coreApp = { addon = app.core, config = {} }
assert(loadfile("Seamless/src/config/schema.lua"))("Seamless", coreApp)
assert(loadfile("Seamless/src/config/model.lua"))("Seamless", coreApp)
app.optionPages = {}
app.dbDefaults = {}
app.position = { GetOptions = function() end }
app.core.GetEditModeButtonSection = dofile("src/tests/settings-support.lua").buttonSection
app.core.GetEditModePositionButton = dofile("src/tests/settings-support.lua").positionButton
load("options/shared.lua")
load("options/player.lua")
load("options/target.lua")
load("options/focus.lua")
for _, page in pairs(app.optionPages) do
    app.core:PrepareSettingsOptions(page.config)
end
app.dbDefaults = app.core:GetOptionsDefaults(app.optionPages)
load("editmode.lua")
app.RegisterEditMode()
app.RegisterEditMode()
assert(registrations == 1 and registered.system == 11, "registered once for the cast bar system")
assert(registered.page.addon == "SeamlessCastbar" and registered.page.key == "player" and registered.enabled())
-- Core draws the page: Size rows go to the window's Size section by their plain keys.
dofile("src/tests/settings-support.lua").editModePages(app.core, "SeamlessCastbar", app)
registered.options = {}
for _, section in ipairs(app.core:GetEditModePageSections("SeamlessCastbar", "player")) do
    if section.key == "settings:size" then
        registeredSize = section
    else
        for _, row in ipairs(section.options) do
            registered.options[#registered.options + 1] = row
        end
    end
end
assert(registeredSize.name == "Size" and #registeredSize.options == 5)
local sizeArgs = app.optionPages.player.config.args.size.args
assert(not sizeArgs.resetSize.hidden(), "reset size is visible in standalone options")
sizeEditMode = true
assert(sizeArgs.resetSize.hidden(), "reset size option row is hidden in Edit Mode")
sizeEditMode = false
local resetButton = app.optionPages.player.config.buttonSection.options[3]
assert(resetButton.name == "Reset To Default Size", "Edit Mode footer declares reset size")
for _, reset in ipairs({ sizeArgs.resetSize.func, resetButton.click }) do
    local settings = app.db.profile.player
    settings.width, settings.height, settings.scale, settings.iconSize = 250, 22, 2, 32
    app.ApplyPlayerSize()
    reset()
    app.ApplyPlayerSize()
    assert(settings.width == 208 and settings.height == 11 and settings.scale == 1 and settings.iconSize == 16)
    assert(dimensions.width == 208 and dimensions.height == 11 and dimensions.scale == 1)
    assert(
        iconSize.width == 16 and iconSize.height == 16,
        "both reset buttons apply actual defaults, not captured values"
    )
end
refreshes, optionRefreshes = 0, 0
assert(sizeArgs.width and sizeArgs.height and not app.optionPages.player.config.args.width)
local rows, keys = {}, {}
for _, row in ipairs(registered.options) do
    rows[row.name] = row
    assert(not keys[row.key], "unique row keys")
    keys[row.key] = true
end
assert(not rows.Width and not rows.Height, "dimensions belong to Size, not Style")
for _, row in ipairs(registeredSize.options) do
    rows[row.name] = row
end
local player = app.db.profile.player
assert(rows.Width.min() == 10 and rows.Width.max() == 300 and rows.Width.step() == 1)
assert(rows.Height.min() == 8 and rows.Height.max() == 32 and rows.Height.step() == 1)
assert(rows["Icon size"].min() == 8 and rows["Icon size"].max() == 64 and rows["Icon size"].step() == 1)
sizeEditMode = true
assert(rows["Reset To Default Size"].hidden(), "the footer resets size in Edit Mode")
sizeEditMode = false
rows["Icon size"].set(32)
app.ApplyPlayerSize()
assert(player.iconSize == 32 and iconSize.width == 32 and iconSize.height == 32)
player.iconSize = nil
assert(rows.Scale.key == "scale" and rows.Scale.min() == 0.5 and rows.Scale.max() == 3)
rows.Scale.set(0.5)
app.ApplyPlayerSize()
assert(player.scale == 0.5 and dimensions.scale == 0.5)
rows.Scale.set(3)
app.ApplyPlayerSize()
assert(dimensions.scale == 3)
player.scale = nil
rows.Width.set(10)
rows.Height.set(8)
app.ApplyPlayerSize()
assert(player.width == 10 and player.height == 8 and dimensions.width == 10 and dimensions.height == 8)
player.width, player.height = nil, nil
app.ApplyPlayerSize()
refreshes, optionRefreshes = 0, 0
rows["Spell rank"].set(false)
assert(player.rank.enabled == false and refreshes == 1 and optionRefreshes == 1)
assert(rows["Spell rank"].get() == false)
rows["Cast time format"].set("REMAINING")
assert(player.castTime.format == "REMAINING" and #rows["Cast time format"].values() == 3)
rows["After a finished cast"].set(0.30000000000000004)
assert(player.hold.success == 0.3 and rows["After a finished cast"].format(0.3) == "0.3")
player.hold.enabled = false
assert(rows["After a finished cast"].disabled(), "hold sliders follow their switch")
assert(rows.Enable and rows.Enable.setting.path[2] ~= nil, "feature groups keep their Enable switch, as in settings")
for _, key in ipairs({ "player", "target", "focus" }) do
    assert(not app.optionPages[key].config.args.enabled and app.dbDefaults.profile[key].enabled == nil)
end
enabled = false
assert(not registered.enabled(), "the section leaves while the addon is disabled")
print("PASS: player cast bar Style section in Edit Mode")

-- Target and focus previews: Edit Mode stand-ins that move the real bars, with their Style settings.
local secret = {}
issecretvalue = function(value)
    return value == secret
end
local function Frame(name)
    local frame = { shown = false, level = 1, name = name, scale = 1 }
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
    function frame:GetName()
        return self.name
    end
    function frame:IsObjectType()
        return true
    end
    function frame:GetEffectiveScale()
        return self.scale
    end
    function frame:ClearAllPoints()
        self.point = nil
    end
    function frame:SetPoint(...)
        self.point = { ... }
    end
    function frame:SetScale(value)
        self.ownScale = value
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
function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end
UIParent = Frame("UIParent")
TargetFrame, FocusFrame = Frame("TargetFrame"), Frame("FocusFrame")
TargetFrame.smallSize, TargetFrame.haveToT, FocusFrame.smallSize, FocusFrame.haveToT = false, false, true, false
TargetFrame.scale = 1.5
TargetFrameSpellBar, FocusFrameSpellBar = Frame("TargetFrameSpellBar"), Frame("FocusFrameSpellBar")
for _, bar in ipairs({ TargetFrameSpellBar, FocusFrameSpellBar }) do
    function bar:AdjustPosition()
        self.point = { "TOPLEFT", "client" }
    end
end
-- Anchored to the aura container, the target bar's geometry is secret.
TargetFrameSpellBar.scale = secret
EventRegistry = { TriggerEvent = function() end }
local editMode, layout, added, defaults, moved = true, "Modern", {}, {}, {}
local fixed, frameSettings, libCallbacks, previewOptions, positionSpecs, hooks = {}, {}, {}, nil, {}, {}
function editLib:AddFrame(frame, callback, default, name)
    added[name], moved[frame], defaults[frame] = frame, callback, default
end
function editLib:AddFrameSettings(frame, settings)
    frameSettings[frame] = settings
end
function editLib:RefreshFrameSettings() end
function editLib:IsInEditMode()
    return editMode
end
function editLib:GetActiveLayoutName()
    return layout
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
app.core.GetEditModePositionSetting = function(_, spec)
    positionSpecs[#positionSpecs + 1] = spec
    return { kind = "position", name = "Position", spec = spec }
end
app.core.GetPositionOptions = function(_, spec)
    return { type = "group", name = "Position", spec = spec, args = {}, editModePosition = spec }, {
        type = "group",
        name = "Size",
        args = {},
        editModeSize = true,
    }
end
app.core.GetFramePositionService = function()
    return {
        IsValidAnchorTarget = function(_, target, frame)
            return target ~= frame
        end,
        GetAnchorFrames = function()
            return {}
        end,
    }
end
function app.addon:SecureHook(object, method, handler)
    hooks[object] = hooks[object] or {}
    hooks[object][method] = handler
end
function app.addon:SecureHookScript(object, script, handler)
    hooks[object] = hooks[object] or {}
    hooks[object][script] = handler
end
app.db.profile.positions = { target = {}, focus = {} }
app.db.profiles = { Default = app.db.profile }
enabled = true
load("position.lua")
load("preview.lua")
-- As in the TOC, the target and focus pages load after position.lua and declare its Position groups.
load("options/target.lua")
load("options/focus.lua")
app.core:PrepareSettingsOptions(app.optionPages.target.config)
app.core:PrepareSettingsOptions(app.optionPages.focus.config)
dofile("src/tests/settings-support.lua").editModePages(app.core, "SeamlessCastbar", app)
app.RegisterPreviews()
local target, focus = added["Target cast bar"], added["Focus cast bar"]
assert(target and focus and not fixed[target] and #previewOptions == 2, "movable stand-ins")
assert(target:GetParent() == UIParent, "an addon-owned UIParent child, not a child of the unit frame")
app.position:Enable()
assert(hooks[TargetFrameSpellBar].AdjustPosition and hooks[TargetFrameSpellBar].OnShow, "post-hooks the placement")
libCallbacks.enter()
assert(target.shown and focus.shown and target.point[2] == TargetFrame and target.point[4] == 43)
assert(focus.point[4] == 38 and focus.point[5] == 3, "small focus frame spot")
assert(target.ownScale == 1.5, "the unit frame's scale while the bar's is secret")
assert(target.Time.text == "1.2 / 2.5" and target.Text.text == "Target cast bar")

-- Not moved: the client's placement stays.
TargetFrameSpellBar:AdjustPosition()
hooks[TargetFrameSpellBar].AdjustPosition(TargetFrameSpellBar)
assert(TargetFrameSpellBar.point[2] == "client" and not app.position:IsMoved("target"))

-- A drag releases the anchor frame: the bar is stored where LibEditMode placed it on UIParent.
moved[target](target, layout, "TOPLEFT", 40, -40)
local stored = app.db.profile.positions.target.Modern
assert(
    stored and stored.point == "TOPLEFT" and stored.relativeTo == "UIParent" and stored.relativePoint == "TOPLEFT",
    "a drag leaves the unit frame"
)
assert(stored.x == 40 and stored.y == -40)
assert(TargetFrameSpellBar.point[2] == UIParent and TargetFrameSpellBar.point[4] == 40, "the real bar moves")
-- The client placing the bar again (new target, cast start) puts it back at the stored position.
TargetFrameSpellBar:AdjustPosition()
hooks[TargetFrameSpellBar].OnShow(TargetFrameSpellBar)
assert(TargetFrameSpellBar.point[2] == UIParent and TargetFrameSpellBar.point[5] == -40)
assert(rawget(FocusFrameSpellBar, "point") == nil, "the focus bar is left alone")

-- Positions belong to the layout and follow copies, renames and deletes.
libCallbacks.create("Copy", nil, "Modern")
libCallbacks.rename("Copy", "Renamed")
assert(app.db.profile.positions.target.Renamed.x == 40 and not app.db.profile.positions.target.Copy)
libCallbacks.delete("Renamed")
assert(not app.db.profile.positions.target.Renamed)
layout = "Classic"
libCallbacks.layout()
assert(not app.position:IsMoved("target") and app.position:Get("target").x == 43)
layout = "Modern"

-- The Position rows and options tab write the same layout position.
local positionSpec = frameSettings[target][1].spec
for _, field in ipairs({ "point", "relativeTo", "relativePoint", "x", "y" }) do
    assert(positionSpec.default(field) == nil, "a preview estimate is not an authoritative native default")
    assert(app.position:GetOptions("target").spec.default(field) == nil)
end
positionSpec.set("y", -60)
assert(stored ~= app.db.profile.positions.target.Modern and app.db.profile.positions.target.Modern.y == -60)
assert(app.position:GetOptions("target").spec.get("y") == -60)
assert(app.position:GetOptions("player") == nil, "the player bar is the client's Edit Mode system")

-- Scale is a disabled placeholder: nothing binds it and the bars are never scaled.
assert(positionSpec.scale == nil and app.position.SetScale == nil)
rawset(TargetFrameSpellBar, "ownScale", nil)
hooks[TargetFrameSpellBar].OnShow(TargetFrameSpellBar)
assert(rawget(TargetFrameSpellBar, "ownScale") == nil, "the client's scale is left alone")
app.UpdatePreviews()
assert(target.ownScale == 1.5, "the preview shows the unit frame's scale")
assert(app.db.profile.positions.target.Modern.y == -60)

-- Reset Position: back to the client's anchor from the next placement on.
moved[target](target, layout, defaults[target].point, defaults[target].x, defaults[target].y)
assert(not app.position:IsMoved("target"))
TargetFrameSpellBar:AdjustPosition()
hooks[TargetFrameSpellBar].AdjustPosition(TargetFrameSpellBar)
assert(TargetFrameSpellBar.point[2] == "client")

-- The preview's dialog shows the target page: Position, then its groups and rows, writing the
-- target profile.
local settings = frameSettings[target]
assert(settings[1].name == "Position" and settings[2].kind == "seamless-header")
local byName, byPath = {}, {}
for _, setting in ipairs(settings) do
    if setting.kind == "seamless-option" then
        byName[setting.row.setting:Read("name")] = setting.row
        byPath[table.concat(setting.row.setting.path, ".")] = setting.row
    elseif setting.name then
        byName[setting.name] = setting
    end
end
assert(not byName["Spell icon"], "only the player bar has the icon option")
assert(not byName.Width and not byName.Height, "dimension sliders are player-only")
app.db.profile.player.castTime.format = "ELAPSED_TOTAL"
byName["Cast time format"].set("REMAINING")
assert(app.db.profile.target.castTime.format == "REMAINING" and app.db.profile.player.castTime.format ~= "REMAINING")
byName["After an interrupt"].set(0.30000000000000004)
assert(app.db.profile.target.hold.interrupt == 0.3 and byName["After an interrupt"].format(0.3) == "0.3")
assert(byName["Decimals"].format(1) == "1" and byPath["target.castTime.enabled"].default() == true)
app.UpdatePreviews()
assert(target.Time.text == "1.3", "the preview follows the Style options")
previewOptions[1].set(false)
assert(not target.shown and focus.shown, "the Frames checkbox hides a preview")
editMode = false
libCallbacks.exit()
assert(not focus.shown, "hidden outside Edit Mode")

-- Disabled: moved bars are no longer re-anchored.
moved[target](target, layout, "TOPLEFT", 1, 2)
app.position:Disable()
TargetFrameSpellBar:AdjustPosition()
hooks[TargetFrameSpellBar].AdjustPosition(TargetFrameSpellBar)
assert(TargetFrameSpellBar.point[2] == "client", "disabled leaves the client's placement")
print("PASS: target and focus previews in Edit Mode move the real bars")
