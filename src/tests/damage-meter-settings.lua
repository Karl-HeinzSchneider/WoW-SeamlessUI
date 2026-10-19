-- Run from the repository root: lua src/tests/damage-meter-settings.lua
unpack = unpack or table.unpack
local root = "SeamlessDamageMeter/src/"
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("Seamless/lib/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
local registry = LibStub("AceConfigRegistry-3.0")
local app = {}
assert(loadfile(root .. "service.lua"))("SeamlessDamageMeter", app)
assert(loadfile(root .. "archive.lua"))("SeamlessDamageMeter", app)
assert(loadfile(root .. "settings.lua"))("SeamlessDamageMeter", app)
local function copy(t)
    local result = {}
    for k, v in pairs(t) do
        result[k] = type(v) == "table" and copy(v) or v
    end
    return result
end
local old = { id = 1, width = 450, height = 230, x = 12.5, y = -25, favorites = { "Dps" } }
local fresh = { id = 2, overrides = {}, favorites = { "DamageDone", "HealingDone" } }
app.db = { profile = { windows = { old, fresh }, windowDefaults = copy(app.windowDefaults) } }
app.db.profile.windowDefaults.fontSize = 15
app.db.profile.windowDefaults.font = "Friz Quadrata TT"
old.overrides = { classColors = false, textColor = { 0.2, 0.3, 0.4, 1 } }
app:PrepareWindowSettings()
assert(app:GetWindowSetting(fresh, "font") == "Default damage meter")
assert(fresh.skin == "default" and old.skin ~= "default")
assert(app:GetWindowSetting(fresh, "fontSize") == 15)
assert(app:GetWindowSetting(old, "classColors") == false)
assert(app:GetWindowSetting(old, "textColor")[1] == 0.2)
assert(old.overrides.classColors == nil and app.db.profile.windowDefaults.fontSize == nil)
app.db.profile.skins.default.settings.font = "Friz Quadrata TT"
app:PrepareWindowSettings()
assert(app:GetWindowSetting(fresh, "font") == "Friz Quadrata TT", "Later font choices survive repeated preparation")
assert(app:GetWindowSetting(old, "classColors") == false)
assert(app.db.profile.maxVisibleFavorites == 6)
assert(app.db.profile.favorites[1] == "Dps" and app.db.profile.favorites[2] == "HealingDone")
assert(old.favorites == nil and fresh.favorites == nil)
assert(old.width == nil and old.overrides.width == 450)
assert(app:GetWindowSetting(fresh, "width") == 400)
app.db.profile.windowDefaults.width = 500
assert(app:GetWindowSetting(fresh, "width") == 500)
assert(app:GetWindowSetting(old, "width") == 450)
app.db.profile.skins.default.settings.classColors = false
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
    RefreshOptions = function() end,
    RegisterOptions = function(_, name, spec)
        app.optionSpec = spec
        local args =
            { general = { type = "group", name = "General", args = spec.general }, windows = spec.tabs.windows }
        args.windows.type = "group"
        for key, tab in pairs(spec.tabs) do
            tab.type = "group"
            args[key] = tab
        end
        registry:ValidateOptionsTable({ type = "group", name = "Test", args = args }, name)
    end,
}
assert(loadfile(root .. "options.lua"))("SeamlessDamageMeter", app)
app:RegisterOptions()
local refreshed = 0
app.RefreshWindows = function()
    refreshed = refreshed + 1
end
local favoriteLimit = app.optionSpec.general.windows.args.maxVisibleFavorites
favoriteLimit.set(nil, 3)
assert(favoriteLimit.get() == 3 and refreshed == 1 and app.db.profile.favorites[2] == "HealingDone")
local values = app.windowOptions.args.window2.args
local defaults = app.windowOptions.args.defaults.args
assert(defaults.fixedHeight.get() == true and defaults.visibleLines.get() == 7)
assert(defaults.visibleLines.step == 0.25 and defaults.showResizeHandle.get() == true)
fresh.overrides.fixedHeight = true
for _, lines in ipairs({ 7, 7.25, 7.5, 7.75 }) do
    fresh.overrides.visibleLines = lines
    assert(app:GetWindowSetting(fresh, "height") == 40 + lines * 28 - 4)
end
app.db.profile.skins.default.settings.rowHeight, app.db.profile.skins.default.settings.rowSpacing = 20, 2
assert(app:GetWindowSetting(fresh, "height") == 40 + 7.75 * 22 - 2)
fresh.overrides.fixedHeight = false
assert(app:GetWindowSetting(fresh, "height") == app.db.profile.windowDefaults.height)
fresh.overrides.fixedHeight, fresh.overrides.visibleLines = nil, nil
app.db.profile.skins.default.settings.rowHeight, app.db.profile.skins.default.settings.rowSpacing = 24, 4
app.RebuildWindows = function() end
local skinControls = app.skinOptions.args.default.args
assert(values.classColors == nil and defaults.fontSize == nil)
skinControls.classColors.set(nil, false)
assert(app:GetWindowSetting(fresh, "classColors") == false)
local skinID = app:AddSkin("Custom")
fresh.skin = skinID
app.db.profile.skins[skinID].settings.textColor[1] = 0.25
assert(app.db.profile.skins.default.settings.textColor[1] == 1)
app.db.profile.skins[skinID].settings.rowHeight = 30
assert(app:GetWindowSetting(fresh, "rowHeight") == 30)
assert(app:GetWindowSetting(old, "rowHeight") == 24)
app:PrepareWindowSettings()
assert(fresh.skin == skinID and app:GetWindowSetting(fresh, "rowHeight") == 30)
assert(app:AddSkin("  ") == nil)
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
assert(
    highID.anchorTo == 3
        and existing.anchorTo == 2
        and app:GetWindowSetting(highID, "fontSize") == 19
        and highID.overrides.fontSize == nil
)
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
