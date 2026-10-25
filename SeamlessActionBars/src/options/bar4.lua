---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MultiBarRight"]
end
local setting = Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.IconSize
local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)
---@type SeamlessCore.SettingsPage
app.optionPages.bar4 = {
    defaults = {},
    config = {
        type = "group",
        name = L["Action bar %d"]:format(4),
        order = 40,
        hidden = function()
            return getFrame() == nil
        end,
        args = { position = app.core:GetNativePositionOptions(getFrame, scale) },
    },
}
