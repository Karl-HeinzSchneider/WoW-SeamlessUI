---@type string, SeamlessCore
local appName, app = ...

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

-- Every Seamless addon's panel is an AceConfig table of tabs: General first, the addon's own tabs
-- in between, Profiles last. Core's panel is the suite's entry in Settings > AddOns; the feature
-- addons' panels are its children.
local GENERAL_ORDER, PROFILES_ORDER = 0, 1000

local PROFILE_EVENTS = { "OnProfileChanged", "OnProfileCopied", "OnProfileReset", "OnProfileDeleted", "OnNewProfile" }

---@class SeamlessCore.OptionsSpec
---@field title string The panel's name in the AddOns list and its heading.
---@field general table<string, table> AceConfig args of the General tab.
---@field tabs? table<string, table> The addon's own tabs: AceConfig groups by key, `order` 1 to 999.
---@field db? AceDBObject-3.0 Adds the Profiles tab for this database.

---@class SeamlessCore.OptionsPanel
---@field title string
---@field id any Settings category ID.

---@class SeamlessCore.Options : AceModule
---@field panels table<string, SeamlessCore.OptionsPanel>
---@field addons string[] Feature addons with a panel, in registration order.
---@field addonButtons table<string, table> Args of the Addons group on Core's General tab.
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessCore.Options]]

---@param name string AceConfig app name: the addon's folder name.
---@param spec SeamlessCore.OptionsSpec
---@param parent? any Settings category ID of the parent panel.
function module:Register(name, spec, parent)
    assert(not self.panels[name], "Duplicate Seamless options: " .. name)
    local args = {
        general = { type = "group", name = "General", order = GENERAL_ORDER, args = spec.general },
    }
    for key, tab in pairs(spec.tabs or {}) do
        assert(not args[key] and key ~= "profiles", "Reserved Seamless options tab: " .. key)
        assert(tab.order and tab.order > GENERAL_ORDER and tab.order < PROFILES_ORDER, "Tab order 1-999: " .. key)
        tab.type = "group"
        args[key] = tab
    end
    if spec.db then
        local profiles = AceDBOptions:GetOptionsTable(spec.db)
        profiles.order = PROFILES_ORDER
        args.profiles = profiles
        -- Covers profile changes from slash commands and other panels too.
        for _, event in ipairs(PROFILE_EVENTS) do
            spec.db.RegisterCallback(args, event, function()
                self:Refresh(name)
            end)
        end
    end
    AceConfigRegistry:RegisterOptionsTable(
        name,
        { type = "group", name = spec.title, childGroups = "tab", args = args }
    )
    local _, id = AceConfigDialog:AddToBlizOptions(name, spec.title, parent)
    self.panels[name] = { title = spec.title, id = id }
end

-- Opens the native Settings window on `name`'s panel (Core's when nil), on one of its tabs if given.
---@param name? string
---@param tab? string
function module:Open(name, tab)
    name = name or appName
    local panel = self.panels[name]
    if not panel then
        return
    end
    if tab then
        AceConfigDialog:SelectGroup(name, tab)
    end
    Settings.OpenToCategory(panel.id)
end

-- Redraws `name`'s panel (Core's when nil) after a change made outside of it.
---@param name? string
function module:Refresh(name)
    AceConfigRegistry:NotifyChange(name or appName)
end

---@class SeamlessCore.FeatureSpec
---@field name string Section heading.
---@field desc string What the feature does, shown under its Enable switch.
---@field order? number
---@field options? table<string, table> AceConfig args; each key is the setting it stores.
---@field settings fun(): table The current profile's settings table; `enabled` is the switch.
---@field toggled fun() After `enabled` changed.
---@field changed? fun() After another setting changed.

