-- Shared options keep their original AceConfig paths inside the custom shell.
local callbacks, tables, opens = {}, {}, {}
local registry = {
    RegisterCallback = function(owner, _, callback)
        callbacks[owner] = callback
    end,
    RegisterOptionsTable = function(_, name, options)
        tables[name] = options
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
function registry:GetOptionsTable(name)
    return tables[name]
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
        player = { name = "PlayerFrame", order = 10, args = {} },
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
