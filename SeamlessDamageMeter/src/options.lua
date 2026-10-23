---@type string, SeamlessDamageMeter
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Layout controls inherit window defaults; appearance controls belong to skins. Position and scale
-- are each window's own values (`WindowPositionOptions`).
local settings = {
    { key = "width", name = L["Width"], type = "range", min = 200, max = 800, step = 1 },
    { key = "height", name = L["Height"], type = "range", min = 120, max = 900, step = 1 },
    {
        key = "fixedHeight",
        name = L["Fixed height by row count"],
        type = "toggle",
        desc = L["Keep the height at the bar count below. Resizing changes only the width."],
    },
    {
        key = "visibleLines",
        name = L["Visible bars"],
        type = "range",
        min = 1,
        max = 30,
        step = 0.25,
        desc = L["For fixed height. 7.5 shows seven bars and half of the next."],
    },
    {
        key = "showResizeHandle",
        name = L["Enable corner resizing"],
        type = "toggle",
        desc = L["Drag the bottom-right handle to resize. Turning this off hides it in Edit Mode too."],
    },
    {
        key = "lockSize",
        name = L["Lock size"],
        type = "toggle",
        desc = L["Prevent grip and Edit Mode width/height resizing."],
    },
    {
        key = "lockPosition",
        name = L["Lock position outside Edit Mode"],
        type = "toggle",
        desc = L["Prevent dragging the window outside Edit Mode. Edit Mode can still move it."],
    },
    {
        key = "font",
        name = L["Font"],
        type = "select",
        values = function()
            local values = { ["Default damage meter"] = L["Default damage meter"] }
            for name in pairs(LibStub("LibSharedMedia-3.0"):HashTable("font")) do
                values[name] = name
            end
            return values
        end,
    },
    { key = "windowAlpha", name = L["Window opacity"], type = "range", min = 0.5, max = 1, step = 0.01 },
    { key = "showIcons", name = L["Show icons"], type = "toggle" },
    { key = "fontSize", name = L["Font size"], type = "range", min = 8, max = 24, step = 1 },
    {
        key = "fontFlags",
        name = L["Font outline"],
        type = "select",
        values = { [""] = L["None"], OUTLINE = L["Outline"], THICKOUTLINE = L["Thick outline"] },
    },
    { key = "textColor", name = L["Text color"], type = "color" },
    { key = "classColors", name = L["Use class colors"], type = "toggle" },
    { key = "hideTypeSelector", name = L["Hide type selector"], type = "toggle" },
    { key = "hideCombatTimer", name = L["Hide combat timer"], type = "toggle" },
    { key = "barColor", name = L["Bar color"], type = "color" },
    { key = "backgroundColor", name = L["Window background"], type = "color" },
    { key = "headerColor", name = L["Header tint"], type = "color" },
    { key = "rowHeight", name = L["Row height"], type = "range", min = 16, max = 40, step = 1 },
    { key = "rowSpacing", name = L["Row spacing"], type = "range", min = 0, max = 12, step = 1 },
}

local function CopyValue(value)
    if type(value) == "table" then
        return { unpack(value) }
    end
    return value
end

local function SettingControl(definition, config, inherited, skin)
    local key = definition.key
    local control = {
        type = definition.type,
        name = config and (inherited and L["Default"] or (definition.desc and definition.name or L["Window value"]))
            or definition.name,
        desc = definition.desc,
        width = config and 0.75 or "full",
        min = definition.min,
        max = definition.max,
        step = definition.step,
        values = definition.values,
        get = function()
            local value
            if skin then
                value = skin.settings[key]
            elseif not config or inherited then
                value = app.db.profile.windowDefaults[key]
            else
                value = app:GetWindowSetting(config, key)
            end
            if definition.type == "color" then
                return unpack(value)
            end
            return value
        end,
        set = function(_, value, g, b, a)
            local target = skin and skin.settings or (config and config.overrides or app.db.profile.windowDefaults)
            if definition.type == "color" then
                target[key] = { value, g, b, a }
            else
                target[key] = value
            end
            app:RebuildWindows()
        end,
    }
    if definition.type == "color" then
        control.hasAlpha = true
    end
    if config then
        control.disabled = function()
            return inherited or config.overrides[key] == nil
        end
    end
    return control
end

