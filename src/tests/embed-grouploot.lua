-- BetterGroupLoot adapter: default on, Start/Stop ownership, namespace, combat-deferred Edit Mode
-- registration and the Frames checkbox that hides previews and the selection.
unpack = unpack or table.unpack
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
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.onShow then
        self.onShow(self)
    end
end
function selection:HookScript(event, callback)
    assert(event == "OnShow" and not self.onShow)
    self.onShow = callback
end
local callbacks = {}
local editModeLib = {
    id = "core",
    frameSelections = {},
    SettingType = {
        Header = "header",
        Position = "position",
        Option = "option",
        ButtonSection = "seamless-button-section",
    },
}
function editModeLib:IsInEditMode()
    return editing
end
function editModeLib:RegisterCallback(event, callback)
    callbacks[event] = callbacks[event] or {}
    table.insert(callbacks[event], callback)
end
function editModeLib:RefreshFrameSettings(frame)
    assert(frame ~= nil)
end
local function trigger(event)
    for _, callback in ipairs(callbacks[event] or {}) do
        callback()
    end
end

local controller = { anchor = {}, previews = false }
function editModeLib:GetFrameDefaultPosition(frame)
    assert(frame == controller.anchor)
    return controller.editMode and controller.editMode.defaultPosition
end
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
function controller:RefreshOptions() end
local frameSettings
function controller:RegisterEditMode(lib, options)
    assert(not self.editMode and not combat and options.managePreviews == false)
    registrations = registrations + 1
    local settings = options.settings(self, lib)
    assert(settings[#settings].kind == "seamless-button-section" and #settings[#settings].options == 2)
    assert(settings[1].kind == "position" and #settings[1].sizeOptions == 2)
    assert(settings[1].sizeOptions[1].row.setting.path[3] == "scale")
    assert(settings[1].sizeOptions[2].row.setting.path[3] == "spacing")
    assert(settings[1].sizeOptions[1].row.format(1) == "1")
    assert(settings[1].sizeOptions[1].row.format(0.55) == "0.55")
    assert(settings[2].name == "Style" and settings[2].kind == "header")
    assert(settings[3].row.setting.path[3] == "growUp" and settings[4].row.setting.path[3] == "showUndecided")
    frameSettings = settings
    self.editMode = { library = lib, defaultPosition = {} }
end
local owner = { prefix = "Other", reason = "owned" }
local startResult
local BGL =
    { defaults = { scale = 1, spacing = 4, growUp = true, showUndecided = true, position = { x = 600, y = 420 } } }
local host
function controller:ApplySettings()
    host.applyPosition(self.anchor)
end
function controller.anchor:SetScale(value)
    self.scale = value
end
function controller.anchor:GetScale()
    return self.scale or 1
end
function controller.anchor:ClearAllPoints() end
function controller.anchor:SetPoint(point, parent, relativePoint, x, y)
    self.point = { point, parent, relativePoint, x, y }
end
function controller.anchor:GetCenter()
    return 500
end
function controller.anchor:GetBottom()
    return 100
end
UIParent = {
    GetWidth = function()
        return 1000
    end,
}
function BGL:Start(options)
    starts = starts + 1
    assert(options.name == "SeamlessGroupLoot" and options.strings.undecided == "Undecided")
    assert(options.getProfile().scale == 1)
    host = options
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
local namespaceDatabase
local frameOptions
local app = {
    LibEditMode = editModeLib,
    optionPages = {},
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
            namespaceDatabase = { profile = CopyTable(defaults.profile) }
            return namespaceDatabase
        end,
    },
    addon = {
        GetEditModeLibrary = function()
            return editModeLib
        end,
        GetEditModeButtonSection = function(_, buttons)
            return { kind = "seamless-button-section", options = buttons }
        end,
        GetEditModePositionSetting = function(_, spec, options, sizeOptions)
            return { kind = "position", position = spec, options = options, sizeOptions = sizeOptions }
        end,
        GetEditModePositionButton = function(_, action)
            return { kind = "seamless-button", name = action, click = function() end }
        end,
        RegisterEditModeOptions = function(_, id, spec)
            assert(id == "Seamless.GroupLoot" and spec.section == "frames")
            frameOptions = spec
        end,
        RefreshEditModeOptions = function() end,
        RefreshOptions = function() end,
    },
}
local spec
app.embed = {
    Register = function(_, id, value)
        assert(id == "groupLoot")
        spec = value
    end,
    RegisterOptions = function(_, id, page)
        app.optionPages[id] = page
    end,
}
for _, file in ipairs({
    "config/schema.lua",
    "config/registry.lua",
    "config/model.lua",
    "config/position.lua",
    "core/editmodepages.lua",
}) do
    assert(loadfile("Seamless/src/" .. file))("Seamless", app)
end
assert(loadfile("Seamless/src/embed/grouploot.lua"))("Seamless", app)
assert(loadfile("Seamless/src/embed/options/grouploot.lua"))("Seamless", app)
app.addon:PrepareSettingsOptions(app.optionPages.groupLoot.config)
app.options = {
    panels = { Seamless = { options = { type = "group", args = { groupLoot = app.optionPages.groupLoot.config } } } },
}
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

-- Panel and Edit Mode resolve the same declaration and the same current namespace profile.
local page = app.optionPages.groupLoot.config
assert(frameSettings[1].position == page.args.position.editModePosition)
local scaleRow = frameSettings[1].sizeOptions[1].row
local spacingRow = frameSettings[1].sizeOptions[2].row
local growUpRow, undecidedRow = frameSettings[3].row, frameSettings[4].row
for _, current in ipairs({ scaleRow, spacingRow, growUpRow, undecidedRow }) do
    local option = current.setting
    assert(option.root == app.options.panels.Seamless.options)
    assert(current.name == option:Read("name") and current.default() == option:DefaultValue())
    assert(current.disabled() == option:Read("disabled"))
end
assert(scaleRow.min() == 0.5 and scaleRow.max() == 2 and scaleRow.step() == 0.05)
page.args.size.args.scale.default = 1.25
page.args.size.args.spacing.max = 30
assert(scaleRow.default() == 1.25 and spacingRow.max() == 30, "Edit Mode reads the page's metadata")
page.args.size.args.scale.default = BGL.defaults.scale
page.args.size.args.spacing.max = 40
scaleRow.set(1.23)
assert(scaleRow.get() == 1.25 and scaleRow.setting:Read("get") == 1.25)
scaleRow.setting:Commit(1)
spacingRow.set(9)
growUpRow.set(false)
undecidedRow.set(false)
assert(host.getProfile().spacing == 9 and not host.getProfile().growUp and not host.getProfile().showUndecided)
combat = true
assert(scaleRow.disabled() and growUpRow.disabled())
scaleRow.set(1.5)
growUpRow.set(true)
assert(host.getProfile().scale == 1 and not host.getProfile().growUp)
combat = false
local oldProfile = namespaceDatabase.profile
namespaceDatabase.profile = CopyTable(BGL.defaults)
namespaceDatabase.profile.spacing = 11
assert(spacingRow.get() == 11 and growUpRow.get() == true)
spacingRow.set(12)
assert(oldProfile.spacing == 9 and namespaceDatabase.profile.spacing == 12)
scaleRow.setting:Reset()
spacingRow.setting:Reset()
assert(scaleRow.get() == BGL.defaults.scale and spacingRow.get() == BGL.defaults.spacing)

-- Existing offsets keep their screen position; Size and Position share the same live scale.
local position = frameSettings[1].position
assert(position.get("point") == "BOTTOM" and position.get("relativeTo") == "UIParent")
host.applyPosition(controller.anchor)
assert(controller.anchor.point[4] == 600 and controller.anchor.point[5] == 420)
host.getProfile().scale = 2
host.applyPosition(controller.anchor)
assert(position.get("x") == 300 and controller.anchor.point[4] == 300)
assert(position.default("x") == controller.editMode.defaultPosition.x)
for _, group in ipairs({ "position", "size", "style" }) do
    for _, option in ipairs(app.addon:GetPageOption("Seamless", "groupLoot", { group }):Children(true)) do
        if option:Read("type") ~= "execute" then
            assert(option:DefaultValue() ~= nil, "every embedded setting declares a default")
        end
    end
end
position.set("point", "TOPLEFT")
position.set("relativePoint", "TOPRIGHT")
position.set("x", 125)
assert(controller.anchor.point[1] == "TOPLEFT" and controller.anchor.point[3] == "TOPRIGHT")
assert(host.getProfile().position.x == 250 and controller.anchor.point[4] == 125)
combat = true
position.set("x", 999)
assert(host.getProfile().position.x == 250)
combat = false
host.savePosition(controller.anchor)
assert(position.get("point") == "BOTTOM" and position.get("relativePoint") == "BOTTOM")
assert(host.getProfile().position.x == 500 and host.getProfile().position.y == 200)
host.resetPosition()
host.getProfile().scale = 1
assert(position.get("point") == "BOTTOM" and position.get("x") == 600 and position.get("y") == 420)

-- Edit Mode shows previews; the Frames checkbox hides previews and the selection, not the anchor.
editing = true
selection.shown = true -- LibEditMode highlights every selection before its enter callbacks.
trigger("enter")
assert(controller.previews and selection.shown)
row.set(false)
assert(not row.get() and not controller.previews and not selection.shown and dialogsHidden == 1)
-- Selecting a native/suite frame or hiding its dialog re-highlights every library selection.
for _ = 1, 3 do
    selection:ShowHighlighted()
    assert(not selection.shown and not controller.previews)
end
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

editing = true
selection:ShowHighlighted()
spec.disable()
assert(stops == 1 and not frameOptions.enabled() and next(eventFrame.events) == nil)
assert(scaleRow.disabled() and growUpRow.disabled())
scaleRow.set(2)
assert(host.getProfile().scale == 1)
selection:ShowHighlighted()
assert(not selection.shown and not controller.previews)
editing = false

-- Re-enable reuses the session's registration.
spec.enable()
assert(registrations == 1 and namespaces == 1 and frameOptions.enabled())
print("Group loot adapter default, ownership, namespace, combat-deferred Edit Mode and Frames row passed")
