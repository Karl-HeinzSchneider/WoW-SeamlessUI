-- Run from the repository root: lua src/tests/blizzard-editmode.lua
dofile("src/tests/locale-support.lua")
local module, panel
local combat, active = false, true
local function frame()
    local f = { shown = true }
    function f:Hide()
        self.shown = false
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
    for _, method in ipairs({
        "SetFrameStrata",
        "EnableMouse",
        "SetPoint",
        "SetAllPoints",
        "SetFrameLevel",
        "SetWordWrap",
    }) do
        f[method] = function() end
    end
    return f
end
function CreateFrame(_, _, parent)
    local f = frame()
    if parent == UIParent then
        panel = f
    end
    return f
end
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
local collapsedSections, header, positionView, dialogPanel = {}, nil, nil, nil
app.core = {
    CreateEditModeHeader = function(_, _, onClick)
        header = frame()
        header.onClick = onClick
        function header:SetHeaderText(text)
            self.text = text
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
    AddEditModeDialogPanel = function(_, panel)
        dialogPanel = panel
    end,
}
app.blizzardPosition = {
    Create = function()
        local view = frame()
        positionView = view
        function view:Refresh(system)
            self.system = system
        end
        return view
    end,
}
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
assert(loadfile("SeamlessUI/src/features/blizzardeditmode.lua"))("SeamlessUI", app)
module:OnProfileRefresh() -- Native UI not loaded yet.
assert(module.events.ADDON_LOADED and next(module.hooks) == nil)
EditModeSystemSettingsDialog = frame()
EditModeManagerFrame = frame()
function EditModeManagerFrame:IsEditModeActive()
    return active
end
module:InstallHooks()
assert(module:IsHooked(EditModeSystemSettingsDialog, "AttachToSystemFrame"))
local config = module:Options().args
for _, key in ipairs({ "player", "target", "pet", "focus" }) do
    local group = config[key]
    local index = Enum.EditModeUnitFrameSystemIndices[key:sub(1, 1):upper() .. key:sub(2)]
    EditModeSystemSettingsDialog.attachedToSystem = { system = 1, systemIndex = index }
    module:RefreshPanel()
    assert(panel:IsShown(), key)
    group.set({ "enabled" }, false)
    assert(not panel:IsShown() and group.args.addPosition.disabled())
    group.set({ "enabled" }, true)
    group.set({ "addPosition" }, true)
    group.set({ "addMoreOptions" }, true)
    assert(panel:IsShown() and group.get({ "addPosition" }) and group.get({ "addMoreOptions" }))
end
-- Add position appears as an expanded Position header that collapses like every other header.
assert(header.shown and header.text == "Position" and not header.collapsed and positionView.shown)
header.onClick()
assert(header.collapsed and not positionView.shown and panel.height == 92 and panel:IsShown())
header.onClick()
assert(not header.collapsed and positionView.shown)
local originalPanel = panel
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
Enum.EditModeSystem.ActionBar, Enum.EditModeSystem.AuraFrame = 2, 3
Enum.EditModeSystem.StatusTrackingBar, Enum.EditModeSystem.Minimap = 4, 5
Enum.EditModeSystem.ObjectiveTracker = 6
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
    assert(config[key].get({ "enabled" }) and not config[key].get({ "addPosition" }))
    config[key].set({ "addPosition" }, true)
    config[key].set({ "enabled" }, false)
    assert(not panel:IsShown())
    config[key].set({ "enabled" }, true)
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
assert(targets.NativeAnchor5 == config.actionBar1.name)
assert(targets.NativeAnchor14 == config.petBar.name)
assert(targets.NativeAnchor16 == config.buffs.name)
assert(targets.NativeAnchor18 == config.statusBar1.name)
assert(targets.NativeAnchor20 == nil, "Minimap keeps its existing dedicated anchor")
config.buffs.set({ "enabled" }, false)
assert(anchorMap().NativeAnchor16 == config.buffs.name)
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
config.buffs.set({ "enabled" }, false)
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
assert(panel:IsShown() and panel == originalPanel)
-- Profile accessors must follow the active profile rather than capture its table.
local oldProfile = app.db.profile
app.db.profile = { blizzardEditMode = { enabled = false, frames = {} } }
module:OnProfileRefresh()
assert(not panel:IsShown() and not config.enabled.get())
app.db.profile = oldProfile
module:OnProfileRefresh()
assert(panel:IsShown())
module:OnDisable()
assert(not panel:IsShown() and next(module.hooks) == nil)
assert(dialogPanel == panel, "System settings from other addons stack below the panel")
print("Blizzard Edit Mode extensions OK")
