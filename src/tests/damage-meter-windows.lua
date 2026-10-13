-- Run from the repository root: lua src/tests/damage-meter-windows.lua
unpack = unpack or table.unpack
local methods = {}
local function object(parent)
    return setmetatable({ parent = parent, scripts = {}, width = 400, height = 200, shown = true }, {
        __index = function(_, key)
            if methods[key] then
                return methods[key]
            end
            if key:match("^[A-Z]") then
                return function() end
            end
        end,
    })
end
function methods:SetScript(event, callback)
    self.scripts[event] = callback
end
function methods:GetScript(event)
    return self.scripts[event]
end
function methods:CreateTexture()
    return object(self)
end
function methods:CreateFontString()
    return object(self)
end
function methods:SetParent(parent)
    self.parent = parent
end
function methods:GetFrameLevel()
    return 1
end
function methods:SetPoint(...)
    self.point = { ... }
    self.points = self.points or {}
    self.points[self.point[1]] = self.point
end
function methods:SetText(text)
    self.text = text
end
function methods:SetFormattedText(format, ...)
    self.format, self.args = format, { ... }
end
function methods:SetNormalAtlas(atlas)
    self.normalAtlas = atlas
end
function methods:SetAtlas(atlas)
    self.atlas = atlas
end
function methods:SetTexture(texture)
    self.texture = texture
end
function methods:SetWidth(width)
    self.width = width
end
function methods:SetHeight(height)
    self.height = height
    if self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self)
    end
end
function methods:SetSize(width, height)
    self.width = width
    self:SetHeight(height)
end
function methods:SetResizeBounds(_, minHeight)
    if self.height < minHeight then
        self:SetHeight(minHeight)
    end
end
function methods:GetWidth()
    return self.width
end
function methods:GetHeight()
    return self.height
end
function methods:GetSize()
    return self.width, self.height
end
function methods:GetCenter()
    return 0, 0
end
function methods:GetTop()
    return 100
end
function methods:GetLeft()
    return -self.width / 2
end
function methods:GetRight()
    return self.width / 2
end
function methods:GetBottom()
    return 100 - self.height
end
function methods:GetEffectiveScale()
    return self.scale or 1
end
function methods:SetScale(scale)
    self.scale = scale
end
function methods:SetValue(value)
    self.statusValue = value
    if self.scripts.OnValueChanged then
        self.scripts.OnValueChanged(self, value)
    end
end
function methods:SetMinMaxValues(minimum, maximum)
    self.minimum, self.maximum = minimum, maximum
end
function methods:Hide()
    self.shown = false
end
function methods:Show()
    self.shown = true
end
function methods:SetShown(shown)
    self.shown = shown
end
function methods:IsShown()
    return self.shown
end

UIParent = object()
function CreateFrame(_, name, parent, template)
    assert(template == nil, "Meter frames must not inherit templates")
    local frame = object(parent)
    if name then
        assert(_G[name] == nil, "Named frames must be reused")
        _G[name] = frame
    end
    return frame
end
RAID_CLASS_COLORS = { MAGE = { r = 0.2, g = 0.5, b = 1 } }
DAMAGE_METER_CURRENT_SESSION_SHORT = "C"
DAMAGE_METER_OVERALL_SESSION_SHORT = "O"
DAMAGE_METER_SOURCE_NAME = "%d. %s"
Enum = { DamageMeterSessionType = { Current = 0, Overall = 1 }, DamageMeterType = { DamageDone = 0, Dps = 1 } }
function GetClassAtlas(class)
    return class
end
function UnitAffectingCombat()
    return false
end
function SecondsToClock(seconds)
    return tostring(seconds)
end
local secret = setmetatable({}, {
    __lt = function()
        error("Secret comparison")
    end,
    __le = function()
        error("Secret comparison")
    end,
    __add = function()
        error("Secret arithmetic")
    end,
    __div = function()
        error("Secret arithmetic")
    end,
    __concat = function()
        error("Secret concatenation")
    end,
})
function issecretvalue(value)
    return value == secret
end
function AbbreviateLargeNumbers(value)
    assert(value ~= secret, "Secret amounts must go directly to a widget")
    return tostring(value)
end

local session = { combatSources = {}, maxAmount = secret, durationSeconds = 10 }
for index = 1, 12 do
    session.combatSources[index] = {
        name = secret,
        totalAmount = secret,
        amountPerSecond = secret,
        classFilename = "MAGE",
        specIconID = 0,
        isLocalPlayer = index == 12,
    }
end
local reads = 0
C_DamageMeter = {
    GetCombatSessionFromType = function()
        reads = reads + 1
        return session
    end,
    IsDamageMeterAvailable = function()
        return true
    end,
    GetAvailableCombatSessions = function()
        return {}
    end,
}
C_CVar = {
    GetCVarBool = function()
        return true
    end,
}
local app = { db = { profile = { windows = {}, nextID = 1, initialized = false } } }
LibStub = function()
    return {
        Fetch = function()
            return "test-font"
        end,
    }
