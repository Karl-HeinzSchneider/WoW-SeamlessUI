---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local entry = app.endCaps[1]
local function getFrame()
    return app.EndCapFrame(entry)
end
local scale = app.EndCapScale(entry)
---@type SeamlessCore.SettingsPage
app.optionPages.endCapLeft = {
    defaults = { profile = { endCaps = { left = { scale = 1 } } } },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = entry.name,
        order = 140,
        hidden = function()
            return getFrame() == nil
        end,
        args = { hidden = app.EndCapHiddenOption(entry), position = app.core:GetNativePositionOptions(getFrame, scale) },
    },
}
