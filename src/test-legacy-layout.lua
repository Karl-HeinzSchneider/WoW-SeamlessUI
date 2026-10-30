-- Offline contracts. Live rendering getters deliberately fail, even out of combat.
unpack = unpack or table.unpack
local pending, combat, geometryWrites, artworkWrites, hookCount = {}, false, 0, 0, 0
local anchorWrites = 0
local editModeActive, libraryEditing = false, false
local editModeCallbacks = {}
EditModeManagerFrame = {
    IsEditModeActive = function()
        return editModeActive
    end,
}
local editModeLibrary = {
    IsInEditMode = function()
        return libraryEditing
    end,
    RegisterCallback = function(_, event, callback)
        editModeCallbacks[event] = callback
    end,
}
local secret = setmetatable({}, {
    __index = function()
        error("indexed a secret")
    end,
    __concat = function()
        error("concatenated a secret")
    end,
    __lt = function()
        error("compared a secret")
    end,
})
function canaccessvalue(value)
    return not rawequal(value, secret)
end
local methods = {}
local callbacks = {}
local function Object()
    return setmetatable({ shown = true }, { __index = methods })
end
Enum = { StatusBarFillStyle = { Reverse = 1 } }
local createdFrames = {}
function CreateFrame(kind, _, parent)
    local frame = Object()
    frame.kind, frame.parent = kind, parent
    if kind == "StatusBar" then
        frame.fill = Object()
    end
    createdFrames[#createdFrames + 1] = frame
    return frame
end
function methods:SetStatusBar(bar)
    self.statusBar = bar
end
function methods:SetAllPoints(relative)
    self.allPoints = relative
end
function methods:RemoveMaskTexture(mask)
    if self.mask == mask then
        self.mask = nil
    end
end
function methods:CreateMaskTexture()
    return Object()
end
function methods:AddMaskTexture(mask)
    self.mask = mask
end
function methods:SetParent(parent)
    assert(not combat, "reparenting during combat")
    self.parent = parent
end
function methods:SetBlendMode(mode)
    self.blend = mode
end
function methods:SetAlphaFromBoolean(value, ifTrue, ifFalse)
    self.alphaFrom = { value, ifTrue, ifFalse }
end
function methods:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
end
function methods:SetScript(name, script)
    self.scripts = self.scripts or {}
    self.scripts[name] = script
end
local predictionUnits = {}
function CreateUnitHealPredictionCalculator()
    return {
        GetMaximumHealth = function()
            return secret
        end,
        GetIncomingHeals = function()
            return secret, secret, secret, secret
        end,
        GetDamageAbsorbs = function()
            return secret, secret
        end,
        GetHealAbsorbs = function()
            return secret, secret
        end,
    }
end
function UnitGetDetailedHealPrediction(unit)
    predictionUnits[#predictionUnits + 1] = unit
end
function methods:SetFillStyle(style)
    self.fillStyle = style
end
function methods:SetAlpha(alpha)
    self.alpha = alpha
end
function methods:SetMinMaxValues(...)
    self.range = { ... }
end
function methods:SetValue(...)
    self.values = { ... }
end
function UnitHealth()
    return secret
end
function UnitHealthMax()
    return secret
end
local function Geometry(region)
    assert(not combat or not region.protected, "protected geometry mutation during combat")
    geometryWrites = geometryWrites + 1
end
function methods:IsProtected()
    return self.protected or false
end
function methods:IsForbidden()
    return false
end
function methods:SetWidth(v)
    Geometry(self)
    assert(canaccessvalue(v))
    self.width = v
end
function methods:SetHeight(v)
    Geometry(self)
    assert(canaccessvalue(v))
    self.height = v
end
function methods:SetPoint(...)
    Geometry(self)
    anchorWrites = anchorWrites + 1
    self.point = { ... }
end
function methods:ClearAllPoints()
    Geometry(self)
    anchorWrites = anchorWrites + 1
    self.point = nil
end
function methods:SetJustifyH(v)
    Geometry(self)
    self.justify = v
end
function methods:SetDrawLayer(...)
    Geometry(self)
    self.layer = { ... }
end
function methods:SetScale(v)
    Geometry(self)
    self.scale = v
end
function methods:SetShown(v)
    Geometry(self)
    self.shown = v
end
function methods:Show()
    self:SetShown(true)
end
function methods:Hide()
    self:SetShown(false)
end
function methods:IsShown()
    return self.shown
end
function methods:CreateTexture()
    return Object()
end
function methods:SetTexture(v)
    artworkWrites = artworkWrites + 1
    assert(canaccessvalue(v))
    self.file = v
    self.atlas = nil
end
function methods:SetTexCoord(...)
    artworkWrites = artworkWrites + 1
    self.coords = { ... }
end
function methods:SetAtlas(v, size, _, reset)
    artworkWrites = artworkWrites + 1
    assert(canaccessvalue(v))
    self.atlas, self.file, self.useSize = v, nil, size
    if reset then
        self.coords = nil
    end
end
function methods:GetStatusBarTexture()
    return self.fill
end
function methods:SetStatusBarTexture(v)
    artworkWrites = artworkWrites + 1
    assert(type(v) == "string")
    assert(v ~= "UI-HUD-UnitFrame-Party-PortraitOn-Bar-TempHPLoss", "party uses the player loss atlas")
    self.fill.file, self.fill.atlas = v, nil
    if not v:find("assets/legacy/", 1, true) then
        self.fill.atlas = v
    end
    self.fill.coords = nil -- Native engine owns these; redraws need no Lua math.
end
function methods:SetStatusBarColor(r, g, b)
    assert(canaccessvalue(r))
    self.color = { r, g, b }
end
local function ForbiddenGetter()
    error("runtime rendering discovery is forbidden")
end
for _, method in ipairs({
    "GetAtlas",
    "GetSize",
    "GetMinMaxValues",
    "GetValue",
    "GetWidth",
    "GetHeight",
    "GetPoint",
    "GetNumPoints",
    "GetTexCoord",
    "GetFrameLevel",
    "GetDrawLayer",
    "GetJustifyH",
    "GetChildren",
    "GetRegions",
    "GetParent",
    "HookScript",
}) do
    methods[method] = ForbiddenGetter
end
local function Path(root, path, bar)
    local at = root
    for key in path:gmatch("[^.]+") do
        if not rawget(at, key) then
            at[key] = Object()
        end
        at = at[key]
    end
    if bar then
        at.fill = Object()
        at.unit = root.unit
        at.unitFrame = root
    end
    return at
end
function InCombatLockdown()
    return combat
end
C_Timer = {
    After = function(_, fn)
        pending[#pending + 1] = fn
    end,
}
function hooksecurefunc(object, method, callback)
    if type(object) == "string" then
        callback, method, object = method, object, _G
    end
    callbacks[object] = callbacks[object] or {}
    callbacks[object][method] = callback
    local original = object[method]
    assert(type(original) == "function")
    hookCount = hookCount + 1
    object[method] = function(...)
        original(...)
        callback(...)
    end
end
local function Drain()
    local count = 0
    while #pending > 0 do
        count = count + 1
        assert(count < 20, "refresh loop")
        table.remove(pending, 1)()
    end
end
local classToken = "MAGE"
local classification, powerToken, alternate, isPlayer, connected, tapped = "normal", "MANA", nil, true, true, false
function UnitClassification()
    return classification
end
function UnitIsBossMob()
    return false
end
function UnitPowerType()
    return 0, powerToken
end
function PlayerFrame_GetAlternatePowerBar()
    return alternate
end
function UnitIsPlayer()
    return isPlayer
end
function UnitClass()
    return "Mage", classToken
end
function UnitExists()
    return true
end
function UnitIsConnected()
    return connected
end
function UnitPlayerControlled()
    return isPlayer
end
function UnitIsTapDenied()
    return tapped
end
function UnitSelectionColor()
    return 1, 0.25, 0.1
end
function CreateColor(r, g, b)
    return {
        SetRGB = function(self, a, c, d)
            self.r, self.g, self.b = a, c, d
        end,
        GetRGB = function(self)
            return self.r or r, self.g or g, self.b or b
        end,
    }
end
RAID_CLASS_COLORS = { MAGE = CreateColor(0.2, 0.6, 1) }
function UnitFrameHealthBar_Update() end
function UnitFrameManaBar_UpdateType() end
function UnitFrame_Initialize() end
PlayerFrame = Object()
PlayerFrame.unit = "player"
local mainPath = "PlayerFrameContent.PlayerFrameContentMain."
local health = Path(PlayerFrame, mainPath .. "HealthBarsContainer.HealthBar", true)
local predictionKeys = { "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }
for _, key in ipairs(predictionKeys) do
    Path(health, key .. ".Fill")
end
Path(PlayerFrame, mainPath .. "HealthBarsContainer.HealthBarMask")
Path(PlayerFrame, mainPath .. "HealthBarsContainer.PlayerFrameTempMaxHealthLoss", true)
local loss = Path(PlayerFrame, mainPath .. "HealthBarsContainer.PlayerFrameHealthBarAnimatedLoss", true)
local mana = Path(PlayerFrame, mainPath .. "ManaBarArea.ManaBar", true)
Path(PlayerFrame, mainPath .. "ManaBarArea.ManaBar.ManaBarMask")
Path(PlayerFrame, mainPath .. "ManaBarArea.ManaBar.LeftText")
Path(PlayerFrame, mainPath .. "ManaBarArea.ManaBar.ManaBarText")
Path(PlayerFrame, mainPath .. "HealthBarsContainer.LeftText")
for _, key in ipairs({ "StatusTexture", "PvpBackgroundIcon" }) do
    Path(PlayerFrame, mainPath .. key)
end
Path(PlayerFrame, "PlayerFrameContent.PlayerFrameContentContextual.AttackIcon")
for _, key in ipairs({
    "FrameTexture",
    "VehicleFrameTexture",
    "AlternatePowerFrameTexture",
    "FrameFlash",
    "PlayerPortraitMask",
    "PlayerPortrait",
}) do
    Path(PlayerFrame, "PlayerFrameContainer." .. key)
end
PlayerName, PlayerPVPTimerText = Object(), Object()
PlayerFrame.healthbar = health
local function Target(unit)
    local frame = Object()
    frame.unit = unit
    frame.protected = true
    for _, key in ipairs({ "FrameTexture", "Flash", "BossPortraitFrameTexture", "Portrait" }) do
        Path(frame, "TargetFrameContainer." .. key)
    end
    local prefix = "TargetFrameContent.TargetFrameContentMain."
    frame.healthbar = Path(frame, prefix .. "HealthBarsContainer.HealthBar", true)
    for _, key in ipairs({ "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }) do
        Path(frame, prefix .. "HealthBarsContainer.HealthBar." .. key .. ".Fill")
        Path(frame, prefix .. "HealthBarsContainer.HealthBar." .. key .. ".FillMask")
    end
    Path(frame, prefix .. "HealthBarsContainer.HealthBar.TotalAbsorbBar.TiledFillOverlay")
    Path(frame, prefix .. "HealthBarsContainer.HealthBar.OverAbsorbGlow")
    Path(frame, prefix .. "HealthBarsContainer.HealthBar.OverHealAbsorbGlow")
    frame.healthbar.protected = true
    frame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.protected = true
    for _, key in ipairs({ "HealthBarText", "LeftText", "RightText", "DeadText", "UnconsciousText" }) do
        Path(frame, prefix .. "HealthBarsContainer." .. key)
    end
    Path(frame, prefix .. "HealthBarsContainer.HealthBarMask")
    Path(frame, prefix .. "HealthBarsContainer.TempMaxHealthLoss", true)
    Path(frame, prefix .. "ManaBar", true)
    Path(frame, prefix .. "ManaBar.RightText")
    Path(frame, prefix .. "ManaBar.ManaBarMask")
    Path(frame, prefix .. "Name")
    Path(frame, prefix .. "ReputationColor")
    Path(frame, "TargetFrameContent.TargetFrameContentContextual.PvpBackgroundIcon")
    function frame:UpdateHealthBarVisuals()
        local container = self.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
        -- Simulate the native Camelot layout reset, including during combat.
        container.height, container.width = 15, 126
        container.point = { "BOTTOMRIGHT", self.TargetFrameContainer, "LEFT", 147, -9 }
        container.HealthBar.point = { "TOPLEFT", container, "TOPLEFT", 0, 3 }
    end
    function frame:CheckClassification()
        self:UpdateHealthBarVisuals()
        self.TargetFrameContainer.FrameTexture:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn", true)
    end
    return frame
end
TargetFrame, FocusFrame = Target("target"), Target("focus")
local function Small(unit)
    local frame = Object()
    frame.unit = unit
    for _, key in ipairs({ "Name", "Portrait", "FrameTexture" }) do
        Path(frame, key)
    end
    frame.healthbar = Path(frame, "HealthBar", true)
    Path(frame, "HealthBar.HealthBarMask")
    Path(frame, "ManaBar", true)
    Path(frame, "ManaBar.ManaBarMask")
    return frame
end
TargetFrameToT, FocusFrameToT, PetFrame = Small("targettarget"), Small("focustarget"), Small("pet")
PetName, PetPortrait, PetFrameTexture, PetFrameFlash, PetAttackModeTexture =
    Object(), Object(), Object(), Object(), Object()
PetFrameHealthBar, PetFrameHealthBarMask, PetFrameManaBar, PetFrameManaBarMask =
    PetFrame.HealthBar, PetFrame.HealthBar.HealthBarMask, PetFrame.ManaBar, PetFrame.ManaBar.ManaBarMask
PartyFrame = Object()
local party = Object()
party.unit, party.state, party.frameType = "party1", "player", "Party"
PartyFrame.MemberFrame1 = party
party.healthbar = Path(party, "HealthBarContainer.HealthBar", true)
for _, key in ipairs(predictionKeys) do
    Path(party.healthbar, key .. ".Fill")
end
Path(party, "HealthBarContainer.HealthBarMask")
Path(party, "HealthBarContainer.TempMaxHealthLoss", true)
Path(party, "ManaBar", true)
Path(party, "ManaBar.ManaBarMask")
for _, key in ipairs({
    "Name",
    "Flash",
    "Texture",
    "VehicleTexture",
    "PartyMemberOverlay.RoleIcon",
    "PartyMemberOverlay.Status",
}) do
    Path(party, key)
end
ComboFrame = Object()
-- An unrelated descendant can contain arbitrary secret state; never discover it.
mana.FeedbackFrame = setmetatable({}, {
    __index = function()
        error("visited feedback frame")
    end,
})
Path(party, "PetFrame.Texture")
Path(party, "PetFrame.Flash")
Path(party, "PetFrame.HealthBar", true)
local warnings = {}
local app = {
    core = {
        GetEditModeLibrary = function()
            return editModeLibrary
        end,
    },
    logger = {
        warn = function(_, fmt, ...)
            warnings[#warnings + 1] = string.format(fmt, ...)
        end,
        debug = function() end,
    },
    db = { profile = { layout = "current", unitFrames = {} } },
    addon = {
        NewModule = function(_, _, prototype)
            return setmetatable({ RegisterEvent = function() end }, { __index = prototype })
        end,
    },
}
local function Load(file)
    dofile("src/tests/locale-support.lua")
    assert(loadfile("SeamlessUnitframes/src/" .. file))("test", app)
end
Load("core/unitframes.lua")
for _, entry in ipairs(app.unitFrames.list) do
    app.db.profile.unitFrames[entry.key] = { healthBarColor = "default" }
end
Load("layout/atlas.lua")
Load("layout/layout.lua")
Load("layout/geometry.lua")
local layout = app.legacyLayout
layout:OnEnable()
assert(geometryWrites == 0 and artworkWrites == 0 and hookCount == 0, "default layout must be inert")
Load("healthcolor/healthcolor.lua")
app.healthColor:OnInitialize()
app.healthColor:OnEnable()
assert(geometryWrites == 0 and artworkWrites == 0, "default health colors must be inert")
local function Mode(mode)
    app.db.profile.layout = mode
    layout:Refresh()
    Drain()
end
local function HasOld(fill)
    return fill.file and fill.file:find("assets/legacy/", 1, true)
end
Mode("legacy")
assert(HasOld(health.fill) and HasOld(mana.fill))
assert(PlayerName.width == 96 and PlayerName.justify == "LEFT")
assert(health.height == 19 and health.point[5] == 0)
assert(health.fill.layer == nil, "layout must leave native draw layers alone")
assert(HasOld(PlayerFrame.PlayerFrameContainer.FrameTexture))
assert(#warnings == 0, "unexpected missing fixture components")
Mode("legacyRounded")
local border = PlayerFrame.PlayerFrameContainer.FrameTexture
local targetArt = app.legacyAtlases["ui-hud-unitframe-target-portraiton"]
assert(border.coords[1] == targetArt[5] and border.coords[2] == targetArt[4], "rounded border mirrors target art")
assert(border.width == targetArt[2] and border.height == targetArt[3], "target border keeps its original size")
assert(health.height == 20 and health.width == 126 and mana.width == 134, "rounded player matches target bar sizes")
local playerArt = PlayerFrame.PlayerFrameContainer
assert(playerArt.PlayerPortrait.width == 58 and playerArt.PlayerPortrait.height == 58)
assert(playerArt.PlayerPortraitMask.atlas == "CircleMask" and playerArt.PlayerPortraitMask.width == 57)
assert(playerArt.FrameFlash.coords[1] > playerArt.FrameFlash.coords[2], "combat border is mirrored")
assert(health.point[2].point[1] == "BOTTOMLEFT" and health.point[2].point[4] == -149)
assert(mana.point[1] == "TOPLEFT" and mana.point[2] == playerArt and mana.point[4] == -157)
assert(health.fill.file:find("target%-portraiton%-bar%-health"), "rounded player uses target health art")
assert(mana.LeftText.point[4] == 13, "power text clears the mirrored portrait")
assert(health.fill.file:find("bars/mirrored-fixed/", 1, true), "rounded health fill keeps the default gradient")
assert(mana.fill.file:find("bars/mirrored-fixed/", 1, true), "rounded power fill keeps the default gradient")
app.db.profile.unitFrames.player.healthBarColor = "class"
app.healthColor:RefreshFrame(PlayerFrame)
assert(
    health.fill.file:find("bars/mirrored-fixed/target-portraiton-bar-health-status.blp", 1, true),
    "class tint keeps reflected fill"
)
app.db.profile.unitFrames.player.healthBarColor = "default"
app.healthColor:RefreshFrame(PlayerFrame)
for _, mask in ipairs({ health.point[2].HealthBarMask, mana.ManaBarMask }) do
    assert(mask.file:find("assets/legacy/masks/", 1, true), "rounded bars use reflected mask files")
    assert(mask.coords[1] == 0 and mask.coords[2] == 1, "mask UVs must not be reflected at runtime")
end

local roundedWrites = artworkWrites
layout:Refresh()
assert(artworkWrites == roundedWrites, "stable rounded refresh must retain its artwork bindings")
playerArt.FrameTexture:SetAtlas("UI-HUD-UnitFrame-Player-PortraitOn", true)
assert(
    border.coords[1] == targetArt[5] and border.coords[2] == targetArt[4],
    "native art updates retain the reflection"
)
combat = true
app.db.profile.layout = "legacy"
layout:Refresh()
assert(layout:IsRoundedPlayer(PlayerFrame), "combat keeps the applied rounded family until geometry can change")
combat = false

Mode("legacy")
assert(border.coords[1] == app.legacyAtlases["ui-hud-unitframe-player-portraiton"][4], "Beta border restored")
assert(playerArt.PlayerPortraitMask.width == 60 and playerArt.PlayerPortrait.width == 60, "Beta portrait restored")
assert(playerArt.PlayerPortraitMask.file:find("playerportraitmask"), "Beta portrait mask restored")
assert(health.width == 124 and mana.width == 124, "Beta bar geometry restored")
Mode("legacyRounded")
Mode("current")
assert(border.coords == nil, "rounded UVs must restore to Default")
assert(playerArt.PlayerPortraitMask.atlas == "UI-HUD-UnitFrame-Player-Portrait-Mask", "Default mask restored")
Mode("legacyRounded")
PlayerFrame.unit = "vehicle"
layout:Refresh()
assert(playerArt.PlayerPortrait.width == 60 and health.width == 124, "vehicle restores native player regions")
PlayerFrame.unit = "player"
alternate = Object()
layout:Refresh()
assert(mana.width == 124 and mana.LeftText.point[4] == 2, "alternate power retains Beta geometry")
alternate = nil
layout:Refresh()
assert(playerArt.PlayerPortrait.width == 58 and mana.width == 134, "normal art restores the rounded player")
UNIT_FRAME_SHOW_HEALTH_ONLY = true
layout:Refresh()
assert(health.height == 32 and playerArt.PlayerPortrait.width == 60, "health-only art retains Beta geometry")
UNIT_FRAME_SHOW_HEALTH_ONLY = nil

Mode("legacy")
local oldHooks = hookCount
for i = 1, 4 do
    Mode("current")
    assert(health.fill.atlas == "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health")
    assert(PlayerName.width == 116 and PlayerName.justify == "CENTER")
    assert(health.height == 20 and health.point[5] == 3)
    assert(PlayerFrame.PlayerFrameContainer.FrameTexture.coords == nil, "old static UVs leaked into new layout")
    assert(health.fill.layer == nil)
    Mode("legacy")
end
assert(hookCount == oldHooks, "duplicate hooks on toggles")
for _, frame in ipairs(app.unitFrames.list) do
    app.db.profile.unitFrames[frame.key].healthBarColor = "class"
end
app.healthColor:Refresh()
assert(HasOld(health.fill) and health.fill.file:find("health%-status"))
assert(health.color[1] == 0.2)
assert(
    loss.color[1] == health.color[1] and loss.color[2] == health.color[2] and loss.color[3] == health.color[3],
    "loss overlay must not flash red over a class bar"
)
assert(loss.fill.file:find("health%-status"), "colored loss requires the white fill")
local beforeHealthRefresh = artworkWrites
app.healthColor:Refresh()
UnitFrameHealthBar_Update(health)
assert(artworkWrites == beforeHealthRefresh, "ordinary health updates must not replace unchanged fills")
Mode("legacy")
local beforeStableRefresh = artworkWrites
Mode("legacy")
assert(artworkWrites == beforeStableRefresh, "stable layout refresh must not swap green/white fills")
TargetFrame:CheckClassification()
assert(
    HasOld(TargetFrame.TargetFrameContainer.FrameTexture),
    "target artwork repair must happen before native update returns"
)
assert(#pending == 0, "target update must not defer repair until the next rendered frame")
-- Edit Mode can call native unit-frame updates many times in one frame. Each
-- hook must repair only its owner instead of rebuilding/recoloring the suite.
local allFrames, applyGeometry = app.unitFrames.All, layout.ApplyGeometry
local refreshColors, refreshFrameColor = app.healthColor.Refresh, app.healthColor.RefreshFrame
local scans, fullColorRefreshes, repaired, recolored = 0, 0, {}, {}
app.unitFrames.All = function(self)
    scans = scans + 1
    return allFrames(self)
end
layout.ApplyGeometry = function(self, roots, legacy)
    repaired[#repaired + 1] = roots
    return applyGeometry(self, roots, legacy)
end
app.healthColor.Refresh = function(self)
    fullColorRefreshes = fullColorRefreshes + 1
    return refreshColors(self)
end
app.healthColor.RefreshFrame = function(self, frame)
    recolored[#recolored + 1] = frame
    return refreshFrameColor(self, frame)
end
local comboPoint = ComboFrame.point
local anchorsBeforeBurst = anchorWrites
for _ = 1, 88 do
    UnitFrameManaBar_UpdateType(mana)
end
assert(scans == 0 and fullColorRefreshes == 0, "native update burst must not scan/recolor every frame")
assert(#repaired == 88 and #recolored == 88)
assert(anchorWrites == anchorsBeforeBurst, "stable native updates must not repeatedly clear/reapply identical anchors")
for index, roots in ipairs(repaired) do
    assert(#roots == 1 and roots[1] == PlayerFrame and recolored[index] == PlayerFrame)
end
assert(ComboFrame.point == comboPoint, "player repairs must not reposition the target's combo points")
local beforeOpening, colorsBeforeOpening = #repaired, #recolored
editModeActive, libraryEditing = true, false
for _ = 1, 88 do
    UnitFrameManaBar_UpdateType(mana)
end
FocusFrame:CheckClassification()
assert(#repaired == beforeOpening and #recolored == colorsBeforeOpening, "entry setup must deduplicate owner repairs")
libraryEditing = true
editModeCallbacks.enter()
assert(#repaired == beforeOpening + 1, "native entry must flush one scoped refresh synchronously")
local openingRoots = repaired[#repaired]
assert(#openingRoots == 2 and openingRoots[1] == PlayerFrame and openingRoots[2] == FocusFrame)
assert(#recolored == colorsBeforeOpening + 2, "entry flush must recolor each affected frame once")
assert(
    scans == 0 and fullColorRefreshes == 0 and #pending == 0,
    "entry flush must not scan the suite or use next-frame timers"
)
local afterOpening = #repaired
UnitFrameManaBar_UpdateType(mana)
assert(#repaired == afterOpening + 1, "updates after entry must still repair immediately")
libraryEditing = false
UnitFrameManaBar_UpdateType(mana)
local beforeCancelledOpening = #repaired
editModeCallbacks.exit()
libraryEditing = true
editModeCallbacks.enter()
assert(#repaired == beforeCancelledOpening, "exit must discard unflushed entry work")
editModeActive, libraryEditing = false, false
editModeCallbacks.exit()
local beforeUnrelated = #repaired
UnitFrame_Initialize(Object())
UnitFrame_Initialize(secret)
UnitFrameManaBar_UpdateType(secret)
assert(#repaired == beforeUnrelated, "unknown or secret update owners must be ignored")
FocusFrame:CheckClassification()
assert(#repaired > beforeUnrelated)
for index = beforeUnrelated + 1, #repaired do
    assert(#repaired[index] == 1 and repaired[index][1] == FocusFrame)
end
assert(ComboFrame.point == comboPoint, "focus repairs must not reposition the target's combo points")
layout:Refresh()
assert(scans > 0 and fullColorRefreshes == 1, "explicit refresh still updates the whole suite")
app.unitFrames.All, layout.ApplyGeometry = allFrames, applyGeometry
app.healthColor.Refresh, app.healthColor.RefreshFrame = refreshColors, refreshFrameColor
-- Cache only fixed anchors we wrote ourselves; every native anchor/parent
-- setter invalidates them even when its arguments are inaccessible.
local probe = Object()
local fixedPoint = { "CENTER", PlayerFrame, "CENTER", 7, 9 }
layout:Edit(probe, { point = fixedPoint })
local beforeCached = anchorWrites
layout:Edit(probe, { point = { unpack(fixedPoint) } })
assert(anchorWrites == beforeCached)
for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetParent" }) do
    callbacks[probe][method](secret, secret)
    local beforeInvalidated = anchorWrites
    layout:Edit(probe, { point = fixedPoint })
    assert(anchorWrites == beforeInvalidated + 2, method .. " must invalidate the fixed anchor")
end
probe.protected = true
combat = true
callbacks[probe].SetPoint(secret, secret)
local beforeProtected = anchorWrites
layout:Edit(probe, { point = fixedPoint })
assert(anchorWrites == beforeProtected, "cache must not bypass protected combat guards")
combat = false
layout:Edit(probe, { point = fixedPoint })
assert(anchorWrites == beforeProtected + 2, "combat-skipped repair must not populate the cache")
local nestedProbe = Object()
function nestedProbe:SetPoint(...)
    methods.SetPoint(self, ...)
    if not self.bounced then
        self.bounced = true
        self:ClearAllPoints()
    end
end
layout:Edit(nestedProbe, { point = fixedPoint })
assert(nestedProbe.point == nil)
layout:Edit(nestedProbe, { point = fixedPoint })
assert(nestedProbe.point and nestedProbe.point[4] == 7, "nested native setters must leave the anchor uncached")
combat = true
TargetFrame:CheckClassification()
assert(HasOld(TargetFrame.TargetFrameContainer.FrameTexture), "combat must not expose native sheet coordinates")
local targetContainer = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
local targetVisual = targetContainer.LeftText.point[2]
assert(targetContainer.height == 15, "native protected reset remains client-owned")
assert(targetVisual.height == 20 and targetVisual.point[4] == 149)
assert(targetVisual.HealthBar.point[4] == 0 and targetVisual.HealthBar.point[5] == 0)
assert(targetContainer.HealthBar.fill.alpha == 0)
targetContainer.HealthBar:SetMinMaxValues(0, secret)
targetContainer.HealthBar:SetValue(secret, secret)
assert(rawequal(targetVisual.HealthBar.range[2], secret))
assert(rawequal(targetVisual.HealthBar.values[1], secret))
assert(rawequal(targetVisual.HealthBar.values[2], secret))
classification = "minus"
TargetFrame:CheckClassification()
assert(targetVisual.height == 12 and targetVisual.width == 125)
assert(targetVisual.point[4] == 148)
classification = "elite"
TargetFrame:CheckClassification()
local dragon = TargetFrame.TargetFrameContainer.BossPortraitFrameTexture
assert(
    dragon.point[1] == "TOPRIGHT"
        and dragon.point[2] == TargetFrame.TargetFrameContainer
        and dragon.point[4] == -11
        and dragon.point[5] == -8,
    "legacy elite dragon uses the old art's offsets"
)
classification = secret
TargetFrame:CheckClassification()
FocusFrame:CheckClassification()
local focusContainer = FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
local focusVisual = focusContainer.LeftText.point[2]
assert(targetVisual.height == 20 and focusVisual.height == 20)
assert(focusContainer.height == 15 and focusContainer.HealthBar.fill.alpha == 0)
assert(targetVisual.HealthBar.fill.mask == targetVisual.HealthBarMask)
assert(targetContainer.LeftText.parent == targetVisual.Text)
-- Native segments are only made transparent; no field or owner is written.
local native = targetContainer.HealthBar.MyHealPredictionBar
assert(native.alpha == 0 and native.statusBar == nil and native.parent == nil)
assert(targetContainer.HealthBar.OverAbsorbGlow.alpha == 0)
assert(native.Fill.mask == nil and native.FillMask.point == nil)
local prediction = targetVisual.Prediction
assert(prediction.Mine.parent == targetVisual.HealthBar)
assert(prediction.Mine.point[2] == targetVisual.HealthBar.fill)
assert(prediction.Others.point[2] == prediction.Mine.fill)
assert(prediction.Absorb.point[2] == prediction.Others.fill)
assert(prediction.HealAbsorb.fillStyle == Enum.StatusBarFillStyle.Reverse)
assert(prediction.Mine.fill.mask == targetVisual.HealthBarMask)
assert(prediction.Mine.width == 126)
-- Calculator results are forwarded without being read.
assert(rawequal(prediction.Mine.values[1], secret) and rawequal(prediction.Mine.range[2], secret))
assert(rawequal(prediction.OverAbsorbGlow.alphaFrom[1], secret))
local events
for _, frame in ipairs(createdFrames) do
    if frame.scripts and frame.scripts.OnEvent then
        events = frame
    end
end
assert(events and events.events.UNIT_HEAL_PREDICTION)
local updates = #predictionUnits
events.scripts.OnEvent(events, "UNIT_HEALTH", "party1")
assert(#predictionUnits == updates, "other units must not refresh target prediction")
events.scripts.OnEvent(events, "UNIT_HEALTH", secret)
assert(#predictionUnits == updates + 2)
assert(HasOld(health.MyHealPredictionBar.Fill), "player prediction uses the old white fill")
local sourceLoss = targetContainer.TempMaxHealthLoss
callbacks[sourceLoss].Show(sourceLoss)
assert(targetVisual.TempMaxHealthLoss.shown)
callbacks[sourceLoss].Hide(sourceLoss)
assert(not targetVisual.TempMaxHealthLoss.shown)
sourceLoss:SetAlpha(secret)
assert(rawequal(targetVisual.TempMaxHealthLoss.alpha, secret))
assert(targetVisual.TempMaxHealthLoss.fillStyle == Enum.StatusBarFillStyle.Reverse)
assert(targetVisual.TempMaxHealthLoss.range[2] == 1)
classification = "normal"
combat = false
layout:Refresh()
-- Native updates with secret arguments must not be inspected by our hooks.
health.fill:SetAtlas("UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health")
assert(health.fill.file:find("health%-status"), "class color lost after native atlas update")
callbacks[health.fill].SetAtlas(secret, secret, secret)
assert(health.fill.file:find("health%-status"), "native secret atlas arguments must be ignored")
UnitFrameManaBar_UpdateType(secret, secret, secret)
Drain()
assert(health.fill.file:find("health%-status"))
for _, colorMode in ipairs({ "default", "reaction", "classReaction", "class" }) do
    app.db.profile.unitFrames.player.healthBarColor = colorMode
    app.healthColor:Refresh()
    assert(HasOld(health.fill), "color option lost standalone bar binding")
end
powerToken = "AMMOSLOT"
local warningCount = #warnings
Mode("legacy")
assert(mana.fill.file:find("bar%-mana"), "native unknown-power fallback must use mana")
assert(#warnings == warningCount, "normal power fallback must not warn")
powerToken = "INSANITY"
Mode("legacy")
assert(mana.fill.atlas == "Unit_Priest_Insanity_Fill", "full resource atlas must stay native")
powerToken = "MANA"
Mode("legacy")
classToken = secret
app.healthColor:Refresh()
assert(health.fill.file:find("health.blp", 1, true), "secret class should fall back without indexing")
classToken = "MAGE"
app.healthColor:Refresh()
Mode("current")
assert(health.fill.atlas == "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status")
assert(
    loss.color[1] == 1 and loss.color[2] == 0 and loss.color[3] == 0,
    "Current must restore the native red loss tint"
)
classification = "minus"
Mode("legacy")
local targetHealth = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar
assert(
    targetVisual.HealthBar.height == 12
        and targetHealth.fill.atlas == "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Health-Status"
)
assert(prediction.Mine.width == 125)
Mode("current")
assert(targetHealth.height == 20)
assert(targetContainer.LeftText.parent == targetContainer)
assert(native.alpha == 1 and targetContainer.HealthBar.OverAbsorbGlow.alpha == 1)
assert(native.statusBar == nil and native.parent == nil)
assert(health.MyHealPredictionBar.Fill.atlas == "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status")
assert(targetContainer.LeftText.point[2] == targetContainer)
assert(targetHealth.fill.alpha == 1 and not targetVisual.HealthBar.shown)
assert(not focusVisual.HealthBar.shown)
classification = "elite"
Mode("legacy")
assert(dragon.point[4] == -11 and dragon.point[5] == -8)
Mode("current")
assert(dragon.point[4] == 0 and dragon.point[5] == 1, "current restores the client's elite dragon offsets")
classification = secret
powerToken = secret
party.state = secret
Mode("legacy") -- must log and skip affected definitions without indexing secrets.
assert(#warnings > 0)
classification, powerToken, party.state = "normal", "ENERGY", "player"
alternate = Object()
Mode("legacy")
assert(mana.fill.file:find("classresource"))
alternate = nil
party.frameType = "CharacterFrameOn"
Mode("legacy")
assert(party.ManaBar.width == 69)
Mode("current")
assert(party.ManaBar.width == 70)
party.state = "vehicle"
Mode("legacy")
assert(party.HealthBarContainer.point[5] == -18)
Mode("current")
assert(party.HealthBarContainer.point[5] == -29)
PlayerFrame.unit = "vehicle"
Mode("legacy")
assert(health.width == 124)
assert(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.width == 118)
Mode("current")
assert(health.width == 124)
PlayerFrame.unit = "player"
UNIT_FRAME_SHOW_HEALTH_ONLY = true
Mode("legacy")
assert(health.height == 32)
Mode("current")
assert(health.height == 20)
UNIT_FRAME_SHOW_HEALTH_ONLY = nil
local count = geometryWrites
combat = true
app.db.profile.layout = "legacyRounded"
layout:Refresh()
Drain()
assert(geometryWrites == count, "layout change was not deferred")
app.db.profile.layout = "current"
layout:Refresh()
Drain()
assert(geometryWrites == count)
combat = false
Mode("legacy")
Mode("current")
-- Missing known fields fail with a diagnostic, not a nil call; later refresh retries.
local preview = Small("player")
preview.healthbar.unit, preview.healthbar.lockColor = "player", true
app.db.profile.unitFrames.targettarget.healthBarColor = "class"
Mode("legacy")
layout:ApplyToTPreview(preview)
app.healthColor:ApplyPreview(preview, "targettarget")
assert(HasOld(preview.FrameTexture) and HasOld(preview.healthbar.fill))
assert(preview.Name.justify == "LEFT" and preview.healthbar.color[1] == 0.2)
Mode("current")
layout:ApplyToTPreview(preview)
app.healthColor:ApplyPreview(preview, "targettarget")
assert(preview.FrameTexture.atlas == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn")
assert(preview.Name.justify == "CENTER" and preview.healthbar.color[1] == 0.2)
powerToken = "RAGE"
layout:ApplyToTPreview(preview, "MANA")
assert(
    preview.ManaBar.fill.atlas == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana",
    "VIP power selects existing mana artwork"
)
layout:ApplyToTPreview(preview, "ENERGY")
assert(preview.ManaBar.fill.atlas == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Energy")
layout:ApplyToTPreview(preview)
assert(
    preview.ManaBar.fill.atlas == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Rage",
    "live fallback restores existing power artwork"
)
powerToken = "MANA"
app.db.profile.unitFrames.targettarget.healthBarColor = "default"
app.healthColor:ApplyPreview(preview, "targettarget")
assert(preview.healthbar.color[1] == 1 and preview.healthbar.color[2] == 1)

local saved = PlayerFrame.PlayerFrameContainer
PlayerFrame.PlayerFrameContainer = nil
Mode("legacy")
PlayerFrame.PlayerFrameContainer = saved
Mode("current")
assert(PlayerName.width == 116)
Mode("legacy")
editModeActive, libraryEditing = true, false
UnitFrameManaBar_UpdateType(mana)
layout:OnDisable()
assert(PlayerName.width == 116, "module disable must restore Current")
local writesAfterDisable = geometryWrites
libraryEditing = true
editModeCallbacks.enter()
assert(geometryWrites == writesAfterDisable, "disabled entry work must not repaint restored frames")
editModeActive, libraryEditing = false, false
editModeCallbacks.exit()
print(
    "Fixed layout contracts passed: no render snapshots, both modes, colors, styles, secret inputs, combat deferral, diagnostics"
)
