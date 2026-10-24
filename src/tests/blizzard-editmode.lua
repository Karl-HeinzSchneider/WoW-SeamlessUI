-- Run from the repository root: lua src/tests/blizzard-editmode.lua
dofile("src/tests/locale-support.lua")
local module, panel
local combat, active = false, true
local function frame()
    local f = { shown = true }
    function f:Hide()
        self.shown = false
        self.hides = (self.hides or 0) + 1
    end
    function f:Show()
        self.shown = true
    end
    function f:IsShown()
        return self.shown
    end
    function f:GetFrameLevel()
        return 10
    end
    function f:SetText(text)
        self.text = text
    end
    function f:CreateFontString()
        return frame()
    end
    function f:SetHeight(height)
        self.height = height
    end
    function f:GetHeight()
        return self.height or 0
    end
    function f:SetChecked(checked)
        self.checked = checked
    end
    function f:SetEnabled(enabled)
        self.enabled = enabled
    end
    function f:Init(value)
        self.value = value
    end
    function f:SetupMenu(generator)
        -- Like the client, build the menu at once.
        self.generator = generator
        generator(self, { CreateRadio = function() end })
    end
    function f:HasFocus()
        return false
    end
    function f:SetDefaultText(text)
        self.defaultText = text
    end
    for _, method in ipairs({
        "SetFrameStrata",
        "EnableMouse",
        "SetPoint",
        "SetAllPoints",
        "SetFrameLevel",
        "SetWordWrap",
        "ClearAllPoints",
        "SetScript",
        "SetTextColor",
        "SetWidth",
        "SetJustifyH",
        "SetSize",
        "SetPropagateMouseMotion",
        "GenerateMenu",
        "SetAutoFocus",
        "SetMaxLetters",
        "SetCursorPosition",
        "SetText",
        "ClearFocus",
        "SetShown",
    }) do
        f[method] = function() end
    end
    return f
end
local created = {}
function CreateFrame(_, name, parent, template)
    local f = frame()
    if template == "EditModeSettingCheckboxTemplate" then
        f.Button, f.Label = frame(), frame()
    elseif template == "EditModeSettingSliderTemplate" then
        f.Label, f.Slider = frame(), frame()
        f.Slider.MinText, f.Slider.MaxText = frame(), frame()
        f.cbrHandles = {
            Unregister = function() end,
            RegisterCallback = function(_, _, _, callback)
                f.onValueChanged = callback
            end,
        }
    end
    if template then
        created[template] = f
    end
    return f
end
WHITE_FONT_COLOR, DISABLED_FONT_COLOR = { GetRGB = function() end }, { GetRGB = function() end }
MinimalSliderWithSteppersMixin = { Event = { OnValueChanged = 1 }, Label = { Right = 1 } }
function CreateMinimalSliderFormatter() end
function PlaySound() end
SOUNDKIT = {}
UIParent = {}
Enum = {
    EditModeSystem = { UnitFrame = 1 },
    EditModeUnitFrameSystemIndices = { Player = 1, Target = 2, Pet = 3, Focus = 4 },
}
function InCombatLockdown()
    return combat
end
function IsLoggedIn()
    return true
end
local app = { addon = {}, db = { profile = {} } }
-- header is the last one created; headers holds each by its text.
local collapsedSections, header, headers = {}, nil, {}
local beside, placedDialog
app.core = {
    SetEditModeDialogsBesideManager = function(_, enabled)
        beside = enabled
    end,
    PlaceBesideEditModeManager = function(_, dialog)
        placedDialog = dialog
        return true
    end,
    CreateEditModeHeader = function(_, _, onClick)
        header = frame()
        header.onClick = onClick
        function header:SetHeaderText(text)
            self.text = text
            headers[text] = self
        end
        function header:UpdateCollapsedState(collapsed)
            self.collapsed = collapsed
        end
        return header
    end,
    GetEditModePositionSectionKey = function()
        return "settings:position"
    end,
    IsEditModeSectionCollapsed = function(_, key)
        return collapsedSections[key] == true
    end,
    SetEditModeSectionCollapsed = function(_, key, collapsed)
        collapsedSections[key] = collapsed
    end,
}
-- Core's real registry for sections other addons add to a system; its message reaches the module.
function app.core:SendMessage(message)
    local handler = module.messages and module.messages[message]
    if handler then
        module[handler](module)
    end
