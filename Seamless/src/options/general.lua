---@type string, SeamlessCore
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

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

local levels, levelOrder = LogLevels()
---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        local defaults, key = app.dbDefaults.profile, path[#path]
        if key == "minimap" then
            return not defaults.minimap.hide
        end
        if key == "compartment" then
            return defaults.minimap.showInCompartment
        end
        return defaults[key]
    end,
    defaults = {
        profile = { logLevel = "INFO", minimap = { hide = false, minimapPos = 200, showInCompartment = false } },
    },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
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
            editModeLayout = {
                type = "group",
                inline = true,
                order = 15,
                name = L["Edit Mode layout"],
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = L["Seamless keeps an account Edit Mode layout named %s as a starting point and adds it again whenever it is missing. Choose it in Edit Mode, or copy it to make your own."]:format(
                            app.defaultLayout.LAYOUT_NAME
                        ),
                    },
                    use = {
                        type = "execute",
                        order = 10,
                        name = L["Use Seamless layout"],
                        desc = L["Switch this character to the Seamless Edit Mode layout, adding it again if it was deleted."],
                        func = function()
                            local ok, err = app.defaultLayout:Use()
                            if not ok then
                                app.logger:warn(err)
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
    },
}