local function AppearanceOptions(config)
    local args = {
        info = {
            type = "description",
            order = 0,
            name = config
                    and L["Defaults are shown on the left. Enable Override to edit a window value. Turn it off to follow future default changes. Resizing sets width/height overrides.\n"]
                or L["Shared settings for every window without an override, including newly created windows.\n"],
        },
    }
    for order, definition in ipairs(settings) do
        local key = definition.key
        if app.skinDefaults[key] == nil then
            if config then
                local default = SettingControl(definition, config, true)
                default.order = 1
                local value = SettingControl(definition, config, false)
                value.order = 3
                args[key] = {
                    type = "group",
                    inline = true,
                    name = definition.name,
                    order = order * 10,
                    args = {
                        default = default,
                        override = {
                            type = "toggle",
                            name = L["Override"],
                            order = 2,
                            width = 0.5,
                            get = function()
                                return config.overrides[key] ~= nil
                            end,
                            set = function(_, enabled)
                                config.overrides[key] = enabled and CopyValue(app.db.profile.windowDefaults[key]) or nil
                                -- A false toggle value is itself a valid override.
                                if enabled and app.db.profile.windowDefaults[key] == false then
                                    config.overrides[key] = false
                                end
                                app:RebuildWindows()
                            end,
                        },
                        value = value,
                    },
                }
            else
                args[key] = SettingControl(definition)
                args[key].order = order * 10
            end
        end
    end
    return args
end