end
assert(loadfile("Seamless/src/core/systemoptions.lua"))("Seamless", { addon = app.core })
-- Core's real row renderer draws the registered sections.
assert(loadfile("Seamless/src/core/editmoderows.lua"))("Seamless", { addon = app.core })
-- A stand-in for Core's settings window in its attached placement (editmode-dialog.lua tests the
-- real one): it lays the sections out with the renderer, and its height is theirs.
panel = frame()
panel.shown = false
function app.core:AttachEditModeSettingsWindow(spec)
    panel.spec = spec
    panel:Show()
    panel.height = self:LayoutEditModeSections(panel, spec.sections(), 0, false, spec.changed)
end
function app.core:DetachEditModeSettingsWindow()
    panel:Hide()
end
-- A stand-in Position section with one row; blizzard-position.lua tests the real one.
local positionSystem
app.blizzardPosition = {
    GetSection = function(_, system)
        positionSystem = system
        return {
            id = "position",
            name = "Position",
            key = "settings:position",
            options = {
                {
                    key = "anchored",
                    type = "toggle",
                    name = "Anchored",
                    get = function()
                        return true
                    end,
                    set = function() end,
                },
            },
        }
    end,
}
local function positionShown()
    return headers.Position ~= nil and headers.Position.shown
end
assert(loadfile("SeamlessUI/src/core/db.lua"))("SeamlessUI", app)
app.db.profile = app.dbDefaults.profile
function app.addon:NewModule()
    module = { hooks = {}, events = {} }
    function module:SetEnabledState(value)
        self.enabled = value
    end
    function module:IsEnabled()
        return self.enabled
    end
    function module:Enable()
        if not self.enabled then
            self.enabled = true
            self:OnEnable()
        end
    end
    function module:Disable()
        if self.enabled then
            self.enabled = false
            self:OnDisable()
        end
    end
    function module:RegisterEvent(event, handler)
        self.events[event] = handler
    end
    function module:UnregisterAllEvents()
        self.events = {}
    end
    function module:RegisterMessage(message, handler)
        self.messages = self.messages or {}
        self.messages[message] = handler
    end
    function module:UnregisterAllMessages()
        self.messages = {}
    end
    function module:IsHooked(object, method)
        return self.hooks[object] and self.hooks[object][method]
    end
    function module:SecureHook(object, method, handler)
        self.hooks[object] = self.hooks[object] or {}
        self.hooks[object][method] = handler
    end
    module.SecureHookScript = module.SecureHook
    function module:UnhookAll()
        self.hooks = {}
    end
    return module
end
assert(loadfile("SeamlessUI/src/features/systemoptions.lua"))("SeamlessUI", app)
assert(loadfile("SeamlessUI/src/features/blizzardeditmode.lua"))("SeamlessUI", app)
module:OnProfileRefresh() -- Native UI not loaded yet.
assert(module.events.ADDON_LOADED and next(module.hooks) == nil)
EditModeSystemSettingsDialog = frame()
EditModeManagerFrame = frame()
function EditModeManagerFrame:IsEditModeActive()
    return active
end
module:InstallHooks()
assert(module:IsHooked(EditModeSystemSettingsDialog, "AttachToSystemFrame") == "OnDialogAttached")
assert(module:IsHooked(EditModeManagerFrame, "SelectSystem") == "RefreshPanel", "re-attach after LibEditMode")
-- Selecting a frame snaps the native dialog right of the Edit Mode window through Core (which
-- only re-anchors it), and Core's dialog for suite frames follows the same option.
do
    local dialog = EditModeSystemSettingsDialog
    assert(beside == true, "enabling the extensions turns it on for suite frames")
    module:OnDialogAttached()
    assert(placedDialog == dialog)
    placedDialog = nil
    local config = module:Options().args
    config.snapSettingsDialog.set(nil, false)
    assert(beside == false and not config.snapSettingsDialog.get())
    module:OnDialogAttached()
    assert(placedDialog == nil, "the option leaves the dialog where Blizzard or the player put it")
    config.snapSettingsDialog.set(nil, true)
    assert(beside == true)
    config.enabled.set(nil, false)
    assert(beside == false, "disabling the extensions restores Core's default")
    config.enabled.set(nil, true)
    assert(beside == true)
