---@type string, SeamlessCore
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

app.optionPages.profiles = {
    tooltip = function(path)
        if path[#path] == "choose" then
            return "Default", true
        end
    end,
    defaults = {},
    config = { type = "group", name = L["Profiles"], order = 1000, args = {} },
}
