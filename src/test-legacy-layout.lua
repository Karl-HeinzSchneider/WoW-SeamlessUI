-- Offline behavior tests; run with Lua 5.1+ from the repository root.
unpack = unpack or table.unpack
local pending, combat, writes, hooks = {}, false, 0, 0
local methods = {}
local function Object(kind, parent)
    local object = setmetatable({
        kind = kind or "Frame",
        parent = parent,
        width = 100,
        height = 20,
        points = {},
        children = {},
        regions = {},
        shown = true,
        justify = "CENTER",
        frameLevel = 8,
    }, { __index = methods })
    if parent then
        local list = kind == "Texture" and parent.regions or parent.children
        list[#list + 1] = object
    end
    return object
end
local function Mutation()
    assert(not combat, "UI mutation during combat")
    writes = writes + 1
end
function methods:GetWidth()
    return self.width
end
function methods:GetHeight()
    return self.height
end
function methods:SetWidth(value)
    assert(not canaccessvalue or canaccessvalue(value), "secret width passed to setter")
    Mutation()
    self.width = value
end
function methods:SetHeight(value)
    assert(not canaccessvalue or canaccessvalue(value), "secret height passed to setter")
    Mutation()
    self.height = value
end
function methods:SetSize(width, height)
    Mutation()
    self.width, self.height = width, height
end
function methods:GetParent()
    return self.parent
end
function methods:GetNumPoints()
    return #self.points
end
function methods:GetPoint(i)
    return unpack(self.points[i])
end
function methods:ClearAllPoints()
    Mutation()
    self.points = {}
end
function methods:SetPoint(point, relative, relativePoint, x, y)
    Mutation()
    for i, previous in ipairs(self.points) do
        if previous[1] == point then
            table.remove(self.points, i)
            break
        end
    end
    self.points[#self.points + 1] = { point, relative, relativePoint, x, y }
end
function methods:SetAllPoints(relative)
    Mutation()
    self.points = { { "TOPLEFT", relative, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0 } }
end
function methods:GetJustifyH()
    return self.justify
end
function methods:SetJustifyH(value)
    Mutation()
    self.justify = value
end
function methods:GetAtlas()
    return self.atlas
end
function methods:SetAtlas(atlas, useSize, _, resetTexCoords)
    Mutation()
    self.atlas, self.texture = atlas, nil
    if resetTexCoords then
        self.coords = { 0, 1, 0, 1 }
    end
    if useSize then
        self.width, self.height = 130, 22
    end
end
function methods:GetFrameLevel()
    return self.frameLevel
end
function methods:SetFrameLevel(level)
    Mutation()
    self.frameLevel = level
end
function methods:SetTexture(texture)
    Mutation()
    self.texture, self.atlas = texture, nil
end
function methods:SetTexCoord(...)
    Mutation()
    self.coords = { ... }
end
function methods:GetTexCoord()
    return unpack(self.coords or { 0, 1, 0, 1 })
end
function methods:GetRegions()
    return unpack(self.regions)
end
function methods:GetChildren()
    return unpack(self.children)
end
function methods:HookScript()
    error("forbidden script handler")
end
function methods:CreateTexture()
    return Object("Texture", self)
end
function methods:IsShown()
    return self.shown
end
function methods:SetShown(shown)
    Mutation()
    self.shown = shown
end
function methods:Hide()
    self:SetShown(false)
end
function methods:SetScale(scale)
    Mutation()
    self.scale = scale
end

function hooksecurefunc(object, method, callback)
    hooks = hooks + 1
    if type(object) == "string" then
        callback, method, object = method, object, _G
    end
    local original = object[method]
    object[method] = function(...)
        local result = { original(...) }
        callback(...)
        return unpack(result)
    end
end
C_Timer = {
    After = function(_, callback)
        pending[#pending + 1] = callback
    end,
}
C_Texture = {
    GetAtlasInfo = function()
        return { width = 130, height = 22 }
    end,
}
function InCombatLockdown()
    return combat
end
function UnitClassification(unit)
    return unit == "minus" and "minus" or "normal"
end
local function Drain()
    local count = 0
    while #pending > 0 do
        count = count + 1
        assert(count < 20, "refresh loop")
        table.remove(pending, 1)()
    end
end

local roots, recolors, warnings = {}, 0, {}
local app = {
    logger = {
        warn = function(_, format, ...)
            warnings[#warnings + 1] = string.format(format, ...)
        end,
    },
    db = { profile = { layout = "current" } },
    unitFrames = {
        All = function()
            return roots
        end,
    },
    healthColor = {
        Refresh = function()
            recolors = recolors + 1
        end,
    },
    addon = {
        NewModule = function(_, _, prototype)
            -- AceAddon returns a distinct instance inheriting from the prototype.
            -- Methods added by a later file exist only on that returned instance.
            return setmetatable({ RegisterEvent = function() end }, { __index = prototype })
        end,
    },
}
assert(loadfile("SeamlessUnitframes/src/layout/atlas.lua"))("test", app)
assert(loadfile("SeamlessUnitframes/src/layout/layout.lua"))("test", app)
assert(loadfile("SeamlessUnitframes/src/layout/geometry.lua"))("test", app)
local module = app.legacyLayout
module:OnEnable()
assert(writes == 0 and hooks == 0, "default mode must leave frames alone")

-- A texture receives native atlas changes while the layout owns its raw artwork.
local root = Object()
local texture = Object("Texture", root)
local originalAtlas = "UI-HUD-UnitFrame-Player-PortraitOn"
texture:SetAtlas(originalAtlas, true)
texture:SetPoint("CENTER", root, "CENTER", 4, 5)
roots[1] = root
app.db.profile.layout = "legacy"
module:Refresh()
assert(texture.texture and texture.texture:find("assets/legacy/"))
assert(module:GetAtlas(texture) == originalAtlas)
root:SetShown(true)
assert(#pending > 0, "root visibility must request refresh through a secure method post-hook")
Drain()
local nativeWidth = 151
texture:SetWidth(nativeWidth)
texture:SetPoint("CENTER", root, "CENTER", 9, 10)
texture:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn", false)
Drain()
assert(texture.texture, "native update must reapply legacy art")
app.db.profile.layout = "current"
module:Refresh()
assert(texture:GetAtlas() == "UI-HUD-UnitFrame-Target-PortraitOn", "restore latest native atlas")
assert(texture:GetWidth() == nativeWidth, "restore latest explicit native width")
local _, _, _, x, y = texture:GetPoint(1)
assert(x == 9 and y == 10, "restore native anchor")

-- No update or restore may mutate UI objects while combat is locked.
app.db.profile.layout = "legacy"
combat = true
local before = writes
module:Refresh()
assert(writes == before)
app.db.profile.layout = "current"
module:OnProfileRefresh()
Drain()
assert(writes == before)
combat = false
module:Refresh()

-- Repeated toggles must not add hooks or drift dimensions.
app.db.profile.layout = "legacy"
module:Refresh()
local hookCount = hooks
for _ = 1, 5 do
    app.db.profile.layout = "current"
    module:Refresh()
    app.db.profile.layout = "legacy"
    module:Refresh()
end
assert(hooks == hookCount, "duplicate hooks")
app.db.profile.layout = "current"
module:Refresh()
assert(texture:GetWidth() == nativeWidth)

-- A child created after its parent was scanned must also get the old art.
local child = Object("Frame", root)
local late = Object("Texture", child)
late:SetAtlas(originalAtlas, true)
app.db.profile.layout = "legacy"
module:Refresh()
assert(late.texture, "late-created child was not discovered")
app.db.profile.layout = "current"
module:Refresh()
assert(late:GetAtlas() == originalAtlas)

-- Geometry and profile restoration use real fixture names/paths, not hand-coded
-- expected copies of the layout implementation.
local function Part(parent, key, kind)
    local value = Object(kind or "Frame", parent)
    value:SetPoint("CENTER", parent, "CENTER", 0, 0)
    parent[key] = value
    return value
end
PlayerFrame = Object()
PlayerFrame.unit = "player"
local content = Part(PlayerFrame, "PlayerFrameContent")
local main = Part(content, "PlayerFrameContentMain")
local container = Part(main, "HealthBarsContainer")
Part(container, "HealthBar")
local lossOverlay = Part(container, "PlayerFrameHealthBarAnimatedLoss")
Part(container, "HealthBarMask", "Texture")
local mana = Part(Part(main, "ManaBarArea"), "ManaBar")
Part(mana, "ManaBarMask", "Texture")
Part(main, "StatusTexture", "Texture")
Part(main, "PvpBackgroundIcon", "Texture")
local art = Part(PlayerFrame, "PlayerFrameContainer")
Part(art, "FrameFlash", "Texture")
PlayerName = Part(main, "Name", "Texture")
PlayerPVPTimerText = Part(main, "Timer", "Texture")
function PlayerFrame_GetAlternatePowerBar()
    return nil
end
roots[2] = PlayerFrame
local originalPoint = { container:GetPoint(1) }
local originalHeight = container:GetHeight()
app.db.profile.layout = "legacy"
module:Refresh()
assert(container:GetHeight() ~= originalHeight)
assert(
    lossOverlay:GetFrameLevel() < container.HealthBar:GetFrameLevel(),
    "damage-loss overlay must be behind live health"
)
assert(PlayerName:GetJustifyH() == "LEFT")
PlayerFrame.unit = "vehicle"
module:Refresh()
app.db.profile.layout = "current"
module:Refresh()
assert(container:GetHeight() == originalHeight)
assert(lossOverlay:GetFrameLevel() == 8, "restore native loss-overlay stacking")
assert(PlayerName:GetJustifyH() == "CENTER")
local restored = { container:GetPoint(1) }
for i, value in ipairs(originalPoint) do
    assert(restored[i] == value)
end

local target = Object()
target.unit = "minus"
local tc = Part(target, "TargetFrameContent")
local tm = Part(tc, "TargetFrameContentMain")
local context = Part(tc, "TargetFrameContentContextual")
Part(context, "PvpBackgroundIcon", "Texture")
local th = Part(tm, "HealthBarsContainer")
local hb = Part(th, "HealthBar")
local fill = Part(hb, "HealthBarTexture", "Texture")
fill:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status")
Part(th, "HealthBarMask", "Texture"):SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Mask")
Part(Part(th, "TempMaxHealthLoss"), "TempMaxHealthLossTexture", "Texture"):SetAtlas(
    "UI-HUD-UnitFrame-Target-PortraitOn-Bar-TempHPLoss"
)
Part(tm, "Name", "Texture")
Part(tm, "ReputationColor", "Texture")
Part(Part(tm, "ManaBar"), "RightText", "Texture")
Part(Part(target, "TargetFrameContainer"), "Flash", "Texture")
roots[3] = target
local party = Object()
party.state = "player"
local ph = Part(party, "HealthBarContainer")
Part(ph, "HealthBar")
Part(ph, "HealthBarMask", "Texture")
Part(Part(party, "ManaBar"), "ManaBarMask", "Texture")
Part(party, "Flash", "Texture")
Part(party, "Name", "Texture")
local overlay = Part(party, "PartyMemberOverlay")
Part(overlay, "RoleIcon", "Texture")
Part(overlay, "Status", "Texture")
roots[4] = party
app.db.profile.layout = "legacy"
module:Refresh()
assert(module:GetAtlas(fill):find("MinusMob"), "minus-mob art must match its old mask")
assert(th:GetHeight() == 12)
assert(ph:GetWidth() == 70)
target.unit = "target"
party.state, party.frameType = "vehicle", "Party"
module:Refresh()
assert(th:GetHeight() == 20)
assert(ph:GetWidth() == 67)
assert(not module:GetAtlas(fill):find("MinusMob"))
party.state, party.frameType = "player", "CharacterFrameOn"
module:Refresh()
assert(party.ManaBar:GetWidth() == 69)
combat = true
local combatWrites = writes
app.db.profile.layout = "current"
module:Refresh()
assert(writes == combatWrites)
combat = false
module:Refresh()
assert(th:GetHeight() == 20 and ph:GetWidth() == 100)
assert(fill:GetAtlas() == "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status")

-- Secret dimensions are opaque: comparing them can throw in the real client.
-- Distinct sentinels with an equality trap reproduce that failure offline.
local secretMeta = {
    __eq = function()
        error("secret dimension compared")
    end,
}
local secretWidth, secretHeight = setmetatable({}, secretMeta), setmetatable({}, secretMeta)
local secretInfoWidth, secretInfoHeight = setmetatable({}, secretMeta), setmetatable({}, secretMeta)
local secrets = { [secretWidth] = true, [secretHeight] = true, [secretInfoWidth] = true, [secretInfoHeight] = true }
function canaccessvalue(value)
    return not secrets[value]
end
local nativeInfo = C_Texture.GetAtlasInfo
C_Texture.GetAtlasInfo = function(name)
    if name == originalAtlas then
        return { width = secretInfoWidth, height = secretInfoHeight }
    end
    return nativeInfo(name)
end
local secretTexture = Object("Texture", Object("Frame", root))
secretTexture:SetAtlas(originalAtlas)
secretTexture.width, secretTexture.height = secretWidth, secretHeight
app.db.profile.layout = "legacy"
module:Refresh()
module:Edit(secretTexture, { width = 42, height = 17 })
assert(rawequal(secretTexture.width, secretWidth) and rawequal(secretTexture.height, secretHeight))
app.db.profile.layout = "current"
module:Refresh()
assert(secretTexture:GetAtlas() == originalAtlas)
assert(rawequal(secretTexture.width, secretWidth) and rawequal(secretTexture.height, secretHeight))

-- A native update can make a previously readable, owned dimension secret.
C_Texture.GetAtlasInfo = nativeInfo
app.db.profile.layout = "legacy"
module:Refresh()
texture:SetWidth(222)
texture.width = secretWidth
-- The secure hook records the now-secret result returned by GetWidth.
texture:SetSize(secretWidth, 22)
app.db.profile.layout = "current"
module:Refresh()
assert(rawequal(texture.width, secretWidth), "secret native width must not be replayed to SetWidth")
-- A later file adds geometry to Ace's returned instance, not to its prototype.
local geometry = module.ApplyGeometry
module.ApplyGeometry = nil
app.db.profile.layout = "legacy"
local warningCount, beforeMissing = #warnings, writes
module:OnProfileRefresh()
Drain()
module:Refresh()
assert(writes == beforeMissing)
assert(#warnings == warningCount + 1 and warnings[#warnings]:find("missing ApplyGeometry", 1, true))
module.ApplyGeometry = geometry

-- Incomplete layouts log the missing path and recover on a later refresh.
local targetMana = tm.ManaBar
tm.ManaBar = nil
warningCount = #warnings
module:Refresh()
module:Refresh()
assert(#warnings == warningCount + 1)
assert(warnings[#warnings]:find("TargetFrameContent.TargetFrameContentMain.ManaBar.RightText", 1, true))
tm.ManaBar = targetMana
module:Refresh()
assert(targetMana:GetWidth() == 134)

local forbidden = Object()
function forbidden:IsForbidden()
    return true
end
function forbidden:GetChildren()
    error("forbidden frame was traversed")
end
roots[#roots + 1] = forbidden
warningCount = #warnings
module:Refresh()
module:Refresh()
assert(#warnings == warningCount + 1 and warnings[#warnings]:find("forbidden region", 1, true))
table.remove(roots)
app.db.profile.layout = "current"
module:Refresh()

-- Model native bar redraws separately from Texture:SetTexCoord: SetValue writes
-- engine-owned UVs directly and never calls Lua texture methods.
local function StatusBar(parent, atlas)
    local bar = Object("Frame", parent)
    local fill = Object("Texture", bar)
    function bar:GetStatusBarTexture()
        return fill
    end
    function bar:SetStatusBarTexture(asset)
        Mutation()
        self.asset = asset
        if asset:find("Interface/", 1, true) then
            fill.atlas, fill.texture = nil, asset
        else
            fill.atlas, fill.texture = asset, nil
        end
        fill.coords = { 0, 1, 0, 1 }
    end
    function bar:SetValue(value)
        -- The client can render secret values; addon code must not inspect them.
        self.value = value
        local fraction = canaccessvalue(value) and value or 0.37
        fill.coords = { 0, fraction, 0, 1 }
    end
    function bar:SetStatusBarColor(r, g, b)
        self.color = { r, g, b }
    end
    bar:SetStatusBarTexture(atlas)
    return bar, fill
end
local colorRoot = Object()
colorRoot.key = "target"
roots[#roots + 1] = colorRoot
local healthAtlas = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
local healthBar, healthFill = StatusBar(colorRoot, healthAtlas)
local powerBar, powerFill = StatusBar(colorRoot, "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana")
colorRoot.healthbar = healthBar
healthBar.unit, healthBar.unitFrame, healthBar.lockColor = "testtarget", colorRoot, true
app.unitFrames.KeyOf = function(_, frame)
    return frame and frame.key
end
local unitState = { player = true, connected = true, denied = false, reaction = { 1, 0, 0 } }
function UnitFrameHealthBar_Update() end
function UnitExists()
    return true
end
function UnitIsConnected()
    return unitState.connected
end
function UnitIsPlayer()
    return unitState.player
end
function UnitClass()
    return "Mage", "MAGE"
end
function UnitPlayerControlled()
    return unitState.player
end
function UnitIsTapDenied()
    return unitState.denied
end
function UnitSelectionColor()
    return unpack(unitState.reaction)
end
function CreateColor(r, g, b)
    return {
        r = r,
        g = g,
        b = b,
        SetRGB = function(self, red, green, blue)
            self.r, self.g, self.b = red, green, blue
        end,
        GetRGB = function(self)
            return self.r, self.g, self.b
        end,
    }
end
RAID_CLASS_COLORS = { MAGE = CreateColor(0.2, 0.4, 0.9) }
app.logger.debug = function() end
app.db.profile.unitFrames = { target = { healthBarColor = "class" } }
assert(loadfile("SeamlessUnitframes/src/healthcolor/healthcolor.lua"))("test", app)
app.healthColor:OnInitialize()
app.healthColor:OnEnable()
local function Color(r, g, b)
    assert(healthBar.color[1] == r and healthBar.color[2] == g and healthBar.color[3] == b)
end
for _, selection in ipairs({ "current", "legacy", "current", "legacy" }) do
    app.db.profile.layout = selection
    for _, mode in ipairs({ "default", "class", "reaction", "classReaction" }) do
        app.db.profile.unitFrames.target.healthBarColor = mode
        unitState.player, unitState.connected, unitState.denied = true, true, false
        module:Refresh()
        app.healthColor:Refresh()
        Drain()
        if mode == "default" then
            Color(1, 1, 1)
        elseif mode == "reaction" then
            Color(1, 0, 0)
        else
            Color(0.2, 0.4, 0.9)
        end
        for _, fraction in ipairs({ 0, 0.25, 0.75, 1, secretWidth }) do
            healthBar:SetValue(fraction)
            powerBar:SetValue(fraction)
            if selection == "legacy" then
                local logicalHealth = module:GetAtlas(healthFill)
                if app.legacyAtlases[logicalHealth:lower()] then
                    assert(healthBar.asset:find("/legacy/bars/", 1, true), "health must use standalone native fill")
                else
                    assert(healthBar.asset == logicalHealth, "unchanged health atlas must be assigned through the bar")
                end
                assert(powerBar.asset:find("/legacy/bars/", 1, true), "power must use standalone native fill")
                assert(healthFill.coords[1] == 0 and healthFill.coords[3] == 0 and healthFill.coords[4] == 1)
                assert(powerFill.coords[1] == 0 and powerFill.coords[4] == 1)
            end
        end
    end
end
unitState.player = false
app.healthColor:Refresh()
Drain()
Color(1, 0, 0)
unitState.denied = true
app.healthColor:Refresh()
Drain()
Color(0.5, 0.5, 0.5)
unitState.connected = false
app.healthColor:Refresh()
Drain()
Color(1, 1, 1)
unitState.player, unitState.connected, unitState.denied = true, true, false
app.db.profile.unitFrames.target.healthBarColor = "default"
module:Refresh()
Drain()
local defaultFill = healthBar.asset
combat = true
app.db.profile.unitFrames.target.healthBarColor = "class"
app.healthColor:Refresh()
Drain()
assert(healthBar.asset == defaultFill, "combat color change must not reset legacy fill to an atlas sheet")
Color(1, 1, 1)
combat = false
module:Refresh()
Drain()
Color(0.2, 0.4, 0.9)
assert(module:GetAtlas(healthFill):lower():sub(-7) == "-status")
combat = true
app.db.profile.unitFrames.target.healthBarColor = "default"
app.healthColor:Refresh()
Drain()
Color(0.2, 0.4, 0.9)
combat = false
module:Refresh()
Drain()
Color(1, 1, 1)
assert(healthBar.asset == defaultFill)
app.db.profile.layout = "current"
module:Refresh()
Drain()
assert(healthBar.asset == healthAtlas, "restore native health atlas through the owning bar")
assert(powerBar.asset == "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana")
local playerColorRoot = Object()
playerColorRoot.key = "player"
roots[#roots + 1] = playerColorRoot
local playerBar, playerFill = StatusBar(playerColorRoot, "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health")
playerColorRoot.healthbar = playerBar
playerBar.unit, playerBar.unitFrame, playerBar.lockColor = "testplayer", playerColorRoot, true
app.db.profile.unitFrames.player = { healthBarColor = "class" }
for _, mode in ipairs({ "class", "default", "class", "default" }) do
    app.db.profile.layout = "legacy"
    app.db.profile.unitFrames.player.healthBarColor = mode
    module:Refresh()
    Drain()
    assert(playerBar.asset:find("/legacy/bars/player%-portraiton%-bar%-health"))
    assert((module:GetAtlas(playerFill):lower():sub(-7) == "-status") == (mode == "class"))
    playerBar:SetValue(secretWidth)
    assert(playerFill.coords[1] == 0 and playerFill.coords[4] == 1)
    app.db.profile.layout = "current"
    module:Refresh()
    Drain()
    assert(not playerBar.asset:find("/legacy/", 1, true))
end
-- Full sprite/mask restoration, not just status-bar asset names. Atlas setters
-- preserve explicit UVs unless resetTexCoords is explicitly requested.
local staticRoot = Object()
roots[#roots + 1] = staticRoot
local staticTextures = {}
for name, data in pairs(app.legacyAtlases) do
    if not data[8] then
        local sprite = Object("Texture", staticRoot)
        sprite:SetAtlas(name, true, nil, true)
        staticTextures[#staticTextures + 1] = { sprite = sprite, atlas = name }
    end
end
for _ = 1, 3 do
    app.db.profile.layout = "legacy"
    module:Refresh()
    Drain()
    for _, entry in ipairs(staticTextures) do
        assert(entry.sprite.texture, "legacy static art must use the old sheet")
    end
    app.db.profile.layout = "current"
    module:Refresh()
    Drain()
    for _, entry in ipairs(staticTextures) do
        local sprite = entry.sprite
        assert(sprite:GetAtlas() == entry.atlas)
        assert(
            sprite.coords[1] == 0 and sprite.coords[2] == 1 and sprite.coords[3] == 0 and sprite.coords[4] == 1,
            "restored native atlas retained old sheet coordinates"
        )
        assert(sprite:GetWidth() == 130 and sprite:GetHeight() == 22, "native sprite/mask size was not restored")
    end
end
local custom = staticTextures[1].sprite
app.db.profile.layout = "legacy"
module:Refresh()
Drain()
custom:SetTexCoord(0.1, 0.9, 0.2, 0.8)
module:Refresh()
Drain()
app.db.profile.layout = "current"
module:Refresh()
Drain()
assert(custom.coords[1] == 0.1 and custom.coords[3] == 0.2, "restore native explicit coordinates")
app.db.profile.layout = "legacy"
module:Refresh()
Drain()
custom:SetAtlas(staticTextures[1].atlas, true, nil, true)
module:Refresh()
Drain()
app.db.profile.layout = "current"
module:Refresh()
Drain()
assert(custom.coords[1] == 0 and custom.coords[3] == 0, "native atlas reset must retire previous explicit coordinates")
print(
    "Legacy layout: damage stacking, full sprite/mask restoration, color integration, frame safety and secret values OK"
)
