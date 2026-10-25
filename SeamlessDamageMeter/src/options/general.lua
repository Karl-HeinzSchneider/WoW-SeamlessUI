---@type string, SeamlessDamageMeter
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local self = app
---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        return app.dbDefaults.profile[path[#path]]
    end,
    defaults = { profile = { locked = false, maxVisibleFavorites = 6 } },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
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
    },
}
