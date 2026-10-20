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
    function f:SetOnClickHandler(callback)
        self.click = callback
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
    function f:SetWidth(value)
        self.width = value
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
        if self.scripts.OnEditFocusGained then
            self.scripts.OnEditFocusGained(self)
        end
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
    function f:Show()
        self.shown = true
    end
    function f:Hide()
        self.shown = false
    end
    function f:SetShown(value)
        self.shown = value
    end
    function f:GetWidth()
        return 1920
    end
    function f:GetHeight()
        return 1080
    end
    for _, key in ipairs({
        "SetHeight",
        "SetSize",
        "SetWordWrap",
        "SetJustifyH",
        "SetAutoFocus",
        "SetMaxLetters",
        "SetCursorPosition",
        "SetTextColor",
    }) do
        f[key] = function() end
    end
    return f
end
function CreateFrame(_, name, parent, template)
    local f = frame(name, parent)
    f.template = template
    if template == "EditModeSettingSliderTemplate" then
        f.Label = frame()
        f.Slider = frame()
        f.Slider.MinText, f.Slider.MaxText, f.Slider.RightText = frame(), frame(), frame()
        function f.Slider:Init(value, min, max, steps)
            self.min, self.max, self.steps = min, max, steps
            self:SetValue(value)
        end
        function f.Slider:SetValue(value)
            self.value = value
            if self.callback then
                self.callback(self.owner, value)
            end
        end
        f.cbrHandles = {
            Unregister = function(self)
                self.cleared = true
            end,
        }
        function f.cbrHandles:RegisterCallback(slider, _, callback, owner)
            assert(self.cleared, "Native settings callbacks must be removed")
            slider.callback, slider.owner = callback, owner
        end
    end
    return f
end
WHITE_FONT_COLOR = {
    GetRGB = function()
        return 1, 1, 1
    end,
}
DISABLED_FONT_COLOR = WHITE_FONT_COLOR
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = "OnValueChanged" }, Label = { Right = 1 } }
function CreateMinimalSliderFormatter(_, formatter)
    return formatter
end
UIParent = frame("UIParent")
AnchorTarget = frame("AnchorTarget", UIParent)
FocusFrame, TargetFrame, Minimap =
    frame("FocusFrame", UIParent), frame("TargetFrame", UIParent), frame("Minimap", UIParent)
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
dofile("src/tests/locale-support.lua")
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
local otherFrameDirty = false
function EditModeManagerFrame:CheckForSystemActiveChanges()
    self.dirty = player.dirty or otherFrameDirty
end
local selected = player
local app = {
    db = { profile = { blizzardEditMode = { frames = { player = { addPosition = true } } } } },
    blizzardEditMode = {},
    core = {},
}
local picker
function app.core:StartEditModeAnchorPicker(spec)
    picker = spec
    return true
end
local extraAnchorTargets = {}
function app.blizzardEditMode:GetAnchorTargets()
    return extraAnchorTargets
end
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
player.isLocked = true
reject({ offsetX = 99 })
player.isLocked = false
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
local x, y = view.controls.offsetX, view.controls.offsetY
assert(x.template == "EditModeSettingSliderTemplate" and y.template == "EditModeSettingSliderTemplate")
assert(x.Slider.value == -42.5 and x.Slider.min == -1920 and x.Slider.max == 1920)
assert(x.Slider.steps == 3840)
local menu = { entries = {} }
function menu:SetScrollMode(height)
    self.scrollHeight = height
end
function menu:CreateRadio(text, get, set)
    local entry = { get = get, set = set }
    function entry:SetEnabled(value)
        self.enabled = value
    end
    self.entries[text] = entry
    self.order = self.order or {}
    table.insert(self.order, text)
    return entry
