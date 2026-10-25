---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local entry = app.endCaps[2]
local function getFrame()
    return app.EndCapFrame(entry)
end
local scale = app.EndCapScale(entry)
---@type SeamlessCore.SettingsPage
app.optionPages.endCapRight = {
    defaults = { profile = { endCaps = { right = { scale = 1 } } } },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({ "revert", "resetPosition" }),
        type = "group",
        name = entry.name,
        order = 150,
        hidden = function()
            return getFrame() == nil
        end,
        args = { hidden = app.EndCapHiddenOption(entry), position = app.core:GetNativePositionOptions(getFrame, scale) },
    },
}
