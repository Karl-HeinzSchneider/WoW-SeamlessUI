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
function methods:SetAtlas(atlas, useSize)
    Mutation()
    self.atlas, self.texture = atlas, nil
    if useSize then
        self.width, self.height = 130, 22
    end
end
function methods:SetTexture(texture)
    Mutation()
    self.texture, self.atlas = texture, nil
end
function methods:SetTexCoord(...)
    Mutation()
    self.coords = { ... }
end
function methods:GetRegions()
    return unpack(self.regions)
end
function methods:GetChildren()
    return unpack(self.children)
end
function methods:HookScript() end
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

local roots, recolors = {}, 0
local app = {
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
        NewModule = function(_, _, module)
            function module:RegisterEvent() end
            return module
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
assert(PlayerName:GetJustifyH() == "LEFT")
PlayerFrame.unit = "vehicle"
module:Refresh()
app.db.profile.layout = "current"
module:Refresh()
assert(container:GetHeight() == originalHeight)
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
print("Legacy layout: restoration, combat deferral, state changes and opaque secret dimensions OK")
