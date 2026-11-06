---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["SecondaryStatusTrackingBarContainer"]
end
local position, size = app.core:GetNativePositionOptions(getFrame)
size.layoutStored = nil
size.args.scale = app.StatusBarScaleOption("statusBar2")
size.args.width = app.StatusBarWidthOption(getFrame)
---@type SeamlessCore.SettingsPage
app.optionPages.statusBar2 = {
    tooltip = function(path)
        return app.core:GetOptionDefault(app.dbDefaults.profile, path, 2)
    end,
    defaults = { profile = { statusBar2 = { scale = 1 } } },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["XP / reputation bar %d"]:format(2),
        order = 100,
        hidden = function()
            return getFrame() == nil
        end,
        args = {
            style = app.StatusBarTextOptions(),
            xpBarTooltip = app.XPBarTooltipOptions(),
            position = position,
            size = size,
        },
    },
}
