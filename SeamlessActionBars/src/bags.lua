---@type string, SeamlessActionBars
local appName, app = ...
local module = app.addon:NewModule("Bags")

function module:OnInitialize()
    if not Enum.EditModeSystem or not Enum.EditModeSystem.Bags then
        return
    end
    app.core:RegisterEditModeSystemOptions("SeamlessActionBars:bags", {
        system = Enum.EditModeSystem.Bags,
        name = app.optionPages.bags.config.name,
        page = { addon = appName, key = "bags" },
        enabled = function()
            return module:IsEnabled() and app.addon:IsEnabled()
        end,
    })
end

function module:OnEnable()
    app.core:RefreshEditModeSystemOptions()
end

function module:OnDisable()
    app.core:RefreshEditModeSystemOptions()
end
