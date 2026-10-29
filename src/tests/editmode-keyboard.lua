-- Run from the repository root: lua src/tests/editmode-keyboard.lua
local combat, loggedIn, propagated = false, false
function InCombatLockdown()
    return combat
end
function IsLoggedIn()
    return loggedIn
end
function CreateFrame()
    error("keyboard option must not create frames")
end
function LibStub()
    return {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    }
end
local module = { hooks = {}, events = {}, enabled = false }
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
function module:IsHooked(_, script)
    return self.hooks[script] ~= nil
end
function module:SecureHookScript(_, script, method)
    self.hooks[script] = self[method]
end
function module:RegisterEvent(event, handler)
    self.events[event] = handler
end
function module:UnregisterEvent(event)
    self.events[event] = nil
end
function module:UnregisterAllEvents()
    self.events = {}
end
function module:UnhookAll()
    self.hooks = {}
end
local app = { addon = {
    NewModule = function()
        return module
    end,
} }
assert(loadfile("SeamlessUI/src/core/db.lua"))("SeamlessUI", app)
dofile("src/tests/settings-support.lua").defaults("SeamlessUI", app)
app.db = { profile = app.dbDefaults.profile }
assert(app.db.profile.editModeKeyboard == true, "enabled by default")
assert(loadfile("SeamlessUI/src/features/editmodekeyboard.lua"))("SeamlessUI", app)
-- A disabled saved profile must never install hooks/events or touch the native dialog.
app.db.profile = { editModeKeyboard = false }
EditModeSystemSettingsDialog = setmetatable({}, {
    __index = function()
        error("disabled feature touched Blizzard's dialog")
    end,
})
module:OnProfileRefresh()
assert(not module:IsEnabled() and next(module.hooks) == nil and next(module.events) == nil)
loggedIn = true
module:OnProfileRefresh()
assert(next(module.hooks) == nil and next(module.events) == nil)
EditModeSystemSettingsDialog = nil
app.blizzardEditMode = {
    GetOptionsFrames = function()
        return {}, {}
    end,
}
app.optionPages = {}
assert(loadfile("SeamlessUI/src/options/blizzardEditMode.lua"))("SeamlessUI", app)
local option = app.optionPages.blizzardEditMode.config.args.editModeKeyboard
option.set(nil, true) -- Native addon may load later.
assert(module:IsEnabled() and module.events.ADDON_LOADED and next(module.hooks) == nil)
EditModeSystemSettingsDialog = {
    SetPropagateKeyboardInput = function(_, value)
        propagated = value
    end,
}
module:InstallHooks()
module:InstallHooks()
for _, script in ipairs({ "OnKeyDown", "OnKeyUp" }) do
    for _, key in ipairs({ "W", "SPACE", "ENTER", "LSHIFT", "RSHIFT" }) do
        module.hooks[script](module, EditModeSystemSettingsDialog, key)
        assert(propagated == true, script .. " passes " .. key)
    end
    for _, key in ipairs({ "LEFT", "RIGHT", "UP", "DOWN", "ESCAPE", "PRINTSCREEN" }) do
        module.hooks[script](module, EditModeSystemSettingsDialog, key)
        assert(propagated == false, script .. " consumes " .. key)
    end
end
assert(option.get() == true)
option.set(nil, false)
assert(propagated == false and option.get() == false)
assert(not module:IsEnabled() and next(module.hooks) == nil and next(module.events) == nil)
app.db.profile = { editModeKeyboard = true }
module:OnProfileRefresh()
module:OnKey(EditModeSystemSettingsDialog, "W")
assert(propagated == true, "profile switches use the current profile")
combat = true
app.db.profile = { editModeKeyboard = false }
module:OnProfileRefresh()
assert(module:IsEnabled() and module.events.PLAYER_REGEN_ENABLED)
combat = false
module:OnProfileRefresh()
assert(not module:IsEnabled() and propagated == false)
assert(next(module.hooks) == nil and next(module.events) == nil)
option.set(nil, true)
assert(module:IsEnabled() and module.hooks.OnKeyDown and module.hooks.OnKeyUp)
print("UI Edit Mode keyboard option OK")

-- The shared declaration exposes the same Blizzard Editmode toggle to both options panels.
local registered
app.core = {
    RegisterOptions = function(_, _, spec)
        registered = spec
    end,
}
app.xpBarTooltip = {
    Options = function()
        return {}
    end,
}
app.blizzardEditMode = {
    Options = function()
        return {}
    end,
}
app.addon.NewModule = function(_, _, implementation)
    return implementation
end
assert(loadfile("SeamlessUI/src/options/register.lua"))("SeamlessUI", app)
app.options:OnInitialize()
assert(registered.pages.blizzardEditMode.config.args.editModeKeyboard.get() == true)
registered.pages.blizzardEditMode.config.args.editModeKeyboard.set(nil, false)
assert(app.db.profile.editModeKeyboard == false)
print("UI Blizzard Editmode keyboard option registration OK")
