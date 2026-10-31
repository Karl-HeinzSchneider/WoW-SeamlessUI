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
    function f:CreateTexture()
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
    function f:GetStringHeight()
        return 12
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
        "HookScript",
        "SetColorTexture",
    }) do
        f[key] = function() end
    end
    return f
end
local createdFrames = {}
function CreateFrame(_, name, parent, template)
    local f = frame(name, parent)
    f.template = template
    createdFrames[#createdFrames + 1] = f
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
function EditModeManagerFrame:IsEditModeActive()
    return true
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
local selectedSpec = { key = "player" }
function app.blizzardEditMode:GetSelectedFrame()
    if enabled then
        return selected, selectedSpec
    end
end
local collapsed = {}
function app.core:GetEditModePositionSectionKey()
    return "settings:position"
end
function app.core:IsEditModeSectionCollapsed(key)
    return collapsed[key] == true
end
function app.core:SetEditModeSectionCollapsed(key, value)
    collapsed[key] = value
end
function app.core:CreateEditModeHeader(parent)
    local header = frame(nil, parent)
    header.SetHeaderText, header.UpdateCollapsedState = function() end, function() end
    return header
end
local coreMessages = 0
function app.core:SendMessage()
    coreMessages = coreMessages + 1
end
local coreApp = { addon = app.core }
assert(loadfile("Seamless/src/core/frameposition.lua"))("Seamless", coreApp)
assert(loadfile("Seamless/src/core/systemoptions.lua"))("Seamless", coreApp)
-- Core's real row renderer and Position section draw the controls.
assert(loadfile("Seamless/src/core/editmoderows.lua"))("Seamless", coreApp)
assert(loadfile("Seamless/src/core/editmodeposition.lua"))("Seamless", coreApp)
assert(loadfile("SeamlessUI/src/features/blizzardposition.lua"))("SeamlessUI", app)
local position = app.blizzardPosition
-- The Position section laid out like the extended window does, with each row by its key. A click
-- or commit lays it out again, like the window's redraw.
local function createView(service)
    local view = { parent = frame(), controls = {} }
    function view:Refresh(system)
        self.system = system
        self.section = service:GetSection(system)
        app.core:LayoutEditModeSections(
            self.parent,
            {
                self.section,
                self.section.sizeSection,
                { id = "explicit-buttons", options = { self.section.revertButton } },
            },
            0,
            false,
            function()
                self:Refresh(self.system)
            end
        )
        for _, created in ipairs(createdFrames) do
            if created.parent == self.parent and created.option then
                self.controls[created.option.key] = created
            end
        end
        self.RevertButton = self.controls.revert and self.controls.revert.Button
        self.AnchorButton = self.controls.quickAnchor and self.controls.quickAnchor.Button
    end
    return view
end
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
local view = createView(position)
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
assert(menu.entries.BOTTOM.get())
menu.entries.TOPRIGHT.set()
assert(position:Read(player).point == "TOPRIGHT")
local parentMenu = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
view.controls.relativePoint.Dropdown.menu(nil, parentMenu)
parentMenu.entries.BOTTOMLEFT.set()
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
assert(math.abs(position:Read(player).offsetX + 41.5) <= 0.5, "slider steps snap to whole pixels")
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
assert(not view.section.error and position:Read(player).offsetX == -17.125)
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
assert(view.RevertButton.width == view.controls.revert:GetWidth() / 2)
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
assert(view.section.error and position:Read(player).relativeTo == "UIParent" and view.RevertButton.enabled)
TargetFrame:ClearAllPoints()
view.RevertButton.click()
assert(not view.section.error and position:Read(player).relativeTo == "TargetFrame" and not view.RevertButton.enabled)
-- Restore the secondary anchor and default-position metadata as one position state.
player.savedSystemInfo.anchorInfo2 =
    { point = "BOTTOM", relativeTo = "Minimap", relativePoint = "TOP", offsetX = 0, offsetY = 10 }
player.savedSystemInfo.isInDefaultPosition = true
Minimap:SetPoint("CENTER", player, "CENTER", 0, 0)
view:Refresh(player)
view.RevertButton.click()
assert(view.section.error and draft.systems[1].anchorInfo2 == nil)
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
-- A translated catalogue changes labels/order, but never the frame IDs or native anchor names.
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
L["Focus frame"], L["Target frame"] = "Z Focus", "A Target"
L["Anchor"], L["Revert changes"] = "Translated anchor", "Translated revert"
L["X and Y must be finite numbers."] = "Translated numeric error"
local coreApp = { addon = app.core }
assert(loadfile("Seamless/src/core/frameposition.lua"))("Seamless", coreApp)
assert(loadfile("Seamless/src/core/editmodeposition.lua"))("Seamless", coreApp)
assert(loadfile("SeamlessUI/src/features/blizzardposition.lua"))("SeamlessUI", app)
local localizedPosition = app.blizzardPosition
local localizedView = createView(localizedPosition)
localizedView:Refresh(player)
assert(localizedView.controls.point.Label.text == "Translated anchor")
assert(localizedView.RevertButton.text == "Translated revert")
local localizedMenu = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
localizedView.controls.relativeTo.Dropdown.menu(nil, localizedMenu)
assert(table.concat(localizedMenu.order, ",") == "UIParent,A Target,Minimap,Player frame,Z Focus")
local localizedAnchors = { entries = {}, CreateRadio = menu.CreateRadio, SetScrollMode = menu.SetScrollMode }
localizedView.controls.point.Dropdown.menu(nil, localizedAnchors)
localizedAnchors.entries.TOPRIGHT.set()
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

-- "Quick anchor to frame" offers the dropdown's frames, minus UIParent and frames that depend on
-- the selected one, and applies the picked anchor to the live draft.
selected = player
view.section.error = nil
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
assert(picked.offsetX == 5 and picked.offsetY == -5 and not view.section.error)
-- The window's poll picks the pick up in place, without laying the rows out again.
local anchorFrameRow = view.controls.relativeTo
anchorFrameRow.points = {}
assert(not app.core:RefreshEditModeSections(view.parent))
assert(anchorFrameRow.Dropdown.text == "Target frame" and #anchorFrameRow.points == 0)
-- A refusal message adds a row, so the poll asks for a new layout.
view.section.error = "Refused"
assert(app.core:RefreshEditModeSections(view.parent))
view:Refresh(player)
assert(view.controls.error.Text.text == "Refused" and not app.core:RefreshEditModeSections(view.parent))
view.section.error = nil
view:Refresh(player)
-- A pick that lands after the selection changed is dropped.
view.AnchorButton.click()
selected = frame("OtherFrame")
picker.apply("LEFT", "TargetFrame", "RIGHT", 5, 0)
assert(position:Read(player).point == "TOPLEFT")
-- Size is separate from Position and displays the existing scale, always greyed out.
selected = player
view.section.error = nil
local scaleRow = view.controls.scale
assert(scaleRow.template == "EditModeSettingSliderTemplate" and scaleRow.Label.text == "Scale")
assert(view.section.name == "Position" and view.section.sizeSection.name == "Size")
for _, row in ipairs(view.section.options) do
    assert(row.key ~= "scale", "Position contains no size controls")
end
view:Refresh(player)
assert(not scaleRow.Slider.enabled and not scaleRow.EditBox.shown and scaleRow.Slider.value == 1)
assert(scaleRow.Slider.min == 0.5 and scaleRow.Slider.max == 2)
-- A native size setting (the unit frames' Frame Size) is not rerouted to Scale: still 1, greyed out.
local SIZE = 16
Enum.EditModeUnitFrameSetting = { FrameSize = SIZE }
selectedSpec.system = "UnitFrame"
player.settingDisplayInfoMap = { [SIZE] = { minValue = 100, maxValue = 200, stepSize = 5 } }
function player:HasSetting(setting)
    return setting == SIZE
end
function player:GetSettingValue()
    return 120
end
view:Refresh(player)
assert(not scaleRow.Slider.enabled and scaleRow.Slider.value == 1 and scaleRow.Slider.max == 2)
scaleRow.Slider:SetValue(1.35)
assert(saves == 0, "the placeholder writes nothing")
player.settingDisplayInfoMap, player.HasSetting, player.GetSettingValue = nil, nil, nil
selectedSpec.system = nil
assert(app.core.RegisterEditModeSystemScale == nil and app.core.GetNativeSettingScale == nil)
print("Blizzard position controls OK (real override library, validation, draft preservation, scale, focus and Revert)")

-- The config view uses the shared core service without requiring SeamlessUI or a selection.
assert(loadfile("Seamless/src/config/position.lua"))("Seamless", coreApp)
local native = app.core:GetFramePositionService()
local group, sizeGroup = app.core:GetNativePositionOptions(function()
    return player
end)
assert(group.name == "Position" and group.type == "group" and group.inline)
assert(group.layoutStored and not group.editMode, "native layout groups keep tooltip metadata without a badge")
local config = group.args
assert(config.point.get() == position:Read(player).point)
assert(config.relativePoint.get() == position:Read(player).relativePoint)
assert(config.relativeTo.get() == position:Read(player).relativeTo)
assert(config.x.get() == 5 and config.y.get() == -5)
assert(not config.x.disabled(), "config editing needs no selected Edit Mode extension")
local beforeConfigSave = saves
config.x.set(nil, 42)
assert(position:Read(player).offsetX == 42 and saves == beforeConfigSave, "active Edit Mode keeps edits in its draft")
assert(config.y.get() == -5, "editing one field preserves the other four")
local nativeValues = native:Read(player)
nativeValues.offsetY = -28
assert(native:Apply(player, nativeValues))
assert(config.y.get() == -28, "config getters read later native edits")
combat = true
config.x.set(nil, 999)
assert(config.x.disabled() and config.x.get() == 42)
combat = false
preset = true
assert(config.x.disabled())
config.x.set(nil, 999)
assert(config.x.get() == 42)
preset = false
local choices = config.relativeTo.values()
assert(choices.UIParent and not choices.PlayerFrame and not choices.PetFrame, "exclude self and dependent targets")
assert(config.relativeTo.sorting()[1] == "UIParent")
local beforeCycle = native:Read(player)
local cyclic = copy(beforeCycle)
cyclic.relativeTo = "PetFrame"
assert(not native:Apply(player, cyclic))
assert(native:Read(player).relativeTo == beforeCycle.relativeTo)
-- Outside Edit Mode, persist through the live manager, preserving other system data.
function EditModeManagerFrame:IsEditModeActive()
    return false
end
local liveSaves = 0
function EditModeManagerFrame:SaveLayouts()
    liveSaves = liveSaves + 1
    assert(draft.systems[1].anchorInfo.offsetX == 73)
    assert(draft.systems[1].settings[1].value == 1234, "unrelated settings must survive")
    saved.layouts[1] = copy(draft)
    player.dirty = false
end
draft.systems[1].settings = { { setting = 7, value = 1234 } }
config.x.set(nil, 73)
assert(liveSaves == 1 and saved.layouts[1].systems[1].anchorInfo.offsetX == 73)
assert(player.savedSystemInfo.anchorInfo.offsetX == 73)
assert(config.x.get() == 73)
-- A new layout must be read on every access, rather than captured by the option factory.
draft = copy(draft)
draft.systems[1].anchorInfo.offsetX = -80
assert(config.x.get() == -80)
local missing = app.core:GetNativePositionOptions(function()
    return nil
end)
assert(missing.args.x.disabled() and missing.args.x.get() == 0)
print("Config position options OK (shared draft, native persistence, layout switches and combat guards)")

-- Scale is a dead placeholder: always disabled at 100%, writing nothing.
function player:GetScale()
    return 0.75
end
assert(config.scale == nil and sizeGroup.name == "Size")
local configScale = sizeGroup.args.scale
assert(configScale.disabled() and configScale.get() == 1 and configScale.default == nil)
configScale.set(nil, 1.2)
assert(player:GetScale() == 0.75)
local generic, genericSize = app.core:GetPositionOptions({
    get = function()
        return 0
    end,
    set = function()
        error("position setter used for scale")
    end,
    anchorFrames = {},
})
assert(genericSize.args.scale.disabled() and genericSize.args.scale.get() == 1)
assert(not generic.editMode, "profile-stored positions are not tagged")
genericSize.args.scale.set(nil, 1.2)
print("Dead position scale placeholder OK")

-- Defaults come from the preset layout, the same source as the native Reset To
-- Default Position button.
local warnings = {}
coreApp.logger = {
    warn = function(_, _, message)
        warnings[#warnings + 1] = message
    end,
}
local presetAnchor =
    { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 300, offsetY = 250 }
function EditModePresetLayoutManager:GetDefaultSystemAnchorInfo(system, systemIndex)
    assert(system == player.system and systemIndex == player.systemIndex)
    return copy(presetAnchor)
end
local FRAME_SIZE = 9
function EditModePresetLayoutManager:GetDefaultSettingForSystem(_, _, setting)
    return setting == FRAME_SIZE and 0 or nil
end
local frameSizeInfo = { minValue = 100, maxValue = 200, stepSize = 5 }
function frameSizeInfo:ConvertValueForDisplay(raw)
    return raw * self.stepSize + self.minValue
end
local frameSize, largerFrame = 120, true
player.settingDisplayInfoMap = { [FRAME_SIZE] = frameSizeInfo }
function player:HasSetting(setting)
    return setting == FRAME_SIZE
end
function player:ShouldShowSetting(setting)
    return setting == FRAME_SIZE and largerFrame
end
function player:GetSettingValue(setting)
    assert(setting == FRAME_SIZE)
    return frameSize
end
local inDefault = false
function player:IsInDefaultPosition()
    return inDefault
end
local settingSaves = 0
function EditModeManagerFrame:SaveLayouts()
    settingSaves = settingSaves + 1
end
function EditModeManagerFrame:OnSystemSettingChange(system, setting, value)
    assert(system == player and setting == FRAME_SIZE)
    frameSize = value
end

local defaultPosition, defaultSize = app.core:GetNativePositionOptions(function()
    return player
end)
local defaults = defaultPosition.args
assert(native:GetDefault(player).offsetX == 300 and native:GetDefault(player) ~= native:GetDefault(player))
assert(defaults.point.default() == "BOTTOMLEFT" and defaults.relativeTo.default() == "UIParent")
assert(defaults.x.default() == 300 and defaults.y.default() == 250, "offsets map to offsetX/offsetY")

-- The disabled Scale never reads or writes the native Frame Size setting.
local sizeScale = defaultSize.args.scale
assert(sizeScale.get() == 1 and sizeScale.disabled())
sizeScale.set(nil, 1.35)
assert(frameSize == 120 and settingSaves == 0, "disabled Size never saves the native setting")

-- Reset applies the preset anchor and marks the frame as in its default position.
assert(not defaults.reset.disabled() and defaults.reset.type == "execute")
defaults.reset.func()
local reset = draft.systems[1]
assert(reset.anchorInfo.point == "BOTTOMLEFT" and reset.anchorInfo.offsetX == 300 and reset.isInDefaultPosition)
inDefault = true
assert(defaults.reset.disabled(), "nothing to reset, like the native button")
inDefault = false
-- The Edit Mode Position rows show the same preset in their tooltips.
local rowDefaults = {}
for _, row in ipairs(position:GetSection(player).options) do
    rowDefaults[row.key] = row.default and row.default()
end
assert(rowDefaults.point == "BOTTOMLEFT" and rowDefaults.relativePoint == "BOTTOM")
assert(rowDefaults.relativeTo == "UIParent" and rowDefaults.offsetX == 300 and rowDefaults.offsetY == 250)
EditModePresetLayoutManager.GetDefaultSystemAnchorInfo = nil
assert(defaults.x.default() == nil, "clients without the preset API show Not applicable")
assert(not native:ResetToDefault(player) and #warnings == 0)
print("Native position defaults and Reset To Default OK")

-- The footer restores the whole native system even when its dirty flag was missed.
player.savedSystemInfo = copy(draft.systems[1])
draft.systems[1].pendingOtherSetting = 987
player.dirty = false
assert(native:HasSystemChanges(player) and not native:HasChanges(player))
local reverted = 0
function EditModeManagerFrame:RevertSystemChanges(system)
    reverted = reverted + 1
    draft.systems[1] = copy(system.savedSystemInfo)
end
assert(native:RevertSystem(player))
assert(reverted == 1 and not native:HasSystemChanges(player))
assert(not native:RevertSystem(player), "no native changes remain")
print("Native full-system Revert detects changes independently of dirty flags")
