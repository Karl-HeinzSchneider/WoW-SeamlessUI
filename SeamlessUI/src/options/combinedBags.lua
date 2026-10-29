---@type string, SeamlessUI
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

app.optionPages.combinedBags = {
    defaults = { profile = { combinedBags = { layouts = {} } } },
    config = {
        type = "group",
        name = L["Combined bags"],
        order = 25,
        editModeVisibility = app.core:GetCustomEditModeVisibility("SeamlessUI.combinedBags", function()
            return app.combinedBags:EditModeVisibility()
        end, function(value)
            app.combinedBags:EditModeVisibility(value)
        end),
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            {
                name = L["Reset to default position"],
                disabled = function()
                    return InCombatLockdown()
                end,
                click = function()
                    app.combinedBags:ResetPosition()
                end,
            },
        }),
        args = {
            position = app.core:GetPositionOptions(app.combinedBags:GetPositionBinding()),
        },
    },
}