-- The standard Position and scale section, on the window's own values. Moving or re-anchoring
-- keeps the offsets; dragging the window measures them again.
local function WindowPositionOptions(config)
    local group = app.core:GetPositionOptions({
        get = function(key)
            if key == "relativeTo" then
                return config.anchorTo and tostring(config.anchorTo) or "screen"
            end
            return app:GetWindowSetting(config, key)
        end,
        set = function(key, value)
            if key == "relativeTo" then
                config.anchorTo = tonumber(value)
            else
                app:SetWindowValue(config, key, value)
            end
            app:RebuildWindows()
        end,
        default = function(key)
            if key == "relativeTo" then
                return "screen"
            end
            return app.positionDefaults[key]
        end,
        isDefault = function()
            for key in pairs(app.positionDefaults) do
                if key ~= "scale" and app:GetWindowSetting(config, key) ~= app.positionDefaults[key] then
                    return false
                end
            end
            return config.anchorTo == nil
        end,
        reset = function()
            for key in pairs(app.positionDefaults) do
                if key ~= "scale" then
                    app:SetWindowValue(config, key, app.positionDefaults[key])
                end
            end
            config.anchorTo = nil
            app:RebuildWindows()
        end,
        anchorFrames = function()
            local values = { { text = L["Screen (UIParent)"], value = "screen" } }
            for _, candidate in ipairs(app.db.profile.windows) do
                if app:CanAnchorTo(config, candidate.id) then
                    values[#values + 1] = { text = L["Window %d"]:format(candidate.id), value = tostring(candidate.id) }
                end
            end
            return values
        end,
        scale = {
            get = function()
                return app:GetWindowSetting(config, "scale")
            end,
            set = function(value)
                app:SetWindowValue(config, "scale", value)
                app:RebuildWindows()
            end,
            default = function()
                return app.positionDefaults.scale
            end,
        },
    })
    group.order = 2
    return group
end

-- Window defaults and one tab per slot; the tab tables stay registered, only their args are rebuilt.
function app:BuildWindowOptions()
    self:PrepareWindowSettings()
    self.windowOptions.args = AppearanceOptions()
    for _, config in ipairs(self.db.profile.windows) do
        local windowArgs = AppearanceOptions(config)
        windowArgs.position = WindowPositionOptions(config)
        windowArgs.management = {
            type = "group",
            inline = true,
            name = L["Window"],
            order = 1,
            args = {
                hidden = {
                    type = "toggle",
                    name = L["Hide window"],
                    order = 1,
                    get = function()
                        return config.hidden or false
                    end,
                    set = function(_, value)
                        config.hidden = value
                        self:RebuildWindows()
                    end,
                },
                reset = {
                    type = "execute",
                    name = L["Clear all overrides"],
                    order = 2,
                    confirm = true,
                    func = function()
                        config.overrides = {}
                        config.styleOverrides = nil
                        config.modifyGlobalStyle = nil
                        self:RebuildWindows()
                    end,
                },
                enabled = {
                    type = "toggle",
                    name = L["Use this window"],
                    desc = L["Deactivation hides the window and preserves its settings and attachments."],
                    order = 0,
                    get = function()
                        return config.enabled
                    end,
                    set = function(_, value)
                        self:SetWindowEnabled(config, value)
                    end,
                },
                skin = {
                    type = "select",
                    name = L["Skin"],
                    order = 3,
                    width = "full",
                    values = function()
                        local values = {}
                        for key, skin in pairs(self.db.profile.skins) do
                            values[key] = skin.name
                        end
                        return values
                    end,
                    get = function()
                        return config.skin
                    end,
                    set = function(_, value)
                        config.skin = value
                        self:RebuildWindows()
                    end,
                },
            },
        }
        self.windowTabs["window" .. config.id].args = windowArgs
    end
end

function app:BuildSkinOptions()
    if not self.skinOptions then
        return
    end
    local args = {}
    local keys = {}
    for key in pairs(self.db.profile.skins) do
        if key ~= "default" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    table.insert(keys, 1, "default")
    for index, key in ipairs(keys) do
        local skin = self.db.profile.skins[key]
        local controls = {
            info = {
                type = "description",
                order = 0,
                name = L["Appearance settings apply to every window using this skin. New skins start with a copy of Default."],
            },
        }
        for order, definition in ipairs(settings) do
            if self.skinDefaults[definition.key] ~= nil then
                controls[definition.key] = SettingControl(definition, nil, nil, skin)
                controls[definition.key].order = order * 10
            end
        end
        if key ~= "default" then
            controls.remove = {
                type = "execute",
                name = L["Delete skin"],
                order = 1,
                confirm = L["Delete the skin %s? Windows using it switch to Default."]:format(skin.name),
                func = function()
                    self:RemoveSkin(key)
                end,
            }
        end
        args[key] = { type = "group", name = skin.name, order = index, args = controls }
    end
    args.add = {
        type = "group",
        name = L["Add skin"],
        order = 10000,
        args = {
            name = {
                type = "input",
                name = L["Skin name"],
                order = 1,
                width = "full",
                get = function()
                    return self.newSkinName or ""
                end,
                set = function(_, value)
                    self.newSkinName = value
                end,
            },
            create = {
                type = "execute",
                name = L["Add skin"],
                order = 2,
                disabled = function()
                    return not self.newSkinName or not self.newSkinName:match("%S")
                end,
                func = function()
                    self:AddSkin(self.newSkinName or "")
                    self.newSkinName = nil
                end,
            },
        },
    }
    self.skinOptions.args = args
end

function app:HistoryOptions()
    local function Selected()
        return self.archive:Get(self.historySelection)
    end
    return {
        name = L["History"],
        hidden = not self.combatService.saveSessions,
        order = 60,
        args = {
            info = {
                type = "description",
                order = 1,
                name = L["Completed public fights are saved per character through reload/relog. Hidden windows still collect. Reloading during restricted combat may leave incomplete data. The oldest saved segment is deleted before adding a segment above your limit. Pinned segments also count toward the limit. The hard upper limit is 1,000 segments.\nSelect fights from a window's session menu.\n"],
            },
            retention = {
                type = "range",
                name = L["Maximum saved segments"],
                order = 10,
                min = 1,
                max = self.archive.maxSegments,
                step = 1,
                get = function()
                    return self.archive.db.retention
                end,
                set = function(_, value)
                    self.combatService:SetSegmentLimit(value)
                end,
            },
            fight = {
                type = "select",
                name = L["Saved fight"],
                order = 20,
                width = "full",
                values = function()
                    local values = {}
                    for _, entry in ipairs(self.combatService:ListSessions()) do
                        if entry.archiveID then
                            values[tostring(entry.archiveID)] = self.combatService:Describe(entry)
                        end
                    end
                    return values
                end,
                get = function()
                    return self.historySelection and tostring(self.historySelection)
                end,
                set = function(_, value)
                    self.historySelection = tonumber(value)
                end,
            },
            status = {
                type = "description",
                order = 25,
                name = function()
                    local fight = Selected()
                    if not fight then
                        return L["Select a saved fight."]
                    end
                    return fight.complete and L["All supported categories and source details captured."]
                        or L["Incomplete capture: some categories or source details are missing."]
                end,
            },
            pin = {
                type = "toggle",
                name = L["Pin selected fight"],
                order = 30,
                disabled = function()
                    return not Selected()
                end,
                get = function()
                    local fight = Selected()
                    return fight and fight.pinned or false
                end,
                set = function(_, value)
                    if Selected() and Selected().pinned ~= value then
                        self.combatService:Pin(self.historySelection)
                    end
                end,
            },
            delete = {
                type = "execute",
                name = L["Delete selected fight"],
                order = 50,
                confirm = true,
                disabled = function()
                    return not Selected()
                end,
                func = function()
                    self.combatService:Delete(self.historySelection)
                    self.historySelection = nil
                end,
            },
            deleteOlder = {
                type = "execute",
                name = L["Delete segments older than selected"],
                order = 55,
                confirm = L["Delete all saved segments older than the selected fight, including pinned segments?"],
                disabled = function()
                    return not Selected()
                end,
                func = function()
                    self.combatService:DeleteOlderSegments(self.historySelection)
                end,
            },
            clear = {
                type = "execute",
                name = L["Clear saved history"],
                order = 60,
                confirm = L["Delete all saved fights, including pinned fights? Blizzard tracking is not reset."],
                func = function()
                    self.combatService:ClearHistory()
                    self.historySelection = nil
                end,
            },
        },
    }
end

function app:RegisterOptions()
    self:PrepareWindowSettings()
    self.windowOptions = { name = L["Window defaults"], order = 10, args = {} }
    self.windowTabs = {}
    for id = 1, self.MAX_WINDOWS do
        self.windowTabs["window" .. id] = { name = L["Window %d"]:format(id), order = 10 + id, args = {} }
    end
    self.skinOptions = { name = L["Skin"], order = 50, childGroups = "tree", args = {} }
    self:BuildWindowOptions()
    self:BuildSkinOptions()
    local tabs = { windows = self.windowOptions, skin = self.skinOptions, history = self:HistoryOptions() }
    for key, tab in pairs(self.windowTabs) do
        tabs[key] = tab
    end
    self.core:RegisterOptions(appName, {
        tooltip = function(path)
            local key = path[#path]
            if path[1] == "history" then
                if key == "retention" then
                    return 50, true
                end
                if key == "pinned" then
                    return false, true
                end
                return nil, true
            end
            if path[1] == "general" then
                return self.dbDefaults.profile[key]
            end
            if path[1] == "skin" then
                if key == "name" then
                    return ""
                end
                return self.skinDefaults[key]
            end
            if path[1] == "windows" or path[1]:match("^window%d+$") then
                if key == "override" or key == "hidden" then
                    return false
                end
                if key == "skin" then
                    return "default"
                end
                if key == "enabled" then
                    return path[1] == "window1"
                end
                if key == "default" or key == "value" then
                    return self.db.profile.windowDefaults[path[#path - 1]]
                end
                return self.windowDefaults[key]
            end
            return nil
        end,
        title = L["Damage Meter"],
        general = {
            windows = {
                type = "group",
                inline = true,
                order = 10,
                name = L["Meter windows"],
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = L["Each window has its own statistic and session. Drag its header to move, drag the bottom-right corner to resize, and scroll over the bars for more players. Sessions, Current and Overall come from Blizzard's damage meter; addon session saving is temporarily disabled. The gear menu activates, hides or deactivates windows; collapse keeps the header visible.\n"],
                    },
                    limit = {
                        type = "description",
                        order = 5,
                        name = L["Use up to %d permanent windows. Activate or deactivate each window without changing its settings or attachments. Inactive windows remain available as anchor targets."]:format(
                            self.MAX_WINDOWS
                        ) .. "\n",
                    },
                    add = {
                        type = "execute",
                        order = 10,
                        name = L["Activate next window"],
                        disabled = function()
                            return self:GetUnusedWindowSlot() == nil
                        end,
                        desc = L["Activates the first inactive meter window, preserving its settings. Same as /sdm new."],
                        func = function()
                            self:AddWindow()
                        end,
                    },
                    show = {
                        type = "execute",
                        order = 20,
                        name = L["Show hidden windows"],
                        desc = L["Shows every hidden meter window again. Same as /sdm show."],
                        func = function()
                            self.addon:SlashCommand("show")
                        end,
                    },
                    locked = {
                        type = "toggle",
                        order = 30,
                        width = "full",
                        name = L["Lock positions and sizes"],
                        get = function()
                            return self.db.profile.locked
                        end,
                        set = function(_, value)
                            self.db.profile.locked = value
                        end,
                    },
                    maxVisibleFavorites = {
                        type = "range",
                        order = 40,
                        width = "full",
                        name = L["Maximum visible favorites"],
                        desc = L["Favorites are shared by all windows. Hidden slots stay saved; Select type is always last."],
                        min = 0,
                        max = 20,
                        step = 1,
                        get = function()
                            return self.db.profile.maxVisibleFavorites
                        end,
                        set = function(_, value)
                            self.db.profile.maxVisibleFavorites = value
                            self:PrepareWindowSettings()
                            self:RefreshWindows()
                        end,
                    },
                },
            },
            game = {
                type = "group",
                inline = true,
                order = 20,
                name = L["Game meter"],
                args = {
                    gameSettings = {
                        type = "execute",
                        order = 10,
                        name = L["Game damage meter settings"],
                        desc = L["Open the game's settings to turn its own damage meter on or off. Seamless reads combat data either way."],
                        disabled = function()
                            return Settings.ADVANCED_OPTIONS_CATEGORY_ID == nil
                        end,
                        func = function()
                            self:OpenBlizzardMeterSettings()
                        end,
                    },
                },
            },
        },
        tabs = tabs,
    })
end
