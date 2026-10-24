-- Run from the repository root: lua src/tests/editmode-keyboard.lua
local combat, deferred, eventHandler, propagated
function InCombatLockdown()
    return combat
end
function CreateFrame()
    return {
        RegisterEvent = function()
            deferred = true
        end,
        UnregisterEvent = function()
            deferred = false
        end,
        SetScript = function(_, _, handler)
            eventHandler = handler
        end,
    }
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
local module = { hooks = {} }
function module:IsHooked(_, script)
    return self.hooks[script] ~= nil
end
function module:SecureHookScript(_, script, method)
    self.hooks[script] = self[method]
end
function module:RegisterEvent() end
function module:UnregisterAllEvents() end
function module:UnhookAll()
    self.hooks = {}
end
local app = { addon = {
    NewModule = function()
        return module
    end,
} }
assert(loadfile("SeamlessUI/src/core/db.lua"))("SeamlessUI", app)
app.db = { profile = app.dbDefaults.profile }
assert(app.db.profile.editModeKeyboard == true, "enabled by default")
assert(loadfile("SeamlessUI/src/features/editmodekeyboard.lua"))("SeamlessUI", app)
module:OnEnable() -- Native addon may load later.
assert(next(module.hooks) == nil)
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
local option = module:Options()
assert(option.get() == true)
option.set(nil, false)
assert(propagated == false and option.get() == false)
module:OnKey(EditModeSystemSettingsDialog, "W")
assert(propagated == false, "disabled option retains native capture")
app.db.profile = { editModeKeyboard = true }
module:OnProfileRefresh()
module:OnKey(EditModeSystemSettingsDialog, "W")
assert(propagated == true, "profile switches use the current profile")
combat = true
module:OnDisable()
assert(deferred and next(module.hooks) == nil)
combat = false
eventHandler()
assert(propagated == false and not deferred, "restore capture after combat")
print("UI Edit Mode keyboard option OK")

-- The shared declaration exposes the same General toggle to both options panels.
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
assert(loadfile("SeamlessUI/src/core/options.lua"))("SeamlessUI", app)
app.options:OnInitialize()
assert(registered.general.editModeKeyboard.get() == true)
registered.general.editModeKeyboard.set(nil, false)
assert(app.db.profile.editModeKeyboard == false)
print("UI General keyboard option registration OK")
