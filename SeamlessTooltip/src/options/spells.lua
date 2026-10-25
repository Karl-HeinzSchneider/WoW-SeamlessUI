---@type string, SeamlessTooltip
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local media = app.media
local LSM = media.LSM
local auraSource = app.features:GetModule("AuraSource")
local spellIDs = app.features:GetModule("SpellIDs")
local gameSettings = {
    {
        cvar = "tooltipShowAuraSpellIDs",
        name = L["Spell IDs on buffs and debuffs"],
        description = L["The game's own spell ID line, also on target and focus buffs. Where the Spell IDs feature shows its line, it replaces the game's."],
    },
    {
        cvar = "tooltipShowAuraCasterNames",
        name = L["Caster names on buffs and debuffs"],
        description = L["The game's own caster line, also on target and focus buffs. Where the Aura caster feature shows its line, it replaces the game's."],
    },
}

-- The client owns these values and saves them independently of addon profiles.
local function GameSettings()
    local args = {}
    for i, entry in ipairs(gameSettings) do
        local cvar = entry.cvar
        args[cvar] = {
            type = "toggle",
            order = i,
            width = "full",
            name = entry.name,
            desc = entry.description .. L[" A game setting; it also works without the addon."],
            descStyle = "inline",
            hidden = C_CVar.GetCVar(cvar) == nil,
            get = function()
                return C_CVar.GetCVarBool(cvar)
            end,
            set = function(_, value)
                C_CVar.SetCVar(cvar, value and "1" or "0")
            end,
        }
    end
    return { type = "group", inline = true, order = 1000, name = L["Game settings"], args = args }
end

---@type SeamlessCore.SettingsPage
app.optionPages.spells = {
    tooltip = function(path)
        if path[2] == "game" then
            return app.core:GetCVarOptionInfo(path[3])
        end
        local defaults = app.dbDefaults.profile.features[path[2]]
        return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
    end,
    defaults = {
        profile = {
            features = {
                AuraSource = {
                    enabled = true,
                },
                SpellIDs = {
                    enabled = true,
                    spell = true,
                    icon = false,
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Spells"],
        order = 30,
        args = {
            AuraSource = {
                type = "group",
                feature = true,
                name = L["Aura caster"],
                desc = L["Adds who cast a buff or debuff to its tooltip. Players are shown in their class color."],
                order = 20,
                settings = function()
                    return auraSource:Settings()
                end,
                toggled = function()
                    auraSource:Refresh()
                end,
                changed = function()
                    auraSource:SettingsChanged()
                end,
                args = {},
            },
            SpellIDs = {
                type = "group",
                feature = true,
                name = L["Spell IDs"],
                desc = L["Adds the spell's ID, and its icon's ID, to spell tooltips and to buffs and debuffs."],
                order = 10,
                settings = function()
                    return spellIDs:Settings()
                end,
                toggled = function()
                    spellIDs:Refresh()
                end,
                changed = function()
                    spellIDs:SettingsChanged()
                end,
                args = {
                    spell = {
                        type = "toggle",
                        order = 10,
                        name = L["Spell ID"],
                    },
                    icon = {
                        type = "toggle",
                        order = 20,
                        name = L["Icon ID"],
                        desc = L["The file ID of the spell's icon."],
                    },
                },
            },
            game = GameSettings(),
        },
    },
}
