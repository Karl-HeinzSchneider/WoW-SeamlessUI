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
    for _, method in ipairs({
        "SetHeight",
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
app.blizzardPosition = {
    Create = function()
        local view = frame()
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
local originalPanel = panel
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
print("Blizzard Edit Mode extensions OK")
