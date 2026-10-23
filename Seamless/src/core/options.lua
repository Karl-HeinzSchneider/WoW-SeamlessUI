---@type string, SeamlessCore
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

-- Every Seamless addon's panel is an AceConfig table of tabs: General first, the addon's own tabs
-- in between. Only the core panel has Profiles last. Core's panel is the suite's entry in Settings > AddOns; the feature
-- addons' panels are its children.
local GENERAL_ORDER, PROFILES_ORDER = 0, 1000

local PROFILE_EVENTS = { "OnProfileChanged", "OnProfileCopied", "OnProfileReset", "OnProfileDeleted", "OnNewProfile" }

---@class SeamlessCore.OptionsSpec
---@field title string The panel's name in the AddOns list and its heading.
---@field general table<string, table> AceConfig args of the General tab.
---@field tabs? table<string, table> The addon's own tabs: AceConfig groups by key, `order` 1 to 999.
---@field tooltip? fun(path: string[]): any, boolean? Default value and whether the setting is per-character.
---@field new? boolean Tag the addon's category header.
---@field blizzard? boolean Tag the addon's category header.
---@field editMode? boolean Tag the addon's category header.

---@class SeamlessCore.OptionsPanel
---@field title string
---@field id any Settings category ID.
---@field options table Registered AceConfig root, with custom tags stored separately.

---@class SeamlessCore.Options : AceModule
---@field panels table<string, SeamlessCore.OptionsPanel>
---@field addons string[] Feature addons with a panel, in registration order.
---@field addonButtons table<string, table> Args of the Addons group on Core's General tab.
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessCore.Options]]

-- Keep the original option paths: inherited accessors and AceDBOptions handlers
-- must receive exactly the same info tables in either window.
local function RegisterConfigPages(name, title, args, flags)
    local isTweaks = name == appName .. "Tweaks"
    local parent = isTweaks and appName or name
    if name == appName then
        app.config.categories[name].new = flags.new
        app.config.categories[name].blizzard = flags.blizzard
        app.config.categories[name].editMode = flags.editMode
    end
    if name ~= appName and not isTweaks then
        app.addon:RegisterConfigCategory(
            name,
            { name = title, header = true, new = flags.new, blizzard = flags.blizzard, editMode = flags.editMode }
        )
    end
    for key, tab in pairs(args) do
        local tags = app.config:GetOptionTags(tab)
        local id = name .. ":" .. key
        local spec = {
            name = isTweaks and title or tab.name,
            parent = parent,
            order = isTweaks and 500 or tab.order,
            hidden = tab.hidden,
            new = tags.new,
            blizzard = tags.blizzard,
            editMode = tags.editMode,
            create = function(page)
                local root = AceConfigRegistry:GetOptionsTable(name, "dialog", "SeamlessConfig-1.0")
                app.config:CreateOptionsPage(page, root, key, name)
                -- NotifyChange may arrive inside a widget callback. Rebuild on the
                -- next frame so that callback finishes before its widget is released.
                local dirty = false
                AceConfigRegistry.RegisterCallback(page, "ConfigTableChange", function(_, changed)
                    if changed == name then
                        dirty = true
                    end
                end)
                page:SetScript("OnUpdate", function()
                    if dirty then
                        dirty = false
                        app.config:RefreshOptionsPage(page)
                    end
                end)
            end,
            refresh = function(page)
                app.config:RefreshOptionsPage(page)
            end,
        }
        if app.config.categories[id] then
            -- Core's initial General placeholder is selected before initialization.
            local existing = app.config.categories[id]
            if spec.new == nil then
                spec.new = existing.new
            end
            if spec.blizzard == nil then
                spec.blizzard = existing.blizzard
            end
            if spec.editMode == nil then
                spec.editMode = existing.editMode
            end
            app.config.categories[id] = spec
            spec.id = id
        else
            app.addon:RegisterConfigCategory(id, spec)
        end
    end
end

---@param name string AceConfig app name: the addon's folder name.
---@param spec SeamlessCore.OptionsSpec
---@param parent? any Settings category ID of the parent panel.
function module:Register(name, spec, parent)
    assert(not self.panels[name], "Duplicate Seamless options: " .. name)
    app.config.optionInfo[name] = spec.tooltip
    local args = {
        general = { type = "group", name = L["General"], order = GENERAL_ORDER, args = spec.general },
    }
    for key, tab in pairs(spec.tabs or {}) do
        assert(not args[key] and key ~= "profiles", "Reserved Seamless options tab: " .. key)
        assert(tab.order and tab.order > GENERAL_ORDER and tab.order < PROFILES_ORDER, "Tab order 1-999: " .. key)
        tab.type = "group"
        args[key] = tab
    end
    if name == appName then
        local profiles = AceDBOptions:GetOptionsTable(app.db)
        profiles.order = PROFILES_ORDER
        args.profiles = profiles
    end
    -- All panels redraw when the shared profile changes, including those without a Profiles tab.
    for _, event in ipairs(PROFILE_EVENTS) do
        app.db.RegisterCallback(args, event, function()
            self:Refresh(name)
        end)
    end
    local root = { type = "group", name = spec.title, childGroups = "tab", args = args }
    app.config:NormalizeOptionTags(root)
    AceConfigRegistry:RegisterOptionsTable(name, root)
    local _, id = AceConfigDialog:AddToBlizOptions(name, spec.title, parent)
    self.panels[name] = { title = spec.title, id = id, options = root }
    RegisterConfigPages(name, spec.title, args, spec)
