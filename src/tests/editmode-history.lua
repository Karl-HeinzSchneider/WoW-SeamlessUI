-- Run from the repository root: lua src/tests/editmode-history.lua
local combat, mouse, editing = false, false, true
function InCombatLockdown()
    return combat
end
function IsMouseButtonDown()
    return mouse
end
function IsLoggedIn()
    return true
end
function CopyTable(value)
    local result = {}
    for key, child in pairs(value) do
        result[key] = type(child) == "table" and CopyTable(child) or child
    end
    return result
end
local callbacks, pending, objects = {}, {}, {}
C_Timer = {
    After = function(_, callback)
        pending[#pending + 1] = callback
    end,
}
local function flush()
    local work = pending
    pending = {}
    for _, callback in ipairs(work) do
        callback()
    end
end
local function object(name)
    local result = { scripts = {} }
    setmetatable(result, {
        __index = function(_, key)
            if key == "CreateFontString" then
                return function()
                    return object()
                end
            end
            if key == "GetFrameLevel" then
                return function()
                    return 1
                end
            end
            if key == "SetScript" then
                return function(self, script, callback)
                    self.scripts[script] = callback
                end
            end
            if key == "SetText" then
                return function(self, text)
                    self.text = text
                end
            end
            if key == "SetEnabled" then
                return function(self, enabled)
                    self.enabled = enabled
                end
            end
            if key == "Show" then
                return function(self)
                    self.shown = true
                end
            end
            if key == "Hide" then
                return function(self)
                    self.shown = false
                end
            end
            return function() end
        end,
    })
    objects[#objects + 1] = result
    if name then
        _G[name] = result
    end
    return result
end
CreateFrame = function(_, name)
    return object(name)
end
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
function LibStub()
    return {
        GetLocale = function()
            return L
        end,
    }
end
local module = { enabled = false }
function module:SetEnabledState(enabled)
    self.enabled = enabled
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
function module:RegisterEvent() end
function module:UnregisterAllEvents() end
local hooks = {}
function module:IsHooked(frame, method)
    return hooks[frame] and hooks[frame][method]
end
function module:SecureHook(frame, method, callback)
    hooks[frame] = hooks[frame] or {}
    hooks[frame][method] = callback
end
function module:UnhookAll()
    hooks = {}
end
local library = {
    IsInEditMode = function()
        return editing
    end,
    RegisterCallback = function(_, event, callback)
        callbacks[event] = callback
    end,
}
local values = { x = 0, scale = 1 }
local frame = {
    GetName = function()
        return "Test frame"
    end,
}
local locked, fail, failKey = false, false, nil
local sources = {}
for _, key in ipairs({ "x", "scale" }) do
    sources[#sources + 1] = {
        frame = frame,
        key = key,
        name = key,
        get = function()
            return values[key]
        end,
        set = function(value)
            if fail or failKey == key then
                return false
            end
            values[key] = value
        end,
        disabled = function()
            return locked
        end,
    }
end
local nativeInfo = {
    anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
    settings = { { setting = 1, value = 100 } },
}
local native = {
    OnDragStop = function() end,
    system = 1,
    systemIndex = 1,
    savedSystemInfo = CopyTable(nativeInfo),
    GetName = function()
        return "Native"
    end,
    GetSettingValue = function()
        return nativeInfo.settings[1].value
    end,
    SetHasActiveChanges = function(self, value)
        self.dirty = value
    end,
}
EditModeManagerFrame = {
    registeredSystemFrames = { native },
    GetActiveLayoutSystemInfo = function()
        return nativeInfo
    end,
    OnSystemSettingChange = function(_, _, _, value)
        nativeInfo.settings[1].value = value
    end,
    CheckForSystemActiveChanges = function() end,
}
local position = {
    CanEdit = function()
        return not locked
    end,
    Apply = function(_, _, anchor, state)
        if locked then
            return false
        end
        nativeInfo.anchorInfo = anchor
        nativeInfo.anchorInfo2 = state.anchorInfo2
        nativeInfo.isInDefaultPosition = state.isInDefaultPosition
        return true
    end,
}
local app = {
    addon = {
        NewModule = function()
            return module
        end,
    },
    db = { profile = { editModeHistory = true } },
    core = {
        GetEditModeLibrary = function()
            return library
        end,
        GetFramePositionService = function()
            return position
        end,
        GetEditModeHistorySources = function()
            return sources
        end,
        RefreshEditModeOptions = function() end,
    },
}
assert(loadfile("SeamlessUI/src/features/editmodehistory.lua"))("SeamlessUI", app)
module:OnProfileRefresh()
local button
for _, obj in ipairs(objects) do
    if obj.text == "Undo last change" then
        button = obj
    end
end
assert(button and not button.enabled and SeamlessUIEditModeHistory.shown)
values.x = 1
module:Sample()
assert(button.enabled)
values.scale = 2
module:Sample()
module:Undo()
assert(values.x == 1 and values.scale == 1)
module:Undo()
assert(values.x == 0 and not button.enabled, "undo does not record itself")
mouse = true
for index = 1, 10 do
    values.x = index
    module:Sample()
end
mouse = false
module:Sample()
module:Undo()
assert(values.x == 0 and not button.enabled, "a drag becomes one undo step")
values.x, values.scale = 4, 3
module:Sample()
module:Undo()
assert(values.x == 0 and values.scale == 1, "one action restores all affected values")
for index = 1, 30 do
    values.x = index
    module:Sample()
end
for index = 1, 25 do
    module:Undo()
end
assert(values.x == 5 and not button.enabled, "history is capped at 25 actions")
values.x = 9
module:Sample()
locked = true
module:Undo()
assert(values.x == 9 and button.enabled, "unavailable undo retains the entry")
locked = false
fail = true
module:Undo()
assert(values.x == 9 and button.enabled)
fail = false
module:Undo()
assert(values.x == 5)
values.x, values.scale = 7, 2
module:Sample()
failKey = "x"
module:Undo()
assert(values.x == 7 and values.scale == 2 and button.enabled, "a partial undo rolls back the whole action")
failKey = nil
module:Undo()
assert(values.x == 5 and values.scale == 1)
values.x = 10
module:Sample()
combat = true
module:Undo()
assert(values.x == 10)
combat = false
callbacks.layout()
flush()
module:Undo()
assert(values.x == 10 and not button.enabled, "layout changes clear history")
local function shows(text)
    for _, obj in ipairs(objects) do
        if obj.text == text then
            return true
        end
    end
    return false
end
nativeInfo.anchorInfo.offsetX = 17
module:Sample()
assert(shows("Native: X"), "typing X names the field rather than calling it a drag")
module:Undo()
nativeInfo.anchorInfo.offsetY = 23
module:Sample()
assert(shows("Native: Y"))
module:Undo()
nativeInfo.anchorInfo.offsetX, nativeInfo.anchorInfo.offsetY = 5, 8
module:Sample()
module:Undo()
assert(
    nativeInfo.anchorInfo.offsetX == 5 and nativeInfo.anchorInfo.offsetY == 0,
    "non-drag X and Y changes undo separately"
)
module:Undo()
assert(nativeInfo.anchorInfo.offsetX == 0)
nativeInfo.anchorInfo.relativePoint = "TOP"
module:Sample()
assert(shows("Native: AnchorParent"))
module:Undo()
nativeInfo.settings[1].value = 150
module:Sample()
module:Undo()
assert(nativeInfo.settings[1].value == 100 and not native.dirty, "native undo preserves the saved baseline")
mouse = true
nativeInfo.anchorInfo.offsetX = 20
module:Sample()
nativeInfo.anchorInfo.offsetX = 40
nativeInfo.anchorInfo.offsetY = 15
module:Sample()
hooks[native].OnDragStop()
mouse = false
module:Sample()
assert(shows("Native: Dragged"), "only an actual drag gets the Dragged label")
module:Undo()
assert(nativeInfo.anchorInfo.offsetY == 0, "both drag axes undo in one step")
assert(nativeInfo.anchorInfo.offsetX == 0, "native dragging uses a copied pre-drag anchor")
local suitePosition = { x = 0, y = 0 }
local suiteSource = {
    frame = frame,
    key = "position",
    name = "Dragged",
    frameName = "Suite",
    dragVersion = 0,
    positionFields = { { key = "x", name = "X" }, { key = "y", name = "Y" } },
    get = function()
        return suitePosition
    end,
    set = function(value)
        suitePosition = value
    end,
}
sources[#sources + 1] = suiteSource
module:Sample(true)
suitePosition.x = 25
module:Sample()
assert(shows("Suite: X"), "suite X edits retain their field label")
module:Undo()
assert(suitePosition.x == 0)
mouse = true
suitePosition.x, suitePosition.y = 30, 40
module:Sample()
suiteSource.dragVersion = 1
mouse = false
module:Sample()
assert(shows("Suite: Dragged"))
module:Undo()
assert(suitePosition.x == 0 and suitePosition.y == 0)
values.x = 11
module:Sample()
module:OnProfileRefresh()
module:Undo()
assert(values.x == 11 and not button.enabled, "profile changes clear history")
editing = false
callbacks.exit()
flush()
assert(not SeamlessUIEditModeHistory.shown)
editing = true
callbacks.enter()
flush()
assert(SeamlessUIEditModeHistory.shown and not button.enabled)
app.db.profile.editModeHistory = false
module:OnProfileRefresh()
assert(not SeamlessUIEditModeHistory.shown and not module.enabled)
print("PASS: Edit Mode history, gestures, bounded undo, native drafts and lifecycle")

local refreshed = 0
app.optionPages = {}
app.core.GetOptionDefault = function() end
app.editModeKeyboard = {}
app.xpBarTooltip = {}
app.editModeHistory.OnProfileRefresh = function()
    refreshed = refreshed + 1
end
assert(loadfile("SeamlessUI/src/options/general.lua"))("SeamlessUI", app)
local general = app.optionPages.general
assert(general.defaults.profile.editModeHistory == true, "history defaults on")
general.config.args.editModeHistory.set(nil, true)
assert(app.db.profile.editModeHistory and refreshed == 1)
print("PASS: UI General history option defaults and lifecycle binding")