end
view.controls.point.Dropdown.menu(nil, menu)
assert(menu.entries.Bottom.get())
menu.entries["Top right"].set()
assert(position:Read(player).point == "TOPRIGHT")
local parentMenu = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
view.controls.relativePoint.Dropdown.menu(nil, parentMenu)
parentMenu.entries["Bottom left"].set()
assert(position:Read(player).relativePoint == "BOTTOMLEFT" and position:Read(player).point == "TOPRIGHT")
local frameMenu = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
view.controls.relativeTo.Dropdown.menu(nil, frameMenu)
assert(table.concat(frameMenu.order, ",") == "UIParent,Focus frame,Minimap,Player frame,Target frame")
assert(not frameMenu.entries["Player frame"].enabled and frameMenu.entries.Minimap.enabled)
assert(frameMenu.entries.AnchorTarget == nil)
frameMenu.entries["Focus frame"].set()
assert(position:Read(player).relativeTo == "FocusFrame")
assert(view.controls.relativeTo.Dropdown.text == "Focus frame")
Minimap:SetPoint("CENTER", player, "CENTER", 0, 0)
view.controls.relativeTo.Dropdown.menu(nil, frameMenu)
assert(not frameMenu.entries.Minimap.enabled)
Minimap:ClearAllPoints()
TargetFrame = nil
view.controls.relativeTo.Dropdown.menu(nil, frameMenu)
assert(not frameMenu.entries["Target frame"].enabled)
TargetFrame = frame("TargetFrame", UIParent)
-- Newly registered extension systems are also anchor choices, with clear labels
-- instead of exposing the sometimes unusual underlying frame names.
MultiBar5 = frame("MultiBar5", UIParent)
extraAnchorTargets =
    { { value = "MultiBar5", text = "Action bar 6" }, { value = "PlayerFrame", text = "Player frame" } }
local expanded = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
view.controls.relativeTo.Dropdown.menu(nil, expanded)
assert(table.concat(expanded.order, ",") == "UIParent,Action bar 6,Focus frame,Minimap,Player frame,Target frame")
assert(expanded.scrollHeight == 400)
expanded.entries["Action bar 6"].set()
assert(position:Read(player).relativeTo == "MultiBar5")
MultiBar5:SetPoint("CENTER", player, "CENTER", 0, 0)
view.controls.relativeTo.Dropdown.menu(nil, expanded)
assert(not expanded.entries["Action bar 6"].enabled)
MultiBar5:ClearAllPoints()
expanded.entries.UIParent.set()
extraAnchorTargets = {}
-- Steppers and slider dragging use the same override path as typed values.
x.Slider:SetValue(-41.5)
assert(position:Read(player).offsetX == -41.5)
-- Simulate dragging elsewhere in Edit Mode while typing: refresh other fields,
-- but preserve typed text and use the latest untouched anchor fields on commit.
x.EditBox:SetFocus()
x.EditBox:SetText("-17.125")
draft.systems[1].anchorInfo.offsetY = 150
view:Refresh(player)
assert(x.EditBox:GetText() == "-17.125" and y.Slider.value == 150)
x.EditBox.scripts.OnEnterPressed(x.EditBox)
assert(position:Read(player).offsetX == -17.125 and position:Read(player).offsetY == 150 and saves == 0)
x.EditBox:SetFocus()
x.EditBox:SetText("junk")
x.EditBox.scripts.OnEscapePressed(x.EditBox)
assert(not view.error and position:Read(player).offsetX == -17.125)
-- Numeric input can exceed the screen-sized slider range without being clamped.
x.EditBox:SetFocus()
x.EditBox:SetText("-5000.25")
x.EditBox.scripts.OnEnterPressed(x.EditBox)
assert(position:Read(player).offsetX == -5000.25 and x.Slider.min == -5001)
x.EditBox:SetFocus()
x.EditBox:SetText("-17.125")
x.EditBox.scripts.OnEnterPressed(x.EditBox)
-- An old field callback cannot apply to the newly selected frame.
x.EditBox:SetFocus()
x.EditBox:SetText("500")
selected = frame("OtherFrame")
x.EditBox.scripts.OnEnterPressed(x.EditBox)
frameMenu.entries["Focus frame"].set()
assert(position:Read(player).offsetX == -17.125)
selected = player
preset = true
view:Refresh(player)
assert(not x.Slider.enabled and not x.EditBox.shown)
preset = false
-- The live draft can be reverted without the override cache having saved anything.
draft = copy(saved.layouts[1])
player.systemInfo = draft.systems[1]
view:Refresh(player)
assert(x.Slider.value == 120 and saves == 0)
assert(view.RevertButton.template == "EditModeSystemSettingsDialogButtonTemplate")
assert(view.RevertButton.width == view:GetWidth() / 2)
assert(not view.RevertButton.enabled)
-- Detect watched fields changed by native dragging, and preserve unrelated data.
draft.systems[1].anchorInfo.offsetX = 350
draft.systems[1].pendingOtherSetting = 123
player.dirty = true
view:Refresh(player)
assert(view.RevertButton.enabled)
view.RevertButton.click()
assert(position:Read(player).offsetX == 120 and not view.RevertButton.enabled)
assert(draft.systems[1].pendingOtherSetting == 123 and player.dirty and EditModeManagerFrame.dirty)
draft.systems[1].pendingOtherSetting = nil
otherFrameDirty = true
local moved = position:Read(player)
moved.offsetY = 50
assert(position:Apply(player, moved))
view:Refresh(player)
view.RevertButton.click()
assert(not player.dirty and EditModeManagerFrame.dirty and not view.RevertButton.enabled)
otherFrameDirty = false
-- Restoring position alone clears the global dirty state when nothing else differs.
moved = position:Read(player)
moved.offsetX = 500
assert(position:Apply(player, moved))
view:Refresh(player)
view.RevertButton.click()
assert(not player.dirty and not EditModeManagerFrame.dirty and not view.RevertButton.enabled)
-- A new saved baseline replaces the before version, rather than restoring defaults.
draft.systems[1].anchorInfo.offsetX = 777
player.savedSystemInfo = copy(draft.systems[1])
view:Refresh(player)
assert(not view.RevertButton.enabled)
moved = position:Read(player)
moved.offsetX = 800
assert(position:Apply(player, moved))
view:Refresh(player)
view.RevertButton.click()
assert(position:Read(player).offsetX == 777)
-- Follow every point through multiple frames, including a secondary anchor.
AnchorTarget:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
AnchorTarget.points[2] = { "TOP", player, "BOTTOM", 0, 0 }
FocusFrame:SetPoint("TOP", AnchorTarget, "BOTTOM", 0, 0)
moved = position:Read(player)
moved.relativeTo = "FocusFrame"
assert(not position:Apply(player, moved))
AnchorTarget.points[2] = nil
-- Followers remain attached when their target moves to a safe anchor.
FocusFrame:SetPoint("TOP", player, "BOTTOM", 0, 0)
moved = position:Read(player)
moved.offsetX = 820
assert(position:Apply(player, moved))
assert(FocusFrame.points[1][2] == player)
FocusFrame:ClearAllPoints()
-- Revert validates old targets again: relationships may have changed since edit.
player.savedSystemInfo = copy(draft.systems[1])
player.savedSystemInfo.anchorInfo.relativeTo = "TargetFrame"
TargetFrame:SetPoint("TOP", player, "BOTTOM", 0, 0)
view:Refresh(player)
assert(view.RevertButton.enabled)
view.RevertButton.click()
assert(view.error and position:Read(player).relativeTo == "UIParent" and view.RevertButton.enabled)
TargetFrame:ClearAllPoints()
view.RevertButton.click()
assert(not view.error and position:Read(player).relativeTo == "TargetFrame" and not view.RevertButton.enabled)
-- Restore the secondary anchor and default-position metadata as one position state.
player.savedSystemInfo.anchorInfo2 =
    { point = "BOTTOM", relativeTo = "Minimap", relativePoint = "TOP", offsetX = 0, offsetY = 10 }
