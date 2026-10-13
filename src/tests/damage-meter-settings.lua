-- Run from the repository root: lua src/tests/damage-meter-settings.lua
unpack = unpack or table.unpack
local root = "SeamlessDamageMeter/src/"
dofile("SeamlessCore/lib/LibStub/LibStub.lua")
dofile("SeamlessCore/lib/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("SeamlessCore/lib/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
local registry = LibStub("AceConfigRegistry-3.0")
local app = {}
assert(loadfile(root .. "settings.lua"))("SeamlessDamageMeter", app)
local function copy(t)
    local result = {}
    for k, v in pairs(t) do
        result[k] = type(v) == "table" and copy(v) or v
    end
    return result
end
local old = { id = 1, width = 450, height = 230, x = 12.5, y = -25 }
local fresh = { id = 2, overrides = {} }
app.db = { profile = { windows = { old, fresh }, windowDefaults = copy(app.windowDefaults) } }
app:PrepareWindowSettings()
assert(old.width == nil and old.overrides.width == 450)
assert(app:GetWindowSetting(fresh, "width") == 400)
app.db.profile.windowDefaults.width = 500
assert(app:GetWindowSetting(fresh, "width") == 500)
assert(app:GetWindowSetting(old, "width") == 450)
fresh.overrides.classColors = false
assert(app:GetWindowSetting(fresh, "classColors") == false)
assert(app:CanAnchorTo(old, 2))
fresh.anchorTo = 1
assert(not app:CanAnchorTo(old, 2))
assert(not app:CanAnchorTo(old, 1))
assert(not app:CanAnchorTo(old, 99))
C_CVar = {
    GetCVar = function()
        return "1"
    end,
}
app.core = {
    RegisterOptions = function(_, name, spec)
        local args =
            { general = { type = "group", name = "General", args = spec.general }, windows = spec.tabs.windows }
        args.windows.type = "group"
        registry:ValidateOptionsTable({ type = "group", name = "Test", args = args }, name)
    end,
}
assert(loadfile(root .. "options.lua"))("SeamlessDamageMeter", app)
app:RegisterOptions()
local values = app.windowOptions.args.window2.args
local defaults = app.windowOptions.args.defaults.args
app.RebuildWindows = function() end
app.db.profile.windowDefaults.classColors = false
assert(defaults.classColors.get() == false)
assert(values.classColors.args.default.get() == false)
values.classColors.args.override.set(nil, true)
assert(fresh.overrides.classColors == false)
values.classColors.args.override.set(nil, false)
assert(fresh.overrides.classColors == nil)
values.textColor.args.override.set(nil, true)
fresh.overrides.textColor[1] = 0.25
assert(app.db.profile.windowDefaults.textColor[1] == 1)
assert(values.x.args.value.validate(nil, "12.125") == true)
assert(type(values.x.args.value.validate(nil, "no")) == "string")
app.db.profile = { windows = {}, windowDefaults = copy(app.windowDefaults) }
app:BuildWindowOptions()
assert(app.windowOptions.args.window1.name == "Window 1")
for id = 2, 10 do
    local group = app.windowOptions.args["window" .. id]
    assert(group and group.name == "|cff808080Window " .. id .. "|r")
    assert(not group.disabled, "Inactive settings must remain editable")
end
assert(app:CanAnchorTo(app.db.profile.windows[1], 10), "Inactive windows must remain anchor targets")
local targets = app.windowOptions.args.window1.args.management.args.anchorTo.values()
assert(targets["10"] == "Window 10")
app.db.profile.windows[10].enabled = true
app:BuildWindowOptions()
assert(app.windowOptions.args.window10.name == "Window 10")
app.db.profile.windows[10].hidden = true
app:BuildWindowOptions()
assert(app.windowOptions.args.window10.name == "|cff808080Window 10|r")
assert(defaults.width.get() == 400)
local highID = { id = 18, anchorTo = 27, overrides = { fontSize = 19 } }
local anchor = { id = 27, overrides = {} }
local existing = { id = 1, anchorTo = 18, overrides = {} }
app.db.profile = { windows = { highID, existing, anchor }, nextID = 28, windowDefaults = copy(app.windowDefaults) }
app:PrepareWindowSettings()
assert(existing.id == 1 and highID.id == 2 and anchor.id == 3)
assert(highID.anchorTo == 3 and existing.anchorTo == 2 and highID.overrides.fontSize == 19)
assert(app.db.profile.nextID == nil and app.db.profile.fixedWindowSlots)
assert(app:GetUnusedWindowSlot() == 4)
app:PrepareWindowSettings()
assert(highID.id == 2 and highID.anchorTo == 3, "Migration must be idempotent")
app.db.profile = { windows = {}, windowDefaults = copy(app.windowDefaults) }
for id = 1, 12 do
    table.insert(app.db.profile.windows, { id = id + 20, overrides = {} })
end
app:PrepareWindowSettings()
assert(#app.db.profile.windows == 10 and #app.db.profile.legacyWindows == 2)
assert(app:GetUnusedWindowSlot() == nil)
print(
    "PASS: migration, inheritance, false overrides, independent colors, anchor cycles, numeric validation, profile switching and AceConfig schema"
)
