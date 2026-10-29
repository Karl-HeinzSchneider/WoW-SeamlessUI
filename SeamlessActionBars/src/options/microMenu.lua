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
    defaults = { profile = { microMenu = { hideArtwork = false, hidden = false } } },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Micro menu"],
        order = 130,
        hidden = function()
            return getFrame() == nil
        end,
        args = { layout = app.MicroMenuOptions(), position = app.core:GetNativePositionOptions(getFrame, scale) },
    },
}
