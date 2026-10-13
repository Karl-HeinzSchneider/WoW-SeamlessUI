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
assert(#app.windows == 10 and #app.db.profile.windows == 10, "Every slot must exist from startup")
for id = 2, 10 do
    assert(app.windowFrames[id] and not app.windowFrames[id]:IsShown())
end
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
app:SetWindowEnabled(app.db.profile.windows[1], false)
assert(
    app.windows[2] == second and SeamlessDamageMeterWindow2 == second,
    "Deleting another window must not rename or reassign this frame"
)
app:RebuildWindows()
assert(app.windows[2] == second)
app:SetWindowEnabled(app.db.profile.windows[2], false)
assert(#app.db.profile.windows == 10 and not frame:IsShown() and not second:IsShown())
app:RebuildWindows()
assert(
    app:GetUnusedWindowSlot() == 1 and not frame:IsShown() and not second:IsShown(),
    "A fully inactive profile must remain inactive"
)
app.db.profile = {
    initialized = true,
    nextID = 3,
    windowDefaults = app.windowDefaults,
    windows = { { id = 2, statistic = "DamageDone", session = "Current", width = 400, height = 200, x = 0, y = 0 } },
}
app:RebuildWindows()
assert(
    app.windows[2] == second and SeamlessDamageMeterWindow2 == second,
    "Profile changes must reuse the same named frame"
)
assert(second.config.width == nil and second.config.overrides.width == 400, "Legacy geometry must migrate")
app.db.profile.windowDefaults.width = 480
app:AddWindow()
local inherited = app.windowFrames[1]
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
local anchorPoint = inherited.point
app:SetWindowEnabled(second.config, false)
assert(inherited.config.anchorTo == 2 and inherited.anchorTarget == second and not second:IsShown())
for index = 1, 5 do
    assert(inherited.point[index] == anchorPoint[index], "Deactivation must preserve the dependent's anchor geometry")
end
assert(inherited.config.overrides.width == nil, "Deactivating an anchor must not override the inherited size")
app.core = { logger = { chat = function() end } }
for _ = 1, 12 do
    app:AddWindow()
end
assert(#app.db.profile.windows == 10, "All creation paths must enforce the window limit")
local slot = app.windowFrames[3]
slot.config.hidden = true
slot.config.collapsed = true
slot.config.statistic = "Dps"
slot.config.sessionID = 99
slot.config.overrides.fontSize = 20
app:RebuildWindows()
assert(not slot:IsShown() and app:GetUnusedWindowSlot() == nil, "Hidden windows must retain their slot")
local previousConfig = slot.config
app:SetWindowEnabled(previousConfig, false)
assert(slot.config == previousConfig and not slot:IsShown())
assert(app:GetUnusedWindowSlot() == 3)
app:AddWindow()
assert(app.windowFrames[3] == slot and slot:IsShown(), "Reactivation must reuse the slot's frame")
assert(slot.config == previousConfig and slot.config.overrides.fontSize == 20)
assert(slot.config.statistic == "Dps" and slot.config.session == "Current")
assert(not slot.config.hidden and slot.config.collapsed and slot.config.sessionID == 99)
for _ = 1, 25 do
    app:SetWindowEnabled(slot.config, false)
    app:AddWindow()
    assert(app.windowFrames[3] == slot)
end
local allocated = 0
for id in pairs(app.windowFrames) do
    assert(id >= 1 and id <= 10)
    allocated = allocated + 1
end
assert(allocated == 10, "Repeated removal and creation must not grow the frame pool")
print("Damage meter window regressions OK")

-- Exercise the adapter against the library's exposed database contract and callbacks.
local registered = 0
local eme = { baseFramesDB = {}, framesDB = {} }
function eme:IsRegistered(frame)
    return frame.system ~= nil
end
function eme:RegisterFrame(frame, _, db)
    registered = registered + 1
    frame.system = 100 + registered
    frame.EMECheckButtonFrame = object(frame)
    self.baseFramesDB[frame.system], self.framesDB[frame.system] = db, db
    frame.SetScaleOverride = frame.SetScale
end
function eme:RegisterResizable(frame, minimum, maximum, step)
    assert(minimum == 50 and maximum == 200 and step == 5)
end
function eme:SetDontResize(frame)
    frame.EMEDontResize = true
end
function eme:IsFrameEnabled(frame)
    return self.framesDB[frame.system].enabled
end
function methods:GetRect()
    return self:GetLeft(), self:GetBottom(), self:GetSize()
end
function methods:GetScale()
    return self.scale or 1
end
local combat = false
function InCombatLockdown()
    return combat
end
function hooksecurefunc(target, key, callback)
    local original = target[key]
    target[key] = function(...)
        original(...)
        callback(...)
    end
end
Enum.EditModeLayoutType = { Character = 2 }
EditModeManagerFrame = {
    GetActiveLayoutInfo = function()
        return { layoutType = 1, layoutName = "Test" }
    end,
    ExitEditMode = function(self)
        self.editModeActive = false
    end,
}
local originalLibStub = LibStub
LibStub = function(name)
    if name == "EditModeExpanded-1.0" then
        return eme
    end
    return originalLibStub(name)
end
app.core.RefreshOptions = function() end
app.addon = {
    IsEnabled = function()
        return true
    end,
}
assert(loadfile("SeamlessDamageMeter/src/editmode.lua"))("SeamlessDamageMeter", app)
app:RebuildWindows()
assert(registered == 10, "Every slot must register once, including inactive slots")
local meter = app.windowFrames[1]
assert(meter.EMEDontResize)
assert(eme.baseFramesDB[meter.system] == meter.config.editMode)
assert(eme.framesDB[meter.system] == meter.config.editMode.profiles["1-Test"])
meter.config.enabled = false
meter.config.hidden = true
EditModeManagerFrame.editModeActive = true
app:RebuildWindows()
assert(meter:IsShown(), "Edit Mode must preview inactive/hidden slots")
assert(not meter.config.enabled and meter.config.hidden, "Preview must not activate slots")
meter:SetScaleOverride(1.25)
assert(meter.config.overrides.scale == 1.25)
assert(eme.framesDB[meter.system].settings[16] ~= nil)
local originalDatabase = meter.config.editMode
app.db.profile = { windows = {}, initialized = false, windowDefaults = app.windowDefaults }
app:RebuildWindows()
assert(registered == 10, "Profile changes must reuse library registrations")
assert(meter.config.editMode ~= originalDatabase)
assert(eme.baseFramesDB[meter.system] == meter.config.editMode, "Rebind the active AceDB profile")
assert(meter.config.overrides.scale == nil, "Profile changes must preserve inheritance")
assert(meter.config.overrides.x == nil and meter.config.overrides.y == nil)
meter:SetScaleOverride(meter:GetScale())
assert(meter.config.overrides.scale == nil, "An unchanged library scale must remain inherited")
assert(
    meter.config.overrides.x == nil and meter.config.overrides.y == nil,
    "An unchanged library position stays inherited"
)
eme.framesDB[meter.system].enabled = false
app:RebuildWindows()
assert(not meter:IsShown(), "The Expanded checkbox controls Edit Mode previews")
eme.framesDB[meter.system].enabled = true
meter.config.hidden = true
EditModeManagerFrame:ExitEditMode()
assert(not meter:IsShown(), "Exit must restore the profile's normal visibility")
local savedX = meter.config.overrides.x
local originalCenter = methods.GetCenter
function methods:GetCenter()
    if self.testCenter then
        return self.testCenter, 0
    end
    return originalCenter(self)
end
meter.testCenter = 200
meter:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 10, 10)
assert(meter.config.overrides.x ~= savedX, "Library movement must update meter overrides")
assert(meter.point[1] == "BOTTOMLEFT", "Saving library movement must not recursively reposition")
combat = true
savedX = meter.config.overrides.x
meter:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 20)
assert(meter.config.overrides.x == savedX, "Do not inspect restricted geometry in combat")
print("Damage meter Edit Mode regressions OK")
