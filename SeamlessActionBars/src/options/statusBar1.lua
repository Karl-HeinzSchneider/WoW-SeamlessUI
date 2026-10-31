---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MainStatusTrackingBarContainer"]
end
local position, size = app.core:GetNativePositionOptions(getFrame)
---@type SeamlessCore.SettingsPage
app.optionPages.statusBar1 = {
    tooltip = function(path)
        return app.core:GetOptionDefault(app.dbDefaults.profile, path, 2)
    end,
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
            position = position,
            size = size,
        },
    },
}
