-- BetterGroupLoot adapter: default on, Start/Stop ownership, namespace, combat-deferred Edit Mode
-- registration and the Frames checkbox that hides previews and the selection.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
local starts, stops, refreshes, registrations, warnings, dialogsHidden = 0, 0, 0, 0, 0, 0
local editing, combat = false, false
local selection = { shown = false }
function selection:Hide()
    self.shown = false
end
function selection:IsShown()
    return self.shown
end
function selection:ShowHighlighted()
    self.shown = true
end
local callbacks = {}
local editModeLib = { id = "core", frameSelections = {} }
function editModeLib:IsInEditMode()
    return editing
end
function editModeLib:RegisterCallback(event, callback)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], callback)
end
local function trigger(event)
    for _, callback in ipairs(callbacks[event] or {}) do
        callback()
    end
end

local controller = { anchor = {}, previews = false }
editModeLib.frameSelections[controller.anchor] = selection
function controller:Stop()
    stops = stops + 1
    self.active = false
    self.previews = false
end
function controller:OnProfileRefresh()
    refreshes = refreshes + 1
end
function controller:ShowPreviews()
    self.previews = true
end
function controller:HidePreviews()
    self.previews = false
end
function controller:GetEditModeSettings(lib, options)
    assert(lib == editModeLib and options.strings.spacing == "Spacing")
    return { { key = "spacing" } }
end
function controller:RegisterEditMode(lib, options)
    assert(not self.editMode and not combat and options.managePreviews == false)
    registrations = registrations + 1
    local settings = options.settings(self, lib)
    assert(#settings == 2 and settings[2].kind == "buttons" and #settings[2].options == 2)
    self.editMode = { library = lib }
end
local owner = { prefix = "Other", reason = "owned" }
local startResult
local BGL = { defaults = { scale = 1, position = { x = 600, y = 420 } } }
function BGL:Start(options)
    starts = starts + 1
    assert(options.name == "SeamlessGroupLoot" and options.strings.undecided == "Undecided")
    assert(options.getProfile().scale == 1)
    if startResult then
        startResult.active = true
        return startResult
    end
    return nil, owner
end
function LibStub(name)
    if name == "AceLocale-3.0" then
        return {
            GetLocale = function()
                return L
            end,
        }
    end
    assert(name == "BetterGroupLoot-1.0")
    return BGL
end
function InCombatLockdown()
    return combat
end
local eventFrame
function CreateFrame()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(event)
        self.events[event] = true
    end
    function eventFrame:UnregisterAllEvents()
        self.events = {}
    end
    function eventFrame:SetScript(_, handler)
        self.handler = handler
    end
    return eventFrame
end
EventRegistry = {
    TriggerEvent = function(_, event)
        assert(event == "EditModeExternal.hideDialog")
        dialogsHidden = dialogsHidden + 1
    end,
}
function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end
local namespaces = 0
local frameOptions
local app = {
    logger = {
        warn = function()
            warnings = warnings + 1
        end,
        debug = function() end,
    },
    db = {
        GetNamespace = function() end,
        RegisterNamespace = function(_, name, defaults)
            assert(name == "GroupLoot" and defaults.profile.position.x == 600)
            namespaces = namespaces + 1
            return { profile = CopyTable(defaults.profile) }
        end,
    },
    addon = {
        GetEditModeLibrary = function()
            return editModeLib
        end,
        GetEditModeButtonSection = function(_, buttons)
            return { kind = "buttons", options = buttons }
        end,
        GetEditModePositionButton = function(_, action)
            return { name = action }
        end,
        RegisterEditModeOptions = function(_, id, spec)
            assert(id == "Seamless.GroupLoot" and spec.section == "frames")
            frameOptions = spec
        end,
        RefreshEditModeOptions = function() end,
    },
}
local spec
app.embed = {
    Register = function(_, id, value)
        assert(id == "groupLoot")
        spec = value
    end,
}
assert(loadfile("Seamless/src/embed/grouploot.lua"))("Seamless", app)
assert(spec.name == "Group loot" and spec.default == true)
local row = frameOptions.options[1]
assert(row.type == "toggle" and row.name == "Group loot" and row.get() == true)
assert(not frameOptions.enabled())

-- Another host owns the frames: no warning spam, never stop or refresh its controller.
spec.enable()
assert(starts == 1 and warnings == 0 and registrations == 0 and not frameOptions.enabled())
spec.refresh()
spec.disable()
assert(stops == 0 and refreshes == 0)

-- Owned, but enabled in combat: Edit Mode registration waits for combat to end.
startResult = controller
combat = true
spec.enable()
assert(starts == 2 and registrations == 0 and eventFrame.events.PLAYER_REGEN_ENABLED)
combat = false
eventFrame.handler(eventFrame, "PLAYER_REGEN_ENABLED")
assert(registrations == 1 and frameOptions.enabled())
spec.refresh()
assert(refreshes == 1)

-- Edit Mode shows previews; the Frames checkbox hides previews and the selection, not the anchor.
editing = true
selection.shown = true -- LibEditMode highlights every selection before its enter callbacks.
trigger("enter")
assert(controller.previews and selection.shown)
row.set(false)
assert(not row.get() and not controller.previews and not selection.shown and dialogsHidden == 1)
trigger("layout")
assert(not controller.previews and not selection.shown)
row.set(true)
assert(controller.previews and selection.shown)
combat = true
eventFrame.handler(eventFrame, "PLAYER_REGEN_DISABLED")
assert(not controller.previews)
combat = false
eventFrame.handler(eventFrame, "PLAYER_REGEN_ENABLED")
assert(controller.previews)
editing = false
trigger("exit")
assert(not controller.previews)

spec.disable()
assert(stops == 1 and not frameOptions.enabled() and next(eventFrame.events) == nil)

-- Re-enable reuses the session's registration.
spec.enable()
assert(registrations == 1 and namespaces == 1 and frameOptions.enabled())
print("Group loot adapter default, ownership, namespace, combat-deferred Edit Mode and Frames row passed")
