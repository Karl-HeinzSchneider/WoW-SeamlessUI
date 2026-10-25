-- The complete page contract, without AceConfigRegistry/AceConfigDialog or a game client.
unpack = unpack or table.unpack
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
local libs = {
    ["AceLocale-3.0"] = {
        GetLocale = function()
            return L
        end,
    },
    ["AceDBOptions-3.0"] = {
        GetOptionsTable = function()
            return { type = "group", name = "Profiles", args = {} }
        end,
    },
}
function LibStub(name)
    return assert(libs[name], "Unexpected library: " .. name)
end
local support = dofile("src/tests/settings-support.lua")
local coreApp = {
    addon = {},
    db = { RegisterCallback = function() end },
    logger = { level = { INFO = 1 } },
    defaultLayout = { LAYOUT_NAME = "Seamless" },
}
function coreApp.addon:NewModule(_, module)
    return module
end
for _, file in ipairs({
    "core/db.lua",
    "config/schema.lua",
    "config/registry.lua",
    "config/model.lua",
    "config/position.lua",
    "core/options.lua",
}) do
    assert(loadfile("Seamless/src/" .. file))("Seamless", coreApp)
end
support.pages("Seamless", coreApp)
coreApp.dbDefaults = coreApp.addon:GetOptionsDefaults(coreApp.optionPages, coreApp.dbDefaults)
coreApp.options:OnInitialize()
assert(coreApp.dbDefaults.profile.tweaks.reloadShortcut)
assert(coreApp.config.categories["Seamless:tweaks"].parent == "Seamless")
assert(coreApp.config.categories["Seamless:profiles"])
local core = coreApp.addon
function core:GetNativePositionOptions(getFrame, scale)
    return { type = "group", order = 10, name = "Position and scale", args = {}, getFrame = getFrame, scale = scale }
end
function core:GetNativeSettingScale(getFrame, setting)
    return { getFrame = getFrame, setting = setting }
end
function core:GetFramePositionService()
    return {
        ReadSetting = function()
            return 0
        end,
    }
end
function core:RegisterOptions(name, spec)
    coreApp.options:RegisterAddon(name, spec)
end
function core:RefreshOptions() end
function core:RegisterEditModeOptions() end
function InCombatLockdown()
    return false
end
function time()
    return 1
end
Enum = { EditModeUnitFrameSetting = { FrameSize = 1 }, EditModeCastBarSetting = { BarSize = 1, LockToPlayerFrame = 2 } }
Settings = {}
C_CVar = {
    GetCVar = function()
        return "1"
    end,
}
C_Item = { GetItemQualityColor = function() end }
local function noop() end
local function feature(key)
    return {
        featureName = key,
        featureDesc = key,
        GetOptionButtons = function()
            return {}
        end,
        Settings = function()
            return {}
        end,
        GetSettings = function()
            return {}
        end,
    }
end
local apps = {}
UIParent = {
    GetWidth = function()
        return 1920
    end,
    GetHeight = function()
        return 1080
    end,
}
for _, addon in ipairs({
    "SeamlessActionBars",
    "SeamlessCastbar",
    "SeamlessChat",
    "SeamlessDamageMeter",
    "SeamlessDarkmode",
    "SeamlessTooltip",
    "SeamlessUI",
    "SeamlessUnitframes",
}) do
    local modules = {}
    local app = { core = core, addon = {}, optionPages = {}, MAX_WINDOWS = 6 }
    function app.addon:NewModule(name, module)
        if type(module) ~= "table" then
            module = {}
        end
        modules[name] = module
        return module
    end
    function app.addon:GetModule(key)
        modules[key] = modules[key] or feature(key)
        return modules[key]
    end
    app.features = {
        GetModule = function(_, key)
            return app.addon:GetModule(key)
        end,
    }
    app.endCaps = { { key = "left", name = "Left endcap" }, { key = "right", name = "Right endcap" } }
    app.EndCapScale = function()
        return {}
    end
    app.EndCapHiddenOption = function()
        return { type = "toggle", name = "Hide" }
    end
    app.EndCapFrame = function() end
    app.MicroMenuOptions = function()
        return { type = "group", name = "Style", args = {} }
    end
    app.position = {
        GetOptions = function()
            return { type = "group", args = {} }
        end,
    }
    app.totPosition = app.position
    app.groups = { { key = "unitFrames", name = "Unit frames" } }
    app.media = {
        LSM = { MediaType = {} },
        Values = function()
            return {}
        end,
    }
    app.archive, app.combatService = { maxSegments = 1000 }, { saveSessions = false }
    app.addon.Refresh = noop
    app.fpsDisplay = {
        GetPositionBinding = function()
            return {}
        end,
    }
    app.blizzardEditMode = {
        GetOptionsFrames = function()
            return {}, {}
        end,
    }
    local file = (
        addon == "SeamlessChat"
        or addon == "SeamlessTooltip"
        or addon == "SeamlessUI"
        or addon == "SeamlessUnitframes"
    )
            and "core/db.lua"
        or "db.lua"
    assert(loadfile(addon .. "/src/" .. file))(addon, app)
    if addon == "SeamlessUnitframes" then
        assert(loadfile(addon .. "/src/core/unitframes.lua"))(addon, app)
    end
    support.pages(addon, app)
    app.dbDefaults = core:GetOptionsDefaults(app.optionPages, app.dbDefaults)
    app.db = { profile = app.dbDefaults.profile }
    if addon == "SeamlessDamageMeter" then
        app.PrepareWindowSettings, app.BuildWindowOptions, app.BuildSkinOptions = noop, noop, noop
        app.MAX_WINDOWS = 6
        app:RegisterOptions()
    else
        modules.Options:OnInitialize()
    end
    for key, page in pairs(app.optionPages) do
        assert(page.config.type == "group" and type(page.config.args) == "table", addon .. ":" .. key)
        assert(coreApp.config.categories[addon .. ":" .. key], "Missing page " .. key)
    end
    apps[addon] = app
