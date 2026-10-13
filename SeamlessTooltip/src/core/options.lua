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
            desc = entry.description .. " A game setting; it also works without the addon.",
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
    return { type = "group", inline = true, order = 1000, name = "Game settings", args = args }
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
    app.core:RegisterOptions(appName, { title = "Tooltip", general = sections.all, tabs = tabs, db = app.db })
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
