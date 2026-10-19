---@type string, SeamlessDamageMeter
local appName, app = ...

local anchors = {
    TOPLEFT = "Top left",
    TOP = "Top",
    TOPRIGHT = "Top right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom right",
}

-- Layout controls inherit window defaults; appearance controls belong to skins.
local settings = {
    { key = "width", name = "Width", type = "range", min = 200, max = 800, step = 1 },
    { key = "height", name = "Height", type = "range", min = 120, max = 900, step = 1 },
    {
        key = "fixedHeight",
        name = "Fixed height by row count",
        type = "toggle",
        desc = "Keep the height at the bar count below. Resizing changes only the width.",
    },
    {
        key = "visibleLines",
        name = "Visible bars",
        type = "range",
        min = 1,
        max = 30,
        step = 0.25,
        desc = "For fixed height. 7.5 shows seven bars and half of the next.",
    },
    {
        key = "showResizeHandle",
        name = "Enable corner resizing",
        type = "toggle",
        desc = "Drag the bottom-right handle to resize. Turning this off hides it in Edit Mode too.",
    },
    {
        key = "lockSize",
        name = "Lock size",
        type = "toggle",
        desc = "Prevent grip and Edit Mode width/height resizing.",
    },
    {
        key = "lockPosition",
        name = "Lock position",
        type = "toggle",
        desc = "Prevent dragging and Edit Mode arrow-key movement without locking size.",
    },
    { key = "scale", name = "Scale", type = "range", min = 0.5, max = 2, step = 0.01 },
    {
        key = "font",
        name = "Font",
        type = "select",
        values = function()
            local values = { ["Default damage meter"] = "Default damage meter" }
            for name in pairs(LibStub("LibSharedMedia-3.0"):HashTable("font")) do
                values[name] = name
            end
            return values
        end,
    },
    { key = "windowAlpha", name = "Window opacity", type = "range", min = 0.5, max = 1, step = 0.01 },
    { key = "showIcons", name = "Show icons", type = "toggle" },
    { key = "fontSize", name = "Font size", type = "range", min = 8, max = 24, step = 1 },
    {
        key = "fontFlags",
        name = "Font outline",
        type = "select",
        values = { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick outline" },
    },
    { key = "textColor", name = "Text color", type = "color" },
    { key = "classColors", name = "Use class colors", type = "toggle" },
    { key = "hideTypeSelector", name = "Hide type selector", type = "toggle" },
    { key = "hideCombatTimer", name = "Hide combat timer", type = "toggle" },
    { key = "barColor", name = "Bar color", type = "color" },
    { key = "backgroundColor", name = "Window background", type = "color" },
    { key = "headerColor", name = "Header tint", type = "color" },
    { key = "rowHeight", name = "Row height", type = "range", min = 16, max = 40, step = 1 },
    { key = "rowSpacing", name = "Row spacing", type = "range", min = 0, max = 12, step = 1 },
    { key = "point", name = "Window anchor", type = "select", values = anchors },
    { key = "relativePoint", name = "Target anchor", type = "select", values = anchors },
    { key = "x", name = "X offset", type = "input" },
    { key = "y", name = "Y offset", type = "input" },
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
        name = config and (inherited and "Default" or (definition.desc and definition.name or "Window value"))
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
            elseif definition.type == "input" then
                return tostring(value)
            end
            return value
        end,
        set = function(_, value, g, b, a)
            local target = skin and skin.settings or (config and config.overrides or app.db.profile.windowDefaults)
            if definition.type == "color" then
                target[key] = { value, g, b, a }
            elseif definition.type == "input" then
                target[key] = tonumber(value)
            else
                target[key] = value
            end
            app:RebuildWindows()
        end,
    }
    if definition.type == "color" then
        control.hasAlpha = true
    elseif definition.type == "input" then
        control.desc = "Offset in window units. Positive X moves right; positive Y moves up. Decimals are supported."
        control.validate = function(_, value)
            local number = tonumber(value)
            return number and number == number and math.abs(number) <= 10000
                or "Enter a number between -10000 and 10000."
        end
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
                    and "Defaults are shown on the left. Enable Override to edit a window value. Turn it off to follow future default changes. Dragging sets X/Y overrides; resizing also sets width/height overrides.\n"
                or "Shared settings for every window without an override, including newly created windows. Offsets are measured at the window's scale.\n",
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
                            name = "Override",
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

function app:BuildWindowOptions()
    self:PrepareWindowSettings()
    local args = {
        defaults = { type = "group", name = "Defaults", order = 1, args = AppearanceOptions() },
        add = {
            type = "group",
            name = "Activate window",
            order = 1000,
            args = {
                info = {
                    type = "description",
                    name = "Use up to "
                        .. self.MAX_WINDOWS
                        .. " permanent windows. Activate or deactivate each window without changing its settings or attachments. Inactive windows remain available as anchor targets.",
                    order = 1,
                },
                add = {
                    type = "execute",
                    name = "Activate next window",
                    order = 2,
                    disabled = function()
                        return self:GetUnusedWindowSlot() == nil
                    end,
                    func = function()
                        self:AddWindow()
                    end,
                },
            },
        },
    }
    for index, config in ipairs(self.db.profile.windows) do
        local windowArgs = AppearanceOptions(config)
        windowArgs.management = {
            type = "group",
            inline = true,
            name = "Window " .. config.id,
            order = 1,
            args = {
                hidden = {
                    type = "toggle",
                    name = "Hide window",
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
                    name = "Clear all overrides",
                    order = 2,
                    confirm = true,
                    func = function()
                        config.overrides = {}
                        config.anchorTo = nil
                        self:RebuildWindows()
                    end,
                },
                enabled = {
                    type = "toggle",
                    name = "Use this window",
                    desc = "Deactivation hides the window and preserves its settings and attachments.",
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
                    name = "Skin",
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
                anchorTo = {
                    type = "select",
                    name = "Anchored to",
                    order = 4,
                    width = "full",
                    desc = "Anchor to the screen or another meter window. Circular anchors are excluded.",
                    values = function()
                        local values = { screen = "Screen (UIParent)" }
                        for _, candidate in ipairs(self.db.profile.windows) do
                            if self:CanAnchorTo(config, candidate.id) then
                                values[tostring(candidate.id)] = "Window " .. candidate.id
                            end
                        end
                        return values
                    end,
                    get = function()
                        return config.anchorTo and tostring(config.anchorTo) or "screen"
                    end,
                    set = function(_, value)
                        config.anchorTo = tonumber(value)
                        self:RebuildWindows()
                    end,
                },
            },
        }
        args["window" .. config.id] = {
            type = "group",
            name = config.enabled and not config.hidden and ("Window " .. config.id)
                or ("|cff808080Window " .. config.id .. "|r"),
            order = index + 1,
            args = windowArgs,
        }
    end
    self.windowOptions.args = args
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
                name = "Appearance settings apply to every window using this skin. New skins start with a copy of Default.",
            },
        }
        for order, definition in ipairs(settings) do
            if self.skinDefaults[definition.key] ~= nil then
                controls[definition.key] = SettingControl(definition, nil, nil, skin)
                controls[definition.key].order = order * 10
            end
        end
        args[key] = { type = "group", name = skin.name, order = index, args = controls }
    end
    args.add = {
        type = "group",
        name = "Add skin",
        order = 10000,
        args = {
            name = {
                type = "input",
                name = "Skin name",
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
                name = "Add skin",
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
        name = "History",
        hidden = not self.combatService.saveSessions,
        order = 20,
        args = {
            info = {
                type = "description",
                order = 1,
                name = "Completed public fights are saved per character through reload/relog. Hidden windows still collect. Reloading during restricted combat may leave incomplete data. The oldest saved segment is deleted before adding a segment above your limit. Pinned segments also count toward the limit. The hard upper limit is 1,000 segments.\nSelect fights from a window's session menu.\n",
            },
            retention = {
                type = "range",
                name = "Maximum saved segments",
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
                name = "Saved fight",
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
                        return "Select a saved fight."
                    end
                    return fight.complete and "All supported categories and source details captured."
                        or "Incomplete capture: some categories or source details are missing."
                end,
            },
            pin = {
                type = "toggle",
                name = "Pin selected fight",
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
                name = "Delete selected fight",
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
                name = "Delete segments older than selected",
                order = 55,
                confirm = "Delete all saved segments older than the selected fight, including pinned segments?",
                disabled = function()
                    return not Selected()
                end,
                func = function()
                    self.combatService:DeleteOlderSegments(self.historySelection)
                end,
            },
            clear = {
                type = "execute",
                name = "Clear saved history",
                order = 60,
                confirm = "Delete all saved fights, including pinned fights? Blizzard tracking is not reset.",
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
    self.windowOptions = { name = "Windows", order = 10, childGroups = "tree", args = {} }
    self.skinOptions = { name = "Skin", order = 15, childGroups = "tree", args = {} }
    self:BuildWindowOptions()
    self:BuildSkinOptions()
    self.core:RegisterOptions(appName, {
        title = "Damage Meter",
        general = {
            windows = {
                type = "group",
                inline = true,
                order = 10,
                name = "Meter windows",
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = "Each window has its own statistic and session. Drag its header to move, drag the bottom-right corner to resize, and scroll over the bars for more players. Sessions, Current and Overall come from Blizzard's damage meter; addon session saving is temporarily disabled. The gear menu activates, hides or deactivates windows; collapse keeps the header visible.\n",
                    },
                    add = {
                        type = "execute",
                        order = 10,
                        name = "Activate next window",
                        disabled = function()
                            return self:GetUnusedWindowSlot() == nil
                        end,
                        desc = "Activates the first inactive meter window, preserving its settings. Same as /sdm new.",
                        func = function()
                            self:AddWindow()
                        end,
                    },
                    show = {
                        type = "execute",
                        order = 20,
                        name = "Show hidden windows",
                        desc = "Shows every hidden meter window again. Same as /sdm show.",
                        func = function()
                            self.addon:SlashCommand("show")
                        end,
                    },
                    locked = {
                        type = "toggle",
                        order = 30,
                        width = "full",
                        name = "Lock positions and sizes",
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
                        name = "Maximum visible favorites",
                        desc = "Favorites are shared by all windows. Hidden slots stay saved; Select type is always last.",
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
                name = "Game meter",
                args = {
                    tracking = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = "Enable the game's damage meter UI",
                        desc = "Controls Blizzard's own meter window. Seamless queries the combat API independently of this setting.",
                        descStyle = "inline",
                        hidden = C_CVar.GetCVar("damageMeterEnabled") == nil,
                        get = function()
                            return C_CVar.GetCVarBool("damageMeterEnabled")
                        end,
                        set = function(_, value)
                            self:SetCombatTracking(value)
                        end,
                    },
                    hideBlizzard = {
                        type = "toggle",
                        order = 20,
                        width = "full",
                        name = "Hide the game's damage meter",
                        desc = "Keeps the game's own meter window hidden while this addon is enabled. It still appears in Edit Mode.",
                        descStyle = "inline",
                        get = function()
                            return self.db.profile.hideBlizzard
                        end,
                        set = function(_, value)
                            self.db.profile.hideBlizzard = value
                            self:UpdateBlizzardMeter()
                        end,
                    },
                },
            },
        },
        tabs = {
            windows = self.windowOptions,
            skin = self.skinOptions,
            history = self:HistoryOptions(),
            credits = {
                name = "Credits",
                order = 30,
                args = {
                    teelo = {
                        type = "description",
                        order = 10,
                        name = "Thanks to p3lim for creating LibEditMode, which powers Edit Mode integration for all ten meter windows.",
                    },
                    github = {
                        type = "input",
                        order = 20,
                        width = "full",
                        name = "GitHub (select and copy)",
                        get = function()
                            return "https://github.com/p3lim-wow/LibEditMode"
                        end,
                        set = function() end,
                    },
                    curseforge = {
                        type = "input",
                        order = 30,
                        width = "full",
                        name = "CurseForge (select and copy)",
                        get = function()
                            return "https://www.curseforge.com/wow/addons/edit-mode-expanded"
                        end,
                        set = function() end,
                    },
                },
            },
        },
        db = self.db,
    })
end
