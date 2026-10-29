-- Run from the repository root: lua src/tests/bar-visibility.lua
local callbacks, module, eventFrame = {}, {}, { events = {} }
local combat, enabled, editing = false, true, false
local function frame(shown)
    return {
        shown = shown,
        calls = 0,
        IsShown = function(self)
            return self.shown
        end,
        Show = function(self)
            assert(not combat)
            self.shown, self.calls = true, self.calls + 1
        end,
        Hide = function(self)
            assert(not combat)
            self.shown, self.calls = false, self.calls + 1
        end,
    }
end
function eventFrame:RegisterEvent(event)
    self.events[event] = true
end
function eventFrame:UnregisterAllEvents()
    self.events = {}
end
function eventFrame:SetScript(_, callback)
    self.callback = callback
end
CreateFrame = function()
    return eventFrame
end
InCombatLockdown = function()
    return combat
end
EditModeManagerFrame = {
    IsEditModeActive = function()
        return editing
    end,
}
local app = {
    addon = {
        NewModule = function()
            return module
        end,
        IsEnabled = function()
            return enabled
        end,
    },
    core = {
        RefreshOptions = function() end,
        GetEditModeLibrary = function()
            return {
                RegisterCallback = function(_, event, callback)
                    callbacks[event] = callback
                end,
            }
        end,
    },
    db = { profile = { microMenu = { hidden = false }, bags = { hidden = false } } },
}
assert(loadfile("SeamlessActionBars/src/barvisibility.lua"))("SeamlessActionBars", app)
MicroMenuContainer, BagsBar = frame(true), frame(false)
module:OnInitialize()
module:OnEnable()
local menu = app.BarHiddenOption("microMenu", "Hide micro menu", 50)
local bags = app.BarHiddenOption("bags", "Hide bag bar", 60)
assert(menu.default == false and not menu.get())
callbacks.enter()
callbacks.exit()
eventFrame.callback()
assert(MicroMenuContainer.calls == 0 and BagsBar.calls == 0, "off never touches Blizzard visibility")
menu.set(nil, true)
assert(not MicroMenuContainer.shown and MicroMenuContainer.calls == 1)
app.RefreshBarVisibility()
assert(MicroMenuContainer.calls == 1, "do not repeat Hide on an already hidden frame")
callbacks.enter()
assert(MicroMenuContainer.shown and BagsBar.calls == 0, "only opted-in frames are previewed")
menu.set(nil, false)
callbacks.exit()
assert(MicroMenuContainer.shown and MicroMenuContainer.calls == 2, "turning off during preview releases ownership")
bags.set(nil, true)
assert(BagsBar.calls == 0, "already hidden frame needs no write")
callbacks.enter()
assert(BagsBar.shown)
callbacks.exit()
assert(not BagsBar.shown)
bags.set(nil, false)
assert(not BagsBar.shown and BagsBar.calls == 2, "restore original hidden state")
menu.set(nil, true)
app.db.profile = { microMenu = { hidden = false }, bags = { hidden = false } }
app.RefreshBarVisibility()
assert(MicroMenuContainer.shown, "profile switch restores owned visibility")
combat = true
menu.set(nil, true)
assert(MicroMenuContainer.shown, "combat defers Hide")
combat = false
eventFrame.callback()
assert(not MicroMenuContainer.shown)
combat, enabled = true, false
module:OnDisable()
assert(not MicroMenuContainer.shown and eventFrame.events.PLAYER_REGEN_ENABLED)
combat = false
eventFrame.callback()
assert(MicroMenuContainer.shown and not next(eventFrame.events), "deferred restoration survives disable")
enabled, editing = true, true
module:OnEnable()
assert(MicroMenuContainer.shown, "enabling during Edit Mode preserves preview")
callbacks.exit()
assert(not MicroMenuContainer.shown)
MicroMenuContainer = nil
app.RefreshBarVisibility()
module:OnDisable()
print("PASS: opt-in visibility, Edit Mode preview, original state, profiles, combat and disable")
