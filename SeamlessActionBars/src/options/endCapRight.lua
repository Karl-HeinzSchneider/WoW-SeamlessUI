---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local entry = app.endCaps[2]
local function getFrame()
    return app.EndCapFrame(entry)
end
local position, size = app.core:GetNativePositionOptions(getFrame)
size.layoutStored = nil
size.args.scale = app.EndCapScaleOption(entry)
---@type SeamlessCore.SettingsPage
app.optionPages.endCapRight = {
    defaults = { profile = { endCaps = { right = { texture = "default", scale = 1 } } } },
    config = {
        editModeFrame = getFrame,
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
        }),
        type = "group",
        name = entry.name,
        order = 150,
        hidden = function()
            return getFrame() == nil
        end,
        args = {
            hidden = app.EndCapHiddenOption(entry),
            texture = app.EndCapTextureOption(entry),
            position = position,
            size = size,
        },
    },
}