player.savedSystemInfo.isInDefaultPosition = true
Minimap:SetPoint("CENTER", player, "CENTER", 0, 0)
view:Refresh(player)
view.RevertButton.click()
assert(view.error and draft.systems[1].anchorInfo2 == nil)
Minimap:ClearAllPoints()
view.RevertButton.click()
assert(draft.systems[1].anchorInfo2.relativeTo == "Minimap" and draft.systems[1].isInDefaultPosition)
assert(not view.RevertButton.enabled and not player.dirty and saves == 0)
-- Read-only/disabled windows cannot revert, even through a stale button callback.
draft.systems[1].anchorInfo.offsetX = 999
preset = true
view:Refresh(player)
assert(not view.RevertButton.enabled)
view.RevertButton.click()
assert(position:Read(player).offsetX == 999)
preset = false
-- A translated catalogue changes labels/order, but never the frame/anchor IDs.
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
L["Focus frame"], L["Target frame"] = "Z Focus", "A Target"
L["Anchor"], L["Top right"], L["Revert changes"] = "Translated anchor", "Translated top right", "Translated revert"
L["X and Y must be finite numbers."] = "Translated numeric error"
assert(loadfile("SeamlessUI/src/features/blizzardposition.lua"))("SeamlessUI", app)
local localizedPosition = app.blizzardPosition
local localizedView = localizedPosition:Create(frame())
localizedView:Refresh(player)
assert(localizedView.controls.point.Label.text == "Translated anchor")
assert(localizedView.RevertButton.text == "Translated revert")
local localizedMenu = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
localizedView.controls.relativeTo.Dropdown.menu(nil, localizedMenu)
assert(table.concat(localizedMenu.order, ",") == "UIParent,A Target,Minimap,Player frame,Z Focus")
local localizedAnchors = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
localizedView.controls.point.Dropdown.menu(nil, localizedAnchors)
localizedAnchors.entries["Translated top right"].set()
assert(localizedPosition:Read(player).point == "TOPRIGHT")
local invalid = localizedPosition:Read(player)
invalid.offsetX = "invalid"
local ok, err = localizedPosition:Apply(player, invalid)
assert(not ok and err == "Translated numeric error")
-- A managed frame in default position ignores its placeholder layout anchor;
-- the live anchor through an unnamed/managed container resolves to PlayerFrame.
local function rect(f, left, top, width, height, scale)
    function f:GetLeft()
        return left
    end
    function f:GetRight()
        return left + width
    end
    function f:GetTop()
        return top
    end
    function f:GetBottom()
        return top - height
    end
    function f:GetEffectiveScale()
        return scale
    end