end

-- Opens the shared config window on the addon's General page or requested tab.
---@param name? string
---@param tab? string
function module:Open(name, tab)
    name = name or appName
    local panel = self.panels[name]
    if not panel then
        return
    end
    app.addon:OpenConfig(name .. ":" .. (tab or "general"))
end

-- Redraws `name`'s panel (Core's when nil) after a change made outside of it.
---@param name? string
function module:Refresh(name)
    local panel = self.panels and self.panels[name or appName]
    if panel then
        app.config:NormalizeOptionTags(panel.options)
    end
    AceConfigRegistry:NotifyChange(name or appName)
end

---@class SeamlessCore.FeatureSpec
---@field name string Section heading.
---@field desc string What the feature does, shown under its Enable switch.
---@field order? number
---@field new? boolean Show a glowing NEW label beside this feature.
---@field blizzard? boolean Show a glowing BLIZZ label beside this feature.
---@field editMode? boolean Show a glowing EDIT MODE label: its settings live in the Edit Mode layout.
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
    -- A feature with no subordinate settings needs only a clearly named switch.
    if not spec.options or not next(spec.options) then
        return {
            type = "toggle",
            new = spec.new,
            blizzard = spec.blizzard,
            editMode = spec.editMode,
            order = spec.order,
            width = "full",
            name = spec.name,
            desc = spec.desc,
            descStyle = "inline",
            get = function()
                return spec.settings().enabled
            end,
            set = function(_, value)
                spec.settings().enabled = value
                spec.toggled()
            end,
            disabled = function()
                return false
            end,
        }
    end
    local args = {
        enabled = {
            type = "toggle",
            order = 0,
            width = "full",
            name = L["Enable"],
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
        new = spec.new,
        blizzard = spec.blizzard,
        editMode = spec.editMode,
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
        values[name] = L[name:sub(1, 1) .. name:sub(2):lower()]
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
            name = L["The enabled Seamless addons. Turn them on or off in the game's AddOns list, then reload.\n"],
        },
    }
    local levels, levelOrder = LogLevels()
    self:Register(appName, {
        tooltip = function(path)
            local key = path[#path]
            local defaults = app.dbDefaults.profile
            if path[1] == "profiles" then
                if key == "choose" then
                    return "Default", true
                end
                return nil
            end
            if key == "minimap" then
                return not defaults.minimap.hide
            end
            if key == "compartment" then
                return defaults.minimap.showInCompartment
            end
            return defaults[key]
        end,
        title = L["Seamless"],
        general = {
            interface = {
                type = "group",
                inline = true,
                order = 10,
                name = L["Interface"],
                args = {
                    minimap = {
                        type = "toggle",
                        order = 10,
                        name = L["Minimap button"],
                        desc = L["Open the Seamless settings from the minimap."],
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
                        name = L["Addon compartment entry"],
                        desc = L["Open the Seamless settings from Blizzard's addon compartment on the minimap, independently of the minimap button."],
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
                        name = L["Log level"],
                        desc = L["How much Seamless writes to chat. Also /seamless loglevel <level>."],
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
                name = L["Addons"],
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = L["The enabled Seamless addons. Turn them on or off in the game's AddOns list, then reload.\n"],
                    },
                },
            },
        },
    })
    self:Register(appName .. "Tweaks", {
        tooltip = function(path)
            return app.dbDefaults.profile.tweaks[path[#path]]
        end,
        title = L["Tweaks"],
        general = {
            tweaks = {
                type = "group",
                inline = true,
                order = 10,
                name = L["Tweaks"],
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
                        name = L["/rl reloads the interface"],
                        desc = L["Type /rl in chat to reload the user interface, just like /reload."],
                        descStyle = "inline",
                    },
                    quickKeybindShortcut = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = L["/kb starts Quick Keybind Mode"],
                        desc = L["Type /kb in chat to bind keys by hovering over action buttons, like the Quick Keybind Mode button in the Keybindings settings."],
                        descStyle = "inline",
                    },
                },
            },
        },
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
