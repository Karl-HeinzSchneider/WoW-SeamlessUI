-- Run from the repository root: lua src/tests/damage-meter-settings.lua
unpack = unpack or table.unpack
local root = "SeamlessDamageMeter/src/"
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("Seamless/lib/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
local registry = LibStub("AceConfigRegistry-3.0")
local app = {}
dofile("src/tests/locale-support.lua")
assert(loadfile(root .. "db.lua"))("SeamlessDamageMeter", app)
assert(loadfile(root .. "service.lua"))("SeamlessDamageMeter", app)
dofile("src/tests/locale-support.lua")
assert(loadfile(root .. "archive.lua"))("SeamlessDamageMeter", app)
dofile("src/tests/locale-support.lua")
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
UIParent = {
    GetWidth = function()
        return 1920
    end,
    GetHeight = function()
        return 1080
    end,
}
InCombatLockdown = function()
    return false
end
local coreApp = { addon = {} }
dofile("src/tests/locale-support.lua")
assert(loadfile("Seamless/src/config/position.lua"))("Seamless", coreApp)
-- Core strips its custom `default` key before AceConfig sees an option.
local function StripDefaults(option)
    option.default = nil
    for _, child in pairs(option.args or {}) do
        StripDefaults(child)
    end
end
app.core = {
    RefreshOptions = function() end,
    GetPositionOptions = function(_, spec)
        return coreApp.addon:GetPositionOptions(spec)
    end,
    RegisterOptions = function(_, name, spec)
        app.optionSpec = spec
        local args =
            { general = { type = "group", name = "General", args = spec.general }, windows = spec.tabs.windows }
        args.windows.type = "group"
        for key, tab in pairs(spec.tabs) do
            tab.type = "group"
            args[key] = tab
        end
        local root = { type = "group", name = "Test", args = args }
        StripDefaults(root)
        registry:ValidateOptionsTable(root, name)
    end,
}
dofile("src/tests/locale-support.lua")
assert(loadfile(root .. "options.lua"))("SeamlessDamageMeter", app)
app:RegisterOptions()
local refreshed = 0
app.RefreshWindows = function()
    refreshed = refreshed + 1
end
local favoriteLimit = app.optionSpec.general.windows.args.maxVisibleFavorites
favoriteLimit.set(nil, 3)
assert(favoriteLimit.get() == 3 and refreshed == 1 and app.db.profile.favorites[2] == "HealingDone")
local values = app.windowTabs.window2.args
local defaults = app.windowOptions.args
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
assert(app.skinOptions.args.default.args.remove == nil, "Default skin can't be deleted")
assert(app.skinOptions.args[skinID].args.remove)
fresh.skin = skinID
app.db.profile.skins[skinID].settings.textColor[1] = 0.25
assert(app.db.profile.skins.default.settings.textColor[1] == 1)
app.db.profile.skins[skinID].settings.rowHeight = 30
assert(app:GetWindowSetting(fresh, "rowHeight") == 30)
assert(app:GetWindowSetting(old, "rowHeight") == 24)
app:PrepareWindowSettings()
assert(fresh.skin == skinID and app:GetWindowSetting(fresh, "rowHeight") == 30)
assert(app:AddSkin("  ") == nil)
local removedID = app:AddSkin("Removed")
old.skin = removedID
app.skinOptions.args[removedID].args.remove.func()
assert(app.db.profile.skins[removedID] == nil and old.skin == "default")
assert(not app:RemoveSkin("default") and app.db.profile.skins.default)
-- Position and scale are the window's own values in the standard section, not overrides.
assert(values.x == nil and values.point == nil and values.scale == nil and defaults.x == nil)
local position = values.position.args
assert(old.position.x == 12.5 and old.position.y == -25 and old.overrides.x == nil, "Old offsets are migrated")
assert(fresh.position.point == "CENTER" and fresh.position.x == 0 and fresh.position.scale == 1)
position.x.set(nil, 40)
position.point.set(nil, "TOPLEFT")
position.scale.set(nil, 1.25)
assert(fresh.position.x == 40 and fresh.position.point == "TOPLEFT" and fresh.overrides.x == nil)
assert(app:GetWindowSetting(fresh, "scale") == 1.25 and position.scale.get() == 1.25)
assert(position.relativeTo.get() == "1" and position.relativeTo.values()["1"] == "Window 1")
assert(app.windowTabs.window1.args.position.args.relativeTo.values()["2"] == nil, "Circular anchors are excluded")
assert(not position.reset.disabled())
position.reset.func()
assert(fresh.position.x == 0 and fresh.position.point == "CENTER" and fresh.position.scale == 1.25)
assert(position.reset.disabled() and fresh.anchorTo == nil, "Reset to default clears offsets and anchor, not scale")
app.db.profile = { windows = {}, windowDefaults = copy(app.windowDefaults) }
app:BuildWindowOptions()
assert(#app.db.profile.windows == app.MAX_WINDOWS and app.MAX_WINDOWS == 6)
for id = 1, app.MAX_WINDOWS do
    local tab = app.optionSpec.tabs["window" .. id]
    assert(tab == app.windowTabs["window" .. id] and tab.name == "Window " .. id, "Every slot has its own tab")
    assert(tab.args.management.args.enabled.get() == (id == 1))
end
assert(app.optionSpec.tabs.window7 == nil and app.optionSpec.tabs.credits == nil)
assert(app:CanAnchorTo(app.db.profile.windows[1], 6), "Inactive windows must remain anchor targets")
local targets = app.windowTabs.window1.args.position.args.relativeTo.values()
assert(targets["6"] == "Window 6" and targets["7"] == nil)
local enabledDefault = app.optionSpec.tooltip({ "window1", "management", "enabled" })
assert(enabledDefault == true and app.optionSpec.tooltip({ "window2", "management", "enabled" }) == false)
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
assert(#app.db.profile.windows == 6 and #app.db.profile.legacyWindows == 6)
assert(app:GetUnusedWindowSlot() == nil)
-- Slots above the limit (from a profile made with more windows) are parked and come back.
app.db.profile = { windows = {}, fixedWindowSlots = true, windowDefaults = copy(app.windowDefaults) }
for id = 1, 10 do
    table.insert(
        app.db.profile.windows,
        { id = id, enabled = id == 8, overrides = {}, anchorTo = id == 2 and 9 or nil }
    )
end
app:PrepareWindowSettings()
assert(#app.db.profile.windows == 6 and app.db.profile.parkedWindows[8].enabled)
assert(not app:CanAnchorTo(app.db.profile.windows[2], 9), "Parked windows are not anchor targets")
app:PrepareWindowSettings()
assert(#app.db.profile.windows == 6 and app.db.profile.parkedWindows[10], "Parking must be idempotent")
app.MAX_WINDOWS = 10
app:PrepareWindowSettings()
assert(#app.db.profile.windows == 10 and app.db.profile.windows[8].enabled and app.db.profile.parkedWindows == nil)
app.MAX_WINDOWS = 6
print(
    "PASS: migration, inheritance, false overrides, independent colors, anchor cycles, numeric validation, profile switching and AceConfig schema"
)