end
rect(player, 100, 800, 200, 80, 1)
local container = frame("PlayerBottomManagedFrameContainer", player)
container.AddManagedFrame = function() end
container:SetPoint("TOP", player, "BOTTOM", 30, 25)
local layoutChild = frame(nil, container)
layoutChild:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
local pet = frame("PetFrame", layoutChild)
pet.system, pet.systemIndex = 1, 2
pet.systemInfo = {
    isInDefaultPosition = true,
    anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
}
function pet:IsInDefaultPosition()
    return self.systemInfo.isInDefaultPosition
end
function pet:GetScale()
    return 0.5
end
rect(pet, 260, 1520, 120, 50, 0.5)
pet:SetPoint("TOPLEFT", layoutChild, "TOPLEFT", 15, 0)
local petLayout = EditModeManagerFrame.GetActiveLayoutSystemInfo
function EditModeManagerFrame:GetActiveLayoutSystemInfo(_, systemIndex)
    return systemIndex == 2 and pet.systemInfo or petLayout(self)
end
local live = position:Read(pet)
-- Screen offset (130 - 100, 760 - 800) at effective scale 0.5, times frame scale 0.5.
assert(live.relativeTo == "PlayerFrame" and live.point == "TOPLEFT" and live.relativePoint == "TOPLEFT")
assert(live.offsetX == 30 and live.offsetY == -40)
pet.systemInfo.isInDefaultPosition = false
assert(position:Read(pet).relativeTo == "UIParent")
EditModeManagerFrame.GetActiveLayoutSystemInfo = petLayout

-- "Anchor to a frame" offers the dropdown's frames, minus UIParent and frames that depend on
-- the selected one, and applies the picked anchor to the live draft.
selected = player
view.error = nil
view:Refresh(player)
assert(view.AnchorButton.template == "EditModeSystemSettingsDialogButtonTemplate" and view.AnchorButton.enabled)
view.AnchorButton.click()
assert(picker and picker.frame == player)
local offered = {}
for _, entry in ipairs(picker.targets()) do
    assert(entry.frame == _G[entry.value])
    offered[entry.value] = true
end
assert(offered.TargetFrame and not offered.UIParent and not offered.PetFrame, "UIParent and dependants are excluded")
picker.apply("TOPLEFT", "TargetFrame", "BOTTOMRIGHT", 5, -5)
local picked = position:Read(player)
assert(picked.point == "TOPLEFT" and picked.relativeTo == "TargetFrame" and picked.relativePoint == "BOTTOMRIGHT")
assert(picked.offsetX == 5 and picked.offsetY == -5 and not view.error)
-- A pick that lands after the selection changed is dropped.
view.AnchorButton.click()
selected = frame("OtherFrame")
picker.apply("LEFT", "TargetFrame", "RIGHT", 5, 0)
assert(position:Read(player).point == "TOPLEFT")
print("Blizzard position controls OK (real override library, validation, draft preservation, scale, focus and Revert)")
