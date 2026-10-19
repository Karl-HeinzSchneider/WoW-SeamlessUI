-- Run from the repository root: lua src/tests/blizzard-position.lua
local unpackValues = unpack or table.unpack
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
local function frame(name, parent)
    local f = { name = name, parent = parent, scripts = {}, shown = true, points = {} }
    function f:GetName()
        return self.name
    end
    function f:GetParent()
        return self.parent
    end
    function f:IsObjectType(kind)
        return kind == "Frame"
    end
    function f:GetNumPoints()
        return #self.points
    end
    function f:ClearAllPoints()
        self.points = {}
    end
    function f:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[1] = { point, relativeTo, relativePoint, x, y }
    end
    function f:GetPoint(index)
        return unpackValues(self.points[index] or {})
    end
    function f:SetScript(event, callback)
        self.scripts[event] = callback
    end
    function f:SetText(text)
        self.text = text
    end
    function f:GetText()
        return self.text or ""
    end
    function f:SetEnabled(value)
        self.enabled = value
    end
    function f:SetDefaultText(text)
        self.text = text
    end
    function f:SetupMenu(callback)
        self.menu = callback
    end
    function f:GenerateMenu() end
    function f:HasFocus()
        return self.focus
    end
    function f:SetFocus()
        self.focus = true
    end
    function f:ClearFocus()
        local focused = self.focus
        self.focus = false
        if focused and self.scripts.OnEditFocusLost then
            self.scripts.OnEditFocusLost(self)
        end
    end
    function f:CreateFontString()
        return frame()
    end
    for _, key in ipairs({ "SetHeight", "SetWordWrap", "SetJustifyH", "SetAutoFocus", "SetMaxLetters" }) do
        f[key] = function() end
    end
    return f
end
function CreateFrame(_, name, parent)
    return frame(name, parent)
end
UIParent = frame("UIParent")
AnchorTarget = frame("AnchorTarget", UIParent)
local library
LibStub = setmetatable({
    NewLibrary = function()
        library = {}
        return library
    end,
}, {
    __call = function()
        return library
    end,
})
Enum = { EditModeLayoutType = { Preset = 0, Account = 1 } }
local saved = {
    activeLayout = 2,
    layouts = {
        {
            layoutType = 1,
            layoutName = "Custom",
            systems = {
                {
                    system = 1,
                    systemIndex = 1,
                    anchorInfo = {
                        point = "TOPLEFT",
                        relativeTo = "UIParent",
                        relativePoint = "TOPLEFT",
                        offsetX = 120,
                        offsetY = -90,
                    },
                },
            },
        },
    },
}
local draft = copy(saved.layouts[1])
local combat, preset, enabled = false, false, true
local saves, loads = 0, 0
function InCombatLockdown()
    return combat
end
C_EditMode = {
    GetLayouts = function()
        loads = loads + 1
        return copy(saved)
    end,
    SaveLayouts = function()
        saves = saves + 1
    end,
}
EditModePresetLayoutManager = {
    GetCopyOfPresetLayouts = function()
        return { { layoutType = 0, systems = {} } }
    end,
}
function tAppendAll(target, source)
    for _, item in ipairs(source) do
        table.insert(target, item)
    end
end
EditModeManagerFrame = {
    accountSettings = {},
    ReconcileWithModern = function()
        return false
    end,
}
function EditModeManagerFrame:GetActiveLayoutSystemInfo()
    return draft.systems[1]
end
function EditModeManagerFrame:IsActiveLayoutPreset()
    return preset
end
function EditModeManagerFrame:SetHasActiveChanges(value)
    self.dirty = value
end
EditModeSystemSettingsDialog = { UpdateDialog = function() end }
assert(loadfile("Seamless/lib/LibEditModeOverride/LibEditModeOverride.lua"))()
local player = frame("PlayerFrame", UIParent)
player.system, player.systemIndex = 1, 1
player.systemInfo = draft.systems[1]
player.savedSystemInfo = copy(player.systemInfo)
function player:ClearFrameSnap()
    self.snapCleared = true
end
function player:ApplySystemAnchor()
    local a = self.systemInfo.anchorInfo
    self:SetPoint(a.point, _G[a.relativeTo], a.relativePoint, a.offsetX / 0.75, a.offsetY / 0.75)
end
function player:SetHasActiveChanges(value)
    self.dirty = value
end
local selected = player
local app = {
    db = { profile = { blizzardEditMode = { frames = { player = { addPosition = true } } } } },
    blizzardEditMode = {},
}
function app.blizzardEditMode:GetSelectedFrame()
    if enabled then
        return selected, { key = "player" }
    end
