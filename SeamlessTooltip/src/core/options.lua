---@type string, SeamlessTooltip
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessTooltip.Options : AceModule, AceEvent-3.0
local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0") --[[@as SeamlessTooltip.Options]]

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

function module:OnInitialize()
    local categories = app.features.CATEGORIES
    local sections = app.features:OptionsByCategory()
    sections.spells.game = GameSettings()
    local tabs = {}
    for category, args in pairs(sections) do
        if category ~= "all" then
            tabs[category] = { order = categories[category].order, name = categories[category].name, args = args }
        end
    end
    app.core:RegisterOptions(appName, {
        title = L["Tooltip"],
        general = sections.all,
        tabs = tabs,
        tooltip = function(path)
            if path[2] == "game" then
                return app.core:GetCVarOptionInfo(path[3])
            end
            local defaults = app.dbDefaults.profile.features[path[2]]
            return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
        end,
    })
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

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
end
