---@type string, SeamlessDamageMeter
local appName, app = ...

function app:RegisterOptions()
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
                        name = "Each window has its own statistic and session. Drag its header to move, drag the bottom-right corner to resize, and scroll over the bars for more players. The gear menu adds, hides or removes windows; the collapse button folds the bars away and keeps the header visible. Combat history is owned by the game and is not saved by this addon.\n",
                    },
                    add = {
                        type = "execute",
                        order = 10,
                        name = "Add window",
                        desc = "Opens a new meter window. Same as /sdm new.",
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
                        name = "Combat tracking",
                        desc = "The game setting that records combat statistics. This addon needs it and turns it on when it loads.",
                        descStyle = "inline",
                        hidden = C_CVar.GetCVar("damageMeterEnabled") == nil,
                        get = function()
                            return C_CVar.GetCVarBool("damageMeterEnabled")
                        end,
                        set = function(_, value)
                            C_CVar.SetCVar("damageMeterEnabled", value and "1" or "0")
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
        db = self.db,
    })
end