end
assert(loadfile("SeamlessUI/src/features/blizzardposition.lua"))("SeamlessUI", app)
local position = app.blizzardPosition
local values = position:Read(player)
assert(values.offsetX == 120 and values.relativeTo == "UIParent")
values.offsetX = -42.5
values.offsetY = 13.25
values.point, values.relativePoint, values.relativeTo = "BOTTOM", "CENTER", "AnchorTarget"
local oldBaseline = copy(player.savedSystemInfo)
draft.systems[1].pendingOtherSetting = 123
assert(position:Apply(player, values))
assert(library:AreLayoutsLoaded() and loads == 1 and saves == 0)
assert(
    draft.systems[1].pendingOtherSetting == 123
        and player.savedSystemInfo.anchorInfo.offsetX == oldBaseline.anchorInfo.offsetX
)
assert(player.points[1][4] == -42.5 / 0.75 and player.dirty and EditModeManagerFrame.dirty)
assert(position:Read(player).offsetY == 13.25 and not draft.systems[1].isInDefaultPosition)
local function reject(changes)
    local value = position:Read(player)
    for key, item in pairs(changes) do
        value[key] = item
    end
    local before = position:Read(player)
    assert(not position:Apply(player, value))
    assert(position:Read(player).offsetX == before.offsetX and saves == 0)
end
reject({ offsetX = "nonsense" })
reject({ offsetY = math.huge })
reject({ offsetX = 0 / 0 })
reject({ point = "invalid" })
reject({ relativeTo = "MissingFrame" })
PlayerFrame = player
reject({ relativeTo = "PlayerFrame" })
ChildFrame = frame("ChildFrame", player)
reject({ relativeTo = "ChildFrame" })
AnchorTarget:SetPoint("CENTER", player, "CENTER", 0, 0)
reject({ relativeTo = "AnchorTarget" })
AnchorTarget:ClearAllPoints()
combat = true
reject({ offsetX = 99 })
combat = false
preset = true
reject({ offsetX = 99 })
preset = false
enabled = false
reject({ offsetX = 99 })
enabled = true
app.db.profile.blizzardEditMode.frames.player.addPosition = false
reject({ offsetX = 99 })
app.db.profile.blizzardEditMode.frames.player.addPosition = true
local view = position:Create(frame())
view:Refresh(player)
assert(view.controls.offsetX:GetText() == "-42.5")
local menu = { entries = {} }
function menu:CreateRadio(text, get, set)
    self.entries[text] = { get = get, set = set }
end
view.controls.point.menu(nil, menu)
assert(menu.entries.BOTTOM.get())
menu.entries.TOPRIGHT.set()
assert(position:Read(player).point == "TOPRIGHT")
local parentMenu = { entries = {}, CreateRadio = menu.CreateRadio }
view.controls.relativePoint.menu(nil, parentMenu)
parentMenu.entries.BOTTOMLEFT.set()
assert(position:Read(player).relativePoint == "BOTTOMLEFT" and position:Read(player).point == "TOPRIGHT")
-- Simulate dragging elsewhere in Edit Mode while typing: refresh other fields,
-- but preserve typed text and use the latest untouched anchor fields on commit.
view.controls.offsetX:SetFocus()
view.controls.offsetX:SetText("-17.125")
draft.systems[1].anchorInfo.offsetY = 150
view:Refresh(player)
assert(view.controls.offsetX:GetText() == "-17.125" and view.controls.offsetY:GetText() == "150")
view.controls.offsetX:ClearFocus()
assert(position:Read(player).offsetX == -17.125 and position:Read(player).offsetY == 150 and saves == 0)
view.controls.offsetX:SetFocus()
view.controls.offsetX:SetText("junk")
view.controls.offsetX.scripts.OnEscapePressed(view.controls.offsetX)
assert(not view.error and position:Read(player).offsetX == -17.125)
-- An old field callback cannot apply to the newly selected frame.
view.controls.offsetX:SetFocus()
view.controls.offsetX:SetText("500")
selected = frame("OtherFrame")
view.controls.offsetX:ClearFocus()
assert(position:Read(player).offsetX == -17.125)
selected = player
preset = true
view:Refresh(player)
assert(not view.controls.offsetX.enabled)
preset = false
-- The live draft can be reverted without the override cache having saved anything.
draft = copy(saved.layouts[1])
player.systemInfo = draft.systems[1]
view:Refresh(player)
assert(view.controls.offsetX:GetText() == "120" and saves == 0)
print("Blizzard position controls OK (real override library, validation, draft preservation, scale, focus and Revert)")
