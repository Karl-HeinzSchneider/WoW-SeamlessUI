---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MultiBarBottomRight"]
end
local setting = Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.IconSize
local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)
---@type SeamlessCore.SettingsPage
app.optionPages.bar3 = {
    defaults = {},
    config = {
        type = "group",
        name = L["Action bar %d"]:format(3),
        order = 30,
        hidden = function()
            return getFrame() == nil
        end,
        args = { position = app.core:GetNativePositionOptions(getFrame, scale) },
    },
}