end
-- Simulate AceDB's per-entry wildcard defaults for newly introduced frame keys.
setmetatable(app.db.profile.blizzardEditMode.frames, {
    __index = function(t, key)
        local defaults = rawget(t, "*")
        local value =
            { enabled = defaults.enabled, addPosition = defaults.addPosition, addMoreOptions = defaults.addMoreOptions }
        rawset(t, key, value)
        return value
    end,
})
local config = module:Options().args
-- Position and more options are global; each frame only has its own Extend Edit Mode switch.
assert(config.addPosition.type == "toggle" and config.addMoreOptions.type == "toggle")
assert(config.addPosition.get() and config.addMoreOptions.get())
config.addPosition.set(nil, false)
assert(config.player.type == "toggle" and config.player.name == "Player frame - Extend Edit Mode")
assert(config.player.order > config.unitsHeading.order and config.player.order < config.barsHeading.order)
for _, key in ipairs({ "player", "target", "pet", "focus" }) do
    local toggle = config[key]
    local index = Enum.EditModeUnitFrameSystemIndices[key:sub(1, 1):upper() .. key:sub(2)]
    EditModeSystemSettingsDialog.attachedToSystem = { system = 1, systemIndex = index }
    module:RefreshPanel()
    assert(panel:IsShown() and toggle.get(), key)
    assert(not positionShown(), "Position stays off until the global switch is on")
    toggle.set(nil, false)
    assert(not panel:IsShown() and not toggle.get())
    toggle.set(nil, true)
    assert(panel:IsShown())
end
config.addPosition.set(nil, true)
config.addMoreOptions.set(nil, true)
assert(config.addPosition.get() and config.addMoreOptions.get())
config.enabled.set(nil, false)
assert(config.addPosition.disabled() and config.player.disabled())
config.enabled.set(nil, true)
assert(not config.addPosition.disabled() and not config.player.disabled())
-- The internal per-frame values still gate the global switch.
app.db.profile.blizzardEditMode.frames.focus.addPosition = false
module:RefreshPanel()
assert(not positionShown())
app.db.profile.blizzardEditMode.frames.focus.addPosition = true
module:RefreshPanel()
-- Add position appears as an expanded Position header that collapses like every other header.
local positionHeader, positionRow = headers.Position, created.EditModeSettingCheckboxTemplate
assert(positionShown() and not positionHeader.collapsed and positionRow.shown)
assert(positionSystem == EditModeSystemSettingsDialog.attachedToSystem)
-- Attached below the native dialog, titled after the frame.
assert(panel.spec.anchor == EditModeSystemSettingsDialog and panel.spec.key == positionSystem)
assert(panel.spec.title == "SeamlessUI - Focus frame", panel.spec.title)
-- Header, one row: 28 + 8 + 32.
assert(panel.height == 68, panel.height)
positionHeader.onClick()
assert(positionHeader.collapsed and not positionRow.shown and panel.height == 28 and panel:IsShown())
positionHeader.onClick()
assert(not positionHeader.collapsed and positionRow.shown)
Enum.EditModeSystem.ActionBar, Enum.EditModeSystem.AuraFrame = 2, 3
Enum.EditModeSystem.StatusTrackingBar, Enum.EditModeSystem.Minimap = 4, 5
Enum.EditModeSystem.ObjectiveTracker = 6
Enum.EditModeSystem.MainActionBarEndCap = 7
Enum.EditModeMainActionBarEndCapSystemIndices = { EndCapLeft = 1, EndCapRight = 2 }
Enum.EditModeActionBarSystemIndices = {
    MainBar = 1,
    Bar2 = 2,
    Bar3 = 3,
    RightBar1 = 4,
    RightBar2 = 5,
    ExtraBar1 = 6,
    ExtraBar2 = 7,
    ExtraBar3 = 8,
    StanceBar = 9,
    PetActionBar = 10,
    PossessActionBar = 11,
}
Enum.EditModeAuraFrameSystemIndices = { BuffFrame = 1, DebuffFrame = 2 }
Enum.EditModeStatusTrackingBarSystemIndices = { StatusTrackingBar1 = 1, StatusTrackingBar2 = 2 }
for i, name in ipairs({ "Party", "Raid", "Boss", "Arena" }) do
    Enum.EditModeUnitFrameSystemIndices[name] = i + 4
