---@type string, SeamlessChat
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0")
function module:OnInitialize()
    app.core:RegisterOptions(appName, { title = L["Chat"], pages = app.optionPages })
end
---@param tab? SeamlessChat.OptionsTab
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
end
