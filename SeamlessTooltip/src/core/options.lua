---@type string, SeamlessTooltip
local appName, app = ...

---@class SeamlessTooltip.Options : AceModule, AceEvent-3.0
local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0") --[[@as SeamlessTooltip.Options]]

local gameSettings = {
    {
        cvar = "tooltipShowAuraSpellIDs",
        name = "Spell IDs on buffs and debuffs",
        description = "The game's own spell ID line, also on target and focus buffs. Where the Spell IDs feature shows its line, it replaces the game's.",
    },
    {
        cvar = "tooltipShowAuraCasterNames",
        name = "Caster names on buffs and debuffs",
        description = "The game's own caster line, also on target and focus buffs. Where the Aura caster feature shows its line, it replaces the game's.",
    },
}

function module:OnInitialize()
    app.core:RegisterOptions(appName, "Tooltip", function(panel)
        app.features:RegisterSettings(panel)
        panel:Header("Game settings")
        for _, entry in ipairs(gameSettings) do
            local cvar = entry.cvar
            -- The client owns these values and saves them independently of addon profiles.
            if C_CVar.GetCVar(cvar) ~= nil then
                panel:Checkbox({
                    id = "game." .. cvar,
                    name = entry.name,
                    tooltip = entry.description .. " This game setting also works without the addon.",
                    default = C_CVar.GetCVarDefault(cvar) == "1",
                    get = function()
                        return C_CVar.GetCVarBool(cvar)
                    end,
                    set = function(value)
                        C_CVar.SetCVar(cvar, value and "1" or "0")
                    end,
                    tags = { "Spells", "auras", "buffs", "debuffs" },
                })
            end
        end
        panel:Profiles(app.db)
    end)
end

function module:OnEnable()
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        for _, entry in ipairs(gameSettings) do
            if name:lower() == entry.cvar:lower() then
                self:Refresh()
                return
            end
        end
    end)
end

function module:Open()
    app.core:OpenOptions(appName)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
end

function module:OnProfileRefresh()
    self:Refresh()
end
