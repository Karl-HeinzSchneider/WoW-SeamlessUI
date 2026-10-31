---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MultiBarBottomRight"]
end
local position, size = app.core:GetNativePositionOptions(getFrame)
---@type SeamlessCore.SettingsPage
app.optionPages.bar3 = {
    defaults = {},
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Action bar %d"]:format(3),
        order = 30,
        hidden = function()
            return getFrame() == nil
        end,
        args = { position = position, size = size },
    },
}
