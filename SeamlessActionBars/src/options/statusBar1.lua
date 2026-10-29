---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MainStatusTrackingBarContainer"]
end
local setting = Enum.EditModeStatusTrackingBarSetting and Enum.EditModeStatusTrackingBarSetting.Size
local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)
---@type SeamlessCore.SettingsPage
app.optionPages.statusBar1 = {
    defaults = {
        profile = {
            xpBarTooltip = {
                enabled = true,
                completedQuests = true,
                automaticRestedXP = true,
                restedXPCap = 150,
                restedXPRate = 5,
            },
        },
    },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["XP / reputation bar %d"]:format(1),
        order = 90,
        hidden = function()
            return getFrame() == nil
        end,
        args = {
            xpBarTooltip = app.XPBarTooltipOptions(),
            position = app.core:GetNativePositionOptions(getFrame, scale),
        },
    },
}
