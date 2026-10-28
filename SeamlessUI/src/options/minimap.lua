---@type string, SeamlessUI
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return MinimapCluster
end
local setting = Enum.EditModeMinimapSetting and Enum.EditModeMinimapSetting.Size
local scale = setting and app.core:GetNativeSettingScale(getFrame, setting)

---@type SeamlessCore.SettingsPage
app.optionPages.minimap = {
    defaults = { profile = { hideMinimapDayNight = false } },
    config = {
        type = "group",
        name = L["Minimap"],
        order = 30,
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        args = {
            style = {
                type = "group",
                inline = true,
                name = L["Style"],
                order = 20,
                args = {
                    hideMinimapDayNight = {
                        type = "toggle",
                        order = 10,
                        width = "full",
                        name = L["Hide minimap day/night indicator"],
                        default = false,
                        get = function()
                            return app.db.profile.hideMinimapDayNight
                        end,
                        set = function(_, value)
                            app.db.profile.hideMinimapDayNight = value
                            app.minimap:OnProfileRefresh()
                        end,
                    },
                },
            },
            position = app.core:GetNativePositionOptions(getFrame, scale),
        },
    },
}