end
local cast = apps.SeamlessCastbar
-- The actual shared position builder must load before a feature's database exists.
-- Its bounds are resolved later and follow the current profile, including off-screen offsets.
local meter = apps.SeamlessDamageMeter
function meter:GetWindowSetting(config, key)
    return config.position[key]
end
meter.db.profile.windows[1] = { position = { x = 2500, y = -1400 } }
local position = core:GetSettingsOption(
    coreApp.options.panels.SeamlessDamageMeter.options,
    { "window1", "position", "x" },
    "SeamlessDamageMeter"
)
assert(position:Read("min") == -2500 and position:Read("max") == 2500)
local vertical = core:GetSettingsOption(
    coreApp.options.panels.SeamlessDamageMeter.options,
    { "window1", "position", "y" },
    "SeamlessDamageMeter"
)
assert(vertical:Read("min") == -1400 and vertical:Read("max") == 1400)
meter.db.profile = { windows = { { position = { x = -3500, y = 40 } } } }
assert(position:Read("min") == -3500 and position:Read("max") == 3500)
assert(vertical:Read("min") == -1080 and vertical:Read("max") == 1080)
assert(cast.optionPages.player.defaults.profile.player.icon.enabled)
assert(not cast.optionPages.target.defaults.profile.target.icon)
assert(cast.optionPages.player.config.args.rank.type == "toggle")
assert(cast.optionPages.player.config.args.castTime.args.enabled)
assert(cast.optionPages.player.config.args.hold.args.success.max == 3)
cast.db.profile.player = { enabled = true, rank = { enabled = true } }
local rank =
    core:GetSettingsOption(coreApp.options.panels.SeamlessCastbar.options, { "player", "rank" }, "SeamlessCastbar")
rank:Read("set", false)
assert(not rank:Read("get") and not rank:Read("disabled"), "A disabled feature can be enabled again")
rank:Read("set", true)
assert(rank:Read("get"))
cast.db.profile.player = { enabled = false, rank = { enabled = true } }
assert(rank:Read("disabled"), "Bar enable state guards its feature switches")
assert(coreApp.config.categories.SeamlessTooltip.header)
assert(coreApp.config.categories["SeamlessTooltip:units"])
assert(apps.SeamlessChat.dbDefaults.profile.features.timestamps.format == "%H:%M:%S")
assert(apps.SeamlessChat.dbDefaults.profile.sync.windows)
assert(apps.SeamlessTooltip.dbDefaults.profile.features.Backdrop.backgroundColor.r == 0.09)
assert(apps.SeamlessUnitframes.dbDefaults.profile.unitFrames.player.healthBarColor == "class")

-- Metadata survives registration and refresh; changes are deferred past widget callbacks.
local profile = { enabled = true, color = { r = 1, g = 0, b = 0 } }
local changes = 0
local tagged = {
    type = "group",
    feature = true,
    new = true,
    blizzard = true,
    editMode = true,
    name = "Feature",
    settings = function()
        return profile
    end,
    toggled = function()
        changes = changes + 1
    end,
    args = { color = { type = "color", name = "Color", default = false } },
}
coreApp.options:RegisterAddon("Test", {
    title = "Test",
    pages = {
        general = { defaults = {}, config = { type = "group", name = "General", args = { tagged = tagged } } },
    },
})
assert(tagged.new and tagged.blizzard and tagged.editMode and tagged.args.color.default == false)
core:PrepareSettingsOptions(tagged) -- Repeated preparation must not duplicate the Enable row.
local tree = coreApp.options.panels.Test.options
local enabled = core:GetSettingsOption(tree, { "general", "tagged", "enabled" }, "Test")
enabled:Read("set", false)
assert(not profile.enabled and changes == 1)
profile = { enabled = true, color = { r = 0, g = 1, b = 0 } }
assert(enabled:Read("get"), "Getters follow the current profile")
local color = core:GetSettingsOption(tree, { "general", "tagged", "color" }, "Test")
assert(color:InEditModeLayout() and color:Read("default") == false)
color:Read("set", 0.2, 0.3, 0.4)
assert(profile.color.r == 0.2 and profile.color.b == 0.4)
local refreshed = 0
function coreApp.config:CreateOptionsPage() end
function coreApp.config:RefreshOptionsPage()
    refreshed = refreshed + 1
end
local page = {
    SetScript = function(self, _, fn)
        self.update = fn
    end,
}
coreApp.config.categories["Test:general"].create(page)
coreApp.config.pages["Test:general"] = page
coreApp.options:Refresh("Test")
assert(refreshed == 0)
page.update()
assert(refreshed == 1)
coreApp.options:Refresh("Seamless")
page.update()
assert(refreshed == 1)
local ok = pcall(function()
    core:GetOptionsDefaults({
        one = { defaults = { profile = { value = 1 } }, config = {} },
        two = { defaults = { profile = { value = 2 } }, config = {} },
    })
end)
assert(not ok, "Conflicting defaults must fail before AceDB starts")
print("All addon page declarations, defaults, profile bindings, metadata and deferred refresh OK")
