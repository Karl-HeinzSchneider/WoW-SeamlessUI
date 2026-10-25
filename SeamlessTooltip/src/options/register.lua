---@type string, SeamlessTooltip
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0")
function module:OnInitialize()
    app.core:RegisterOptions(appName, { title = L["Tooltip"], pages = app.optionPages })
end
function module:OnEnable()
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        for _, entry in ipairs({ { cvar = "tooltipShowAuraSpellIDs" }, { cvar = "tooltipShowAuraCasterNames" } }) do
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
