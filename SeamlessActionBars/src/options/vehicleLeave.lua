---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MainMenuBarVehicleLeaveButton"]
end
local position, size = app.core:GetNativePositionOptions(getFrame)
---@type SeamlessCore.SettingsPage
app.optionPages.vehicleLeave = {
    defaults = {},
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = L["Leave vehicle button"],
        order = 120,
        hidden = function()
            return getFrame() == nil
        end,
        args = { position = position, size = size },
    },
}
