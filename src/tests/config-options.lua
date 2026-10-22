-- Shared options keep their original AceConfig paths inside the custom shell.
dofile("Seamless/lib/LibStub/LibStub.lua")
dofile("Seamless/lib/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("Seamless/lib/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
local realRegistry = LibStub("AceConfigRegistry-3.0")
local callbacks, tables, opens = {}, {}, {}
local registry = {
    RegisterCallback = function(owner, _, callback)
        callbacks[owner] = callback
    end,
    RegisterOptionsTable = function(_, name, options)
        tables[name] = options
        realRegistry:RegisterOptionsTable(name, options)
    end,
    NotifyChange = function(_, name)
        for _, callback in pairs(callbacks) do
            callback("ConfigTableChange", name)
        end
    end,
}
local dialog = {
    AddToBlizOptions = function(_, name)
        return {}, name
    end,
    Open = function()
        error("Custom config must not use AceConfigDialog rendering")
    end,
}
function registry:GetOptionsTable(name, uiType, uiName)
    return realRegistry:GetOptionsTable(name, uiType, uiName)
end
local libraries = {
    ["AceLocale-3.0"] = {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    },
    ["AceConfigRegistry-3.0"] = registry,
    ["AceConfigDialog-3.0"] = dialog,
    ["AceDBOptions-3.0"] = {
        GetOptionsTable = function()
            return { type = "group", name = "Profiles", args = {} }
        end,
    },
}
function LibStub(name)
    return assert(libraries[name], name)
end
local app = { addon = {}, db = { RegisterCallback = function() end } }
function app.addon:NewModule(_, module)
    return module
end
assert(loadfile("Seamless/src/config/registry.lua"))("Seamless", app)
assert(loadfile("Seamless/src/config/model.lua"))("Seamless", app)
assert(
    app.addon:GetOptionDefault({ frames = { ["*"] = { enabled = false } } }, { "frames", "player", "enabled" }) == false
)
C_CVar = {
    GetCVarInfo = function()
        return "0", "1", false, true
    end,
}
assert(
    app.addon:GetOptionDefault(
        { frames = { ["**"] = { enabled = false }, player = { color = "class" } } },
        { "frames", "player", "enabled" }
    ) == false
)
local cvarDefault, character = app.addon:GetCVarOptionInfo("test")
assert(cvarDefault == true and character == true)
function app.config:CreateOptionsPage(page, root, key, name)
    page.option = self.Option:New(root, { key }, name)
end
function app.config:RefreshOptionsPage(page)
    opens[#opens + 1] = { page.option.appName, page.option.path[1] }
end
assert(loadfile("Seamless/src/core/options.lua"))("Seamless", app)
local options = app.options
options.panels, options.addons, options.addonButtons = {}, {}, {}
options:Register("Seamless", { title = "Seamless", general = {} })
options:Register("SeamlessTweaks", { title = "Tweaks", general = {} })
assert(app.config.categories["SeamlessTweaks:general"].parent == "Seamless")
assert(app.config.categories["SeamlessTweaks:general"].name == "Tweaks")
assert(not app.config.categories.SeamlessTweaks)
options:RegisterAddon("Unitframes", {
    title = "Unit frames",
    general = {},
    tabs = {
        player = {
            name = "PlayerFrame",
            order = 10,
            new = true,
            blizzard = true,
            args = {
                tagged = { type = "toggle", name = "Tagged", new = true, default = true },
            },
        },
        target = { name = "TargetFrame", order = 20, args = {} },
        missing = {
            name = "Missing",
            order = 30,
            args = {},
            hidden = function()
                return true
            end,
        },
    },
})
local config = app.config
assert(config.categories.Unitframes.header)
local children = config:GetChildren("Unitframes")
assert(#children == 3)
assert(children[1].id == "Unitframes:general")
assert(children[2].id == "Unitframes:player")
assert(children[3].id == "Unitframes:target")
assert(children[2].new and children[2].blizzard)
local playerTab = tables.Unitframes.args.player
assert(playerTab.new == nil and playerTab.blizzard == nil)
assert(playerTab.args.tagged.new == nil)
assert(config:GetOptionTags(playerTab.args.tagged).new)
assert(playerTab.args.tagged.default == nil, "AceConfig never sees our default key")
assert(config:GetOptionTags(playerTab.args.tagged).default == true)
assert(config.Option:New(tables.Unitframes, { "player", "tagged" }, "Unitframes"):Read("new"))
assert(config.categories["Seamless:profiles"] and not config.categories["Unitframes:profiles"])
local page = {}
function page:GetWidth()
    return 627
end
function page:SetHeight(height)
    self.height = height
end
function page:SetScript(_, callback)
    self.update = callback
end
children[2].create(page)
children[2].refresh(page)
assert(page.option.root == tables.Unitframes)
assert(opens[1][1] == "Unitframes" and opens[1][2] == "player")
options:Refresh("Unitframes")
assert(#opens == 1) -- Do not release widgets during their own callbacks.
page.update()
assert(#opens == 2 and opens[2][2] == "player")
options:Refresh("Seamless")
page.update()
assert(#opens == 2)
function app.addon:OpenConfig(id)
    self.opened = id
end
options:Open("Unitframes", "target")
assert(app.addon.opened == "Unitframes:target")
options:Open("Unitframes")
assert(app.addon.opened == "Unitframes:general")
print("Config options OK")

-- The shared declaration must be simple in both the custom and native panels.
local settings, toggles = { enabled = true }, 0
local switch = options.FeatureGroup({
    name = "Short keybind labels",
    settings = function()
        return settings
    end,
    toggled = function()
        toggles = toggles + 1
    end,
})
assert(switch.type == "toggle" and switch.name == "Short keybind labels" and not switch.args)
switch.set({ "general", "keybinds" }, false)
assert(not settings.enabled and toggles == 1 and not switch.disabled())
settings = { enabled = true }
assert(switch.get())
local castOptions, castSpec
local cast = {
    core = {
        GetOptionDefault = app.addon.GetOptionDefault,
        FeatureGroup = options.FeatureGroup,
        RegisterOptions = function(_, _, spec)
            castSpec = spec
        end,
    },
    addon = {
        NewModule = function()
            castOptions = {}
            return castOptions
        end,
        Refresh = function()
            toggles = toggles + 1
        end,
    },
    db = { profile = { player = { enabled = true, rank = { enabled = true } } } },
}
assert(loadfile("SeamlessCastbar/src/options.lua"))("SeamlessCastbar", cast)
assert(loadfile("SeamlessCastbar/src/db.lua"))("SeamlessCastbar", cast)
castOptions:OnInitialize()
for _, key in ipairs({ "rank", "ticks", "icon" }) do
    local option = castSpec.tabs.player.args[key]
    assert(option.type == "toggle" and option.name ~= "Enable" and not option.args)
end
assert(castSpec.tabs.player.args.castTime.type == "group")
assert(castSpec.tabs.player.args.hold.type == "group")
assert(castSpec.tooltip({ "player", "rank" }) == true)
assert(castSpec.tooltip({ "player", "hold", "enabled" }) == false)
assert(castSpec.tooltip({ "player", "hold", "success" }) == 0.2)
local rank = castSpec.tabs.player.args.rank
rank.set(nil, false)
assert(not cast.db.profile.player.rank.enabled and not rank.disabled({ "player", "rank" }))
cast.db.profile.player.enabled = false
assert(rank.disabled({ "player", "rank" }))
print("Standalone feature options OK")
playerTab.args.tagged.new = false
playerTab.args.tagged.blizzard = true
options:Refresh("Unitframes")
assert(not config:GetOptionTags(playerTab.args.tagged).new)
assert(config:GetOptionTags(playerTab.args.tagged).blizzard)
assert(playerTab.args.tagged.new == nil and playerTab.args.tagged.blizzard == nil)
realRegistry:GetOptionsTable("Unitframes", "dialog", "SeamlessConfig-1.0")
print("Feature tag metadata and AceConfig compatibility OK")
