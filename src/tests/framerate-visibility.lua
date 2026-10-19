-- Run from the repository root: lua src/tests/framerate-visibility.lua
local callbacks, spec = {}, nil
local editing = false
local lib = {
    RegisterCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
    IsInEditMode = function()
        return editing
    end,
}
SlashCmdList = {}
FramerateFrame = {
    shown = false,
    IsShown = function(self)
        return self.shown
    end,
    Show = function(self)
        self.shown = true
    end,
    SetShown = function(self, value)
        self.shown = value
    end,
}
local app = {
    db = { profile = { tweaks = { reloadShortcut = false, showFramerateOnStartup = false } } },
    addon = {
        NewModule = function(_, _, module)
            return module
        end,
        GetEditModeLibrary = function()
            return lib
        end,
        RegisterEditModeOptions = function(_, _, value)
            spec = value
        end,
        RefreshEditModeOptions = function() end,
    },
}
assert(loadfile("Seamless/src/core/tweaks.lua"))("Seamless", app)
local module = app.tweaks
module:OnEnable()
assert(not FramerateFrame.shown and not spec.options[1].get(), "startup defaults off")
assert(spec.section == "options", "startup setting belongs above Frames")
editing = true
callbacks.enter()
assert(FramerateFrame.shown, "Edit Mode must preview hidden FPS")
assert(not app.db.profile.tweaks.showFramerateOnStartup, "preview must not change preference")
callbacks.enter()
editing = false
callbacks.exit()
assert(not FramerateFrame.shown, "repeated entry must preserve original hidden state")
FramerateFrame:Show()
callbacks.enter()
callbacks.exit()
assert(FramerateFrame.shown, "user-visible FPS must stay visible on exit")
FramerateFrame:SetShown(false)
callbacks.enter()
spec.options[1].set(true)
callbacks.exit()
assert(not FramerateFrame.shown and spec.options[1].get(), "startup changes apply on next startup")
module:OnDisable()
module:OnEnable()
assert(FramerateFrame.shown, "saved startup preference must apply")
spec.options[1].set(false)
FramerateFrame:SetShown(false)
callbacks.enter()
module:OnDisable()
assert(not FramerateFrame.shown, "disable must undo temporary preview")
callbacks.enter()
assert(not FramerateFrame.shown, "disabled tweaks must not preview")
editing = true
module:OnEnable()
assert(FramerateFrame.shown, "enabling inside Edit Mode must preview")
editing = false
callbacks.exit()
assert(not FramerateFrame.shown)
print("Framerate visibility tests passed")
