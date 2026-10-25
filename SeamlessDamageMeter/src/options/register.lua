---@type string, SeamlessDamageMeter
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

function app:RegisterOptions()
    self:PrepareWindowSettings()
    self.windowOptions = self.optionPages.windows.config
    self.windowTabs = {}
    for id = 1, self.MAX_WINDOWS do
        self.windowTabs["window" .. id] = self.optionPages["window" .. id].config
    end
    self.skinOptions = self.optionPages.skin.config
    self:BuildWindowOptions()
    self:BuildSkinOptions()
    self.core:RegisterOptions(appName, { title = L["Damage Meter"], pages = self.optionPages })
end
