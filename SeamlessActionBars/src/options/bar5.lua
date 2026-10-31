---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MultiBarLeft"]
end
local setting = Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.IconSize
local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)
local position, size = app.core:GetNativePositionOptions(getFrame, scale)
---@type SeamlessCore.SettingsPage
app.optionPages.bar5 = {
    defaults = {},
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Action bar %d"]:format(5),
        order = 50,
        hidden = function()
            return getFrame() == nil
        end,
        args = { position = position, size = size },
    },
}
