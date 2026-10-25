---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function getFrame()
    return _G["MainMenuBarVehicleLeaveButton"]
end
local scale = nil
---@type SeamlessCore.SettingsPage
app.optionPages.vehicleLeave = {
    defaults = {},
    config = {
        type = "group",
        name = L["Leave vehicle button"],
        order = 120,
        hidden = function()
            return getFrame() == nil
        end,
        args = { position = app.core:GetNativePositionOptions(getFrame, scale) },
    },
}