-- One switchable feature as an inline section: its Enable switch, then its options, which read and
-- write `settings()[key]` (colors as { r, g, b, a }) unless they bring their own get/set, and are
-- disabled while the feature is off unless they bring their own `disabled`.
---@param spec SeamlessCore.FeatureSpec
---@return table
function module.FeatureGroup(spec)
    local args = {
        enabled = {
            type = "toggle",
            order = 0,
            width = "full",
            name = "Enable",
            desc = spec.desc,
            descStyle = "inline",
        },
    }
    for key, option in pairs(spec.options or {}) do
        assert(key ~= "enabled", "Feature options must not redefine enabled")
        args[key] = option
    end
    return {
        type = "group",
        inline = true,
        order = spec.order,
        name = spec.name,
        args = args,
        get = function(info)
            local value = spec.settings()[info[#info]]
            if info.type == "color" then
                return value.r, value.g, value.b, value.a
            end
            return value
        end,
        set = function(info, value, g, b, a)
            local key, settings = info[#info], spec.settings()
            if info.type == "color" then
                local color = settings[key]
                color.r, color.g, color.b = value, g, b
                if info.option.hasAlpha then
                    color.a = a
                end
            else
                settings[key] = value
            end
            if key == "enabled" then
                spec.toggled()
            elseif spec.changed then
                spec.changed()
            end
        end,
        disabled = function(info)
            return info[#info] ~= "enabled" and not spec.settings().enabled
        end,
    }
end
-- Public as `core.FeatureGroup(spec)`.
app.addon.FeatureGroup = module.FeatureGroup

-- The log levels by severity, for a select.
local function LogLevels()
    local values, sorting = {}, {}
    for name in pairs(app.logger.level) do
        values[name] = name:sub(1, 1) .. name:sub(2):lower()
        sorting[#sorting + 1] = name
    end
    table.sort(sorting, function(a, b)
        return app.logger.level[a] < app.logger.level[b]
    end)
    return values, sorting
end

function module:OnInitialize()
    self.panels = {}
    self.addons = {}
    self.addonButtons = {
        info = {
            type = "description",
            order = 0,
            name = "The enabled Seamless addons. Turn them on or off in the game's AddOns list, then reload.\n",
        },
    }
    local levels, levelOrder = LogLevels()
    self:Register(appName, {
        title = "Seamless",
        general = {
            interface = {
                type = "group",
                inline = true,
                order = 10,
                name = "Interface",
                args = {
                    minimap = {
                        type = "toggle",
                        order = 10,
                        name = "Minimap button",
                        desc = "Open the Seamless settings from the minimap.",
                        get = function()
                            return not app.db.profile.minimap.hide
                        end,
                        set = function(_, value)
                            app.db.profile.minimap.hide = not value
                            app.minimapButton:OnProfileRefresh()
                        end,
                    },
                    compartment = {
                        type = "toggle",
                        order = 15,
                        name = "Addon compartment entry",
                        desc = "Open the Seamless settings from Blizzard's addon compartment on the minimap, independently of the minimap button.",
                        disabled = function()
                            return not LibStub("LibDBIcon-1.0"):IsButtonCompartmentAvailable()
                        end,
                        get = function()
                            return app.db.profile.minimap.showInCompartment
                        end,
                        set = function(_, value)
                            app.db.profile.minimap.showInCompartment = value
                            app.minimapButton:OnProfileRefresh()
                        end,
                    },
                    logLevel = {
                        type = "select",
                        order = 20,
                        name = "Log level",
                        desc = "How much Seamless writes to chat. Also /seamless loglevel <level>.",
                        values = levels,
                        sorting = levelOrder,
                        get = function()
                            return app.db.profile.logLevel
                        end,
                        set = function(_, value)
                            if app.logger:setLevel(value) then
                                app.db.profile.logLevel = value
                            end
                        end,
                    },
                },
            },
            -- Filled by RegisterAddon: one button per enabled feature addon.
            addons = {
                type = "group",
                inline = true,
                order = 20,
                name = "Addons",
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = "The enabled Seamless addons. Turn them on or off in the game's AddOns list, then reload.\n",
                    },
                },
            },
        },
        db = app.db,
    })
    self:Register(appName .. "Tweaks", {
        title = "Tweaks",
        general = {
            tweaks = {
                type = "group",
                inline = true,
                order = 10,
                name = "Tweaks",
                get = function(info)
                    return app.db.profile.tweaks[info[#info]]
                end,
                set = function(info, value)
                    app.db.profile.tweaks[info[#info]] = value
                    app.tweaks:OnProfileRefresh()
                end,
                args = {
                    reloadShortcut = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = "/rl reloads the interface",
                        desc = "Type /rl in chat to reload the user interface, just like /reload.",
                        descStyle = "inline",
                    },
                    questXPTooltip = {
                        type = "toggle",
                        order = 30,
                        width = "full",
                        name = "Show completed quests in the XP tooltip",
                        desc = "Adds the number of completed quests and their total XP reward to the player XP bar tooltip. Takes effect on the next hover.",
                        descStyle = "inline",
                    },
                    enhancedXPTooltip = {
                        type = "toggle",
                        order = 40,
                        width = "full",
                        name = "Enhance the XP tooltip",
                        desc = "Shows XP to the next level, rested XP as a percentage of a level, and estimated time to the configured rested cap while resting in an inn or city. Takes effect on the next hover.",
                        descStyle = "inline",
                    },
                    restedXPCap = {
                        type = "range",
                        order = 41,
                        name = "Rested XP cap (%)",
                        desc = "Percentage of one level's XP. Default: 150%. Adjust for perks that increase your cap; the client does not expose the cap directly.",
                        min = 1,
                        max = 500,
                        step = 1,
                        disabled = function()
                            return not app.db.profile.tweaks.enhancedXPTooltip
                        end,
                    },
                    restedXPRate = {
                        type = "range",
                        order = 42,
                        name = "Rested XP per 8 hours (%)",
                        desc = "Percentage of one level accumulated per eight hours in an inn or city. Default: 5%. Adjust for perks or other bonuses; the estimate assumes no rested XP is spent.",
                        min = 0.1,
                        max = 100,
                        step = 0.1,
                        disabled = function()
                            return not app.db.profile.tweaks.enhancedXPTooltip
                        end,
                    },
                },
            },
        },
        db = app.db,
    }, self.panels[appName].id)
end

-- A feature addon's panel, below Core's; its button joins Core's Addons list.
---@param name string
---@param spec SeamlessCore.OptionsSpec
function module:RegisterAddon(name, spec)
    local root = assert(self.panels[appName], "Seamless core options must initialize before feature options")
    self:Register(name, spec, root.id)
    self.addons[#self.addons + 1] = name
    self.addonButtons[name] = {
        type = "execute",
        order = #self.addons,
        name = spec.title,
        func = function()
            self:Open(name)
        end,
    }
    self:Refresh()
end