end
assert(loadfile("SeamlessDamageMeter/src/settings.lua"))("SeamlessDamageMeter", app)
app.db.profile.windowDefaults = app.windowDefaults
assert(loadfile("SeamlessDamageMeter/src/data.lua"))("SeamlessDamageMeter", app)
assert(loadfile("SeamlessDamageMeter/src/windows.lua"))("SeamlessDamageMeter", app)
app:RebuildWindows()
local frame = app.windows[1]
assert(SeamlessDamageMeterWindow1 == frame and frame.windowID == 1)
assert(frame.rows[1]:GetHeight() == 16 and frame.rows[1].entry:GetHeight() == 18)
assert(frame:IsShown() and frame.scrollbar:IsShown())
assert(frame.rows[1].name.args[2] == secret)
assert(frame.rows[1].value.args[1] == secret)
assert(frame.rows[1].value.args[2] == secret, "Restricted rates must also go directly to the widget")
assert(frame.rows[1].points.TOPLEFT[2] == 24, "Bar must start immediately after its icon inside the list inset")
assert(frame.localRow:IsShown(), "Offscreen local player must stay visible")
local fullHeight = app:GetWindowSetting(frame.config, "height")
frame.collapse.scripts.OnClick()
assert(frame:IsShown() and not frame.body:IsShown())
assert(app:GetWindowSetting(frame.config, "height") == fullHeight and frame:GetHeight() == 32)
assert(frame.point[5] == (fullHeight - 32) / 2, "Collapse must keep the header position stable")
assert(not frame.localRow:IsShown())
app:RebuildWindows()
assert(frame:GetHeight() == 32 and app:GetWindowSetting(frame.config, "height") == fullHeight)
frame.collapse.scripts.OnClick()
assert(frame:GetHeight() == fullHeight, "Expanding must not overwrite saved height with resize minimum")
frame.scrollbar:SetValue(5)
assert(frame.offset == 5 and not frame.localRow:IsShown())
session.combatSources[6].totalAmount = 12345
session.combatSources[6].amountPerSecond = 2.8
app:RefreshWindows()
assert(frame.rows[1].value.args[1] == "12345" and frame.rows[1].value.args[2] == "2.8")
frame.config.statistic = "Dps"
app:RefreshWindows()
assert(frame.rows[1]:IsShown())
assert(
    frame.rows[1].value.args[1] == "2.8" and frame.rows[1].value.args[2] == "12345",
    "Rate display must swap primary and secondary values"
)
frame.config.statistic = "Interrupts"
Enum.DamageMeterType.Interrupts = 2
app:RefreshWindows()
assert(frame.rows[1].value.text == "12345", "Action counts must not show a rate")
frame.config.statistic = "DamageDone"
app:AddWindow()
local second = app.windows[2]
assert(SeamlessDamageMeterWindow2 == second)
reads = 0
app:RefreshWindows()
assert(reads == 1, "Matching windows should share one API read")
frame.config.sessionID = 99
app:RefreshWindows()
assert(frame.message:IsShown() and not frame.rows[1]:IsShown() and not frame.localRow:IsShown())
frame.config.sessionID = nil
session.combatSources = {}
app:RefreshWindows()
assert(frame.offset == 0 and not frame.scrollbar:IsShown())
assert(not frame.rows[1]:IsShown() and not frame.localRow:IsShown())
C_DamageMeter = nil
app:RefreshWindows()
assert(frame.message.text == "This client does not provide the damage meter API.")
app:RemoveWindow(app.db.profile.windows[1])
assert(
    app.windows[1] == second and SeamlessDamageMeterWindow2 == second,
    "Deleting another window must not rename or reassign this frame"
)
app:RebuildWindows()
assert(app.windows[1] == second)
app:RemoveWindow(app.db.profile.windows[1])
assert(#app.db.profile.windows == 0 and not frame:IsShown())
app:RebuildWindows()
assert(#app.db.profile.windows == 0, "An empty profile must stay empty")
app.db.profile = {
    initialized = true,
    nextID = 3,
    windowDefaults = app.windowDefaults,
    windows = { { id = 2, statistic = "DamageDone", session = "Current", width = 400, height = 200, x = 0, y = 0 } },
}
app:RebuildWindows()
assert(
    app.windows[1] == second and SeamlessDamageMeterWindow2 == second,
    "Profile changes must reuse the same named frame"
)
assert(second.config.width == nil and second.config.overrides.width == 400, "Legacy geometry must migrate")
app.db.profile.windowDefaults.width = 480
app:AddWindow()
local inherited = app.windows[2]
assert(inherited:GetWidth() == 480 and next(inherited.config.overrides) == nil)
assert(second:GetWidth() == 400, "Migrated geometry must remain an override")
app.db.profile.windowDefaults.width = 520
app:RebuildWindows()
assert(inherited:GetWidth() == 520 and second:GetWidth() == 400)
inherited.config.anchorTo = second.config.id
inherited.config.overrides.scale = 1.5
app:RebuildWindows()
assert(inherited.anchorTarget == second and inherited:GetEffectiveScale() == 1.5)
assert(not app:CanAnchorTo(second.config, inherited.config.id))
app:RemoveWindow(second.config)
assert(inherited.config.anchorTo == nil and inherited.config.overrides.point == "TOPLEFT")
assert(inherited.config.overrides.width == nil, "Removing an anchor must not override the inherited size")
app.core = { logger = { chat = function() end } }
for _ = 1, 12 do
    app:AddWindow()
end
assert(#app.db.profile.windows == 10, "All creation paths must enforce the window limit")
print("Damage meter window regressions OK")