end
local samples = {
    { "party", 1, 5 },
    { "raid", 1, 6 },
    { "boss", 1, 7 },
    { "arena", 1, 8 },
    { "actionBar1", 2, 1 },
    { "actionBar2", 2, 2 },
    { "actionBar3", 2, 3 },
    { "actionBar4", 2, 4 },
    { "actionBar5", 2, 5 },
    { "actionBar6", 2, 6 },
    { "actionBar7", 2, 7 },
    { "actionBar8", 2, 8 },
    { "stanceBar", 2, 9 },
    { "petBar", 2, 10 },
    { "possessBar", 2, 11 },
    { "buffs", 3, 1 },
    { "debuffs", 3, 2 },
    { "statusBar1", 4, 1 },
    { "statusBar2", 4, 2 },
    { "minimap", 5, 1 },
    { "objectiveTracker", 6, 1 },
    { "endCapLeft", 7, 1 },
    { "endCapRight", 7, 2 },
}
EditModeManagerFrame.registeredSystemFrames = {}
assert(config.minimap.hidden() and config.barsHeading.hidden())
for _, sample in ipairs(samples) do
    local key, id, index = sample[1], sample[2], sample[3]
    local native = { system = id, systemIndex = index }
    table.insert(EditModeManagerFrame.registeredSystemFrames, native)
    assert(not config[key].hidden(), key)
    EditModeSystemSettingsDialog.attachedToSystem = native
    module:RefreshPanel()
    local selected, spec = module:GetSelectedFrame()
    assert(selected == native and spec.key == key and panel:IsShown(), key)
    assert(config[key].get() and positionShown() and positionSystem == native, key)
    config[key].set(nil, false)
    assert(not panel:IsShown())
    config[key].set(nil, true)
    assert(panel:IsShown())
end
assert(not config.barsHeading.hidden() and not config.aurasHeading.hidden())
-- Anchor candidates come from those same registered frames, using their real
-- persistent names, independently of whether their extension is enabled.
for index, native in ipairs(EditModeManagerFrame.registeredSystemFrames) do
    local name = "NativeAnchor" .. index
    _G[name] = native
    function native:GetName()
        return name
    end
end
local function anchorMap()
    local result = {}
    for _, entry in ipairs(module:GetAnchorTargets()) do
        result[entry.value] = entry.text
    end
    return result
