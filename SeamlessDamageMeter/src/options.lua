---@type string, SeamlessDamageMeter
local appName, app = ...

function app:RegisterOptions()
    self.core:RegisterOptions(appName, "Damage Meter", function(panel)
        panel:Description(
            "Meter windows",
            "Each window has its own statistic and session. Drag its header to move, drag the bottom-right corner to resize, and scroll over the bars for more players. The gear menu adds or removes windows; the collapse button hides a window. Combat history is owned by the game and is not saved by this addon."
        )
        panel:Button("New meter window", "Add window", function()
            self:AddWindow()
        end)
        panel:Button("Hidden meter windows", "Show all", function()
            self.addon:SlashCommand("show")
        end)
        panel:Checkbox({
            id = "locked",
            name = "Lock meter positions and sizes",
            default = false,
            get = function()
                return self.db.profile.locked
            end,
            set = function(value)
                self.db.profile.locked = value
            end,
        })
        if C_CVar.GetCVar("damageMeterEnabled") ~= nil then
            panel:Checkbox({
                id = "tracking",
                name = "Enable Blizzard combat tracking",
                tooltip = "Shared game setting. Required to receive combat statistics; also enables the built-in meter. Its visibility can be adjusted in the game's Damage Meter settings.",
                default = C_CVar.GetCVarDefault("damageMeterEnabled") == "1",
                get = function()
                    return C_CVar.GetCVarBool("damageMeterEnabled")
                end,
                set = function(value)
                    C_CVar.SetCVar("damageMeterEnabled", value and "1" or "0")
                end,
            })
        end
        panel:Profiles(self.db)
    end)
end
