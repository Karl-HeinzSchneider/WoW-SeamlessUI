-- Existing option registrations feed both the native panels and custom pages.
local app = { addon = {}, logger = {} }
local tables, callbacks, timers, opened = {}, {}, {}, {}
local registry = {}
function registry:RegisterOptionsTable(name, options)
    tables[name] = options
end
function registry.RegisterCallback(owner, event, callback)
    callbacks[event] = { owner, callback }
end
function registry:NotifyChange(name)
    local callback = callbacks.ConfigTableChange
    callback[2]("ConfigTableChange", name)
end
local dialog = {}
function dialog:AddToBlizOptions(name)
    return {}, name
end
function dialog:Open(name, widget, key)
    opened[#opened + 1] = { name, widget, key }
    assert(tables[name].args[key])
end
local function frame()
    return {
        SetParent = function(self, parent)
            self.parent = parent
        end,
        SetFrameStrata = function(self, strata)
            self.strata = strata
        end,
        SetFrameLevel = function(self, level)
            self.level = level
        end,
        ClearAllPoints = function() end,
        SetPoint = function() end,
        HookScript = function(self, event, callback)
            self[event] = callback
        end,
    }
end
local created = 0
local gui = {}
function gui:Create(kind)
    assert(kind == "SimpleGroup")
    created = created + 1
    return {
        frame = frame(),
        SetWidth = function(self, width)
            self.width = width
        end,
    }
end
local libs = {
    ["AceConfigRegistry-3.0"] = registry,
    ["AceConfigDialog-3.0"] = dialog,
    ["AceGUI-3.0"] = gui,
    ["AceDBOptions-3.0"] = {
        GetOptionsTable = function(_, db)
            return { type = "group", name = "Profiles", args = {}, db = db }
        end,
    },
    ["AceLocale-3.0"] = {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    },
}
function LibStub(name)
    return assert(libs[name], name)
end
function app.addon:NewModule(_, module)
    return module
end
C_Timer = {
    After = function(_, callback)
        timers[#timers + 1] = callback
    end,
}
assert(loadfile("Seamless/src/config/registry.lua"))("Seamless", app)
assert(loadfile("Seamless/src/config/options.lua"))("Seamless", app)
assert(loadfile("Seamless/src/core/options.lua"))("Seamless", app)
local options, config = app.options, app.config
options.panels, options.addons, options.addonButtons = {}, {}, {}
local profileCallbacks = {}
local db = {
    RegisterCallback = function(_, event, callback)
        if event == "OnProfileChanged" then
            profileCallbacks[#profileCallbacks + 1] = callback
        end
    end,
}
options:Register("Seamless", { title = "Seamless", general = {}, db = db })
options:Register("SeamlessTweaks", { title = "Tweaks", general = {}, db = db }, "Seamless")
local absent = false
local value = false
local general = {
    enabled = {
        type = "toggle",
        name = "Enable",
        get = function()
            return value
        end,
        set = function(_, nextValue)
            value = nextValue
        end,
    },
}
options:RegisterAddon("Frames", {
    title = "Unit Frames",
    general = general,
    db = db,
    tabs = {
        player = { name = "Player frame", order = 10, args = {} },
        target = {
            name = "Target frame",
            order = 20,
            args = {},
            hidden = function(info)
                assert(info.appName == "Frames" and info[1] == "target" and info.option == tables.Frames.args.target)
                return absent
            end,
        },
    },
})
assert(tables.Frames.args.general.args == general) -- One set of live settings/accessors.
assert(config.categories.Frames.header and config.categories.Frames.name == "Unit Frames")
assert(config.categories["Frames:player"].parent == "Frames")
assert(config.categories["Frames:target"].parent == "Frames")
assert(config.categories["Frames:profiles"].order == 1000)
assert(config.categories["Seamless:tweaks"].parent == "Seamless")
assert(not config.categories.SeamlessTweaks) -- No extra addon header for a Core panel.
local children = config:GetChildren("Frames")
assert(children[1].id == "Frames:general" and children[2].id == "Frames:player")
assert(children[3].id == "Frames:target" and children[4].id == "Frames:profiles")
absent = true
for _, entry in ipairs(config:GetVisibleCategories()) do
    assert(entry.category.id ~= "Frames:target")
end
absent = false
local category = config.categories["Frames:general"]
local page = {
    GetWidth = function()
        return 627
    end,
    GetFrameLevel = function()
        return 5
    end,
    SetHeight = function(self, height)
        self.height = height
    end,
}
category.create(page)
assert(created == 1 and page.optionsWidget.width == 627)
assert(page.optionsWidget.frame.parent == page and page.optionsWidget.frame.level == 6)
assert(page.optionsWidget.frame.strata == "HIGH")
page.optionsWidget.frame.OnSizeChanged(page.optionsWidget.frame, 627, 800)
assert(page.height == 800)
category.refresh(page)
category.refresh(page)
assert(created == 1 and #opened == 2 and opened[2][1] == "Frames" and opened[2][3] == "general")
general.enabled.set(nil, true)
assert(tables.Frames.args.general.args.enabled.get())
local shown, refreshed = true, 0
config.frame = {
    IsShown = function()
        return shown
    end,
}
function config:Refresh()
    refreshed = refreshed + 1
end
registry:NotifyChange("Frames")
registry:NotifyChange("Frames")
assert(#timers == 1 and refreshed == 0) -- Coalesced, after the control callback.
timers[1]()
assert(refreshed == 1)
shown = false
registry:NotifyChange("Frames")
assert(#timers == 1)
shown = true
registry:NotifyChange("Unrelated")
assert(#timers == 1)
options:Refresh("Frames")
assert(#timers == 2)
timers[2]()
assert(refreshed == 2)
profileCallbacks[#profileCallbacks]()
assert(#timers == 3)
timers[3]()
assert(refreshed == 3)
print("Config options integration OK")
