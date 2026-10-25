---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MicroMenuContainer"]
end
local setting = Enum.EditModeMicroMenuSetting and Enum.EditModeMicroMenuSetting.Size
local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)
---@type SeamlessCore.SettingsPage
app.optionPages.microMenu = {
    defaults = { profile = { microMenu = { hideArtwork = false } } },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({ "revert", "resetPosition" }),
        type = "group",
        name = L["Micro menu"],
        order = 130,
        hidden = function()
            return getFrame() == nil
        end,
        args = { layout = app.MicroMenuOptions(), position = app.core:GetNativePositionOptions(getFrame, scale) },
    },
}
