---@type string, SeamlessCastbar
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local options = app.addon:NewModule("Options")
function options:OnInitialize()
    app.core:RegisterOptions(appName, { title = L["Castbar"], pages = app.optionPages })
end