end
local targets = anchorMap()
assert(targets.NativeAnchor5 == "Action bar 1")
assert(targets.NativeAnchor14 == "Pet action bar")
assert(targets.NativeAnchor16 == "Buffs")
assert(targets.NativeAnchor18 == "XP / reputation bar 1")
assert(targets.NativeAnchor20 == nil, "Minimap keeps its existing dedicated anchor")
config.buffs.set(nil, false)
assert(anchorMap().NativeAnchor16 == "Buffs")
_G.NativeAnchor18 = nil
assert(anchorMap().NativeAnchor18 == nil, "Unresolvable names cannot persist as anchors")
EditModeManagerFrame.registeredSystemFrames[#EditModeManagerFrame.registeredSystemFrames + 1] = {
    system = 999,
    GetName = function()
        return "UnknownAnchor"
    end,
}
assert(anchorMap().UnknownAnchor == nil)
assert(config.swingMainHand.hidden(), "Missing enum groups must be hidden safely")
config.buffs.set(nil, false)
assert(config.debuffs.get({ "enabled" }), "Different systems/indices must keep independent switches")
EditModeSystemSettingsDialog.attachedToSystem = { system = 2, systemIndex = 999 }
module:RefreshPanel()
assert(not panel:IsShown())
EditModeSystemSettingsDialog.attachedToSystem = { system = 1, systemIndex = 4 }
module:RefreshPanel()
combat = true
module:RefreshPanel()
assert(not panel:IsShown())
combat = false
module:RefreshPanel()
assert(panel:IsShown())
active = false
module:RefreshPanel()
assert(not panel:IsShown())
active = true
EditModeSystemSettingsDialog:Hide()
module:RefreshPanel()
assert(not panel:IsShown())
EditModeSystemSettingsDialog:Show()
EditModeSystemSettingsDialog.attachedToSystem = { system = 99, systemIndex = 1 }
module:RefreshPanel()
assert(not panel:IsShown())
EditModeSystemSettingsDialog.attachedToSystem = { system = 1, systemIndex = 4 }
config.enabled.set(nil, false)
assert(not panel:IsShown() and next(module.hooks) == nil and next(module.events) == nil)
module:RefreshPanel()
assert(not panel:IsShown())
config.enabled.set(nil, true)
assert(panel:IsShown())
-- Profile accessors must follow the active profile rather than capture its table.
local oldProfile = app.db.profile
app.db.profile = { blizzardEditMode = { enabled = false, frames = {} } }
module:OnProfileRefresh()
assert(not panel:IsShown() and not config.enabled.get())
app.db.profile = oldProfile
module:OnProfileRefresh()
assert(panel:IsShown())
-- Sections other addons register for a system stack below Position under their own header.
Enum.EditModeSystem.CastBar = 7
config.addPosition.set(nil, false)
local castBar = { system = 7 }
table.insert(EditModeManagerFrame.registeredSystemFrames, castBar)
EditModeSystemSettingsDialog.attachedToSystem = castBar
local style, sectionEnabled = { on = true, format = "A", size = 1 }, true
local function accessors(key)
    return function()
        return style[key]
    end, function(value)
        style[key] = value
    end
end
local getOn, setOn = accessors("on")
local getFormat, setFormat = accessors("format")
local getSize, setSize = accessors("size")
app.core:RegisterEditModeSystemOptions("Test", {
    system = 7,
    name = "Style",
    enabled = function()
        return sectionEnabled
    end,
    options = {
        { key = "on", type = "toggle", name = "On", get = getOn, set = setOn },
        {
            key = "format",
            type = "select",
            name = "Format",
            values = { { text = "Alpha", value = "A" }, { text = "Beta", value = "B" } },
            get = getFormat,
            set = setFormat,
            disabled = function()
                return not style.on
            end,
        },
        {
            key = "size",
            type = "range",
            name = "Size",
            min = 0,
            max = 2,
            step = 0.5,
            get = getSize,
            set = setSize,
            hidden = function()
                return not style.on
            end,
        },
    },
})
assert(panel:IsShown() and header.text == "Style" and not header.collapsed)
-- Header, then three rows: 28 + 8 + 32 + 3 + 32 + 3 + 32.
assert(panel.height == 138, panel.height)
local toggle = created.EditModeSettingCheckboxTemplate
local slider = created.EditModeSettingSliderTemplate
local dropdown = created.WowStyle1DropdownTemplate
assert(toggle.Button.checked == true and dropdown.defaultText == "Alpha" and slider.Slider.value == 1)
slider.onValueChanged(nil, 1.5)
assert(style.size == 1.5)
local radios = {}
dropdown.generator(nil, {
    CreateRadio = function(_, text, _, select)
        radios[text] = select
    end,
})
radios.Beta()
assert(style.format == "B" and dropdown.defaultText == "Beta")
toggle:OnCheckButtonClick()
assert(style.on == false and toggle.Button.checked == false and dropdown.enabled == false)
assert(not slider.shown and panel.height == 103, "hidden rows take no space")
-- Re-stacking the window (the Position poll does it) must not hide what stays shown: a hidden
-- button loses the press in progress, so its click never arrives.
local headerHides, toggleHides = header.hides, toggle.hides
module:RefreshPanel()
assert(header.hides == headerHides and toggle.hides == toggleHides, "shown sections stay shown")
header.onClick()
assert(header.collapsed and not toggle.shown and panel.height == 28)
sectionEnabled = false
app.core:RefreshEditModeSystemOptions()
assert(not header.shown and panel.height == 0, "a disabled feature's section leaves")
module:OnDisable()
assert(not panel:IsShown() and next(module.hooks) == nil)
print("Blizzard Edit Mode extensions OK")
