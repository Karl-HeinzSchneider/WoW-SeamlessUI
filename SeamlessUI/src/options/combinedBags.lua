---@type string, SeamlessUI
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local position, size = app.core:GetPositionOptions(app.combinedBags:GetPositionBinding())
size.args.scale = {
    type = "range",
    name = L["Scale"],
    order = 0,
    min = 0.75,
    max = 2,
    step = 0.01,
    -- ContainerFrame.lua: GetContainerScale starts at 1 before fitting bags to the screen.
    default = 1,
    disabled = function()
        return InCombatLockdown() or not app.combinedBags:IsEnabled() or not ContainerFrameCombinedBags
    end,
    get = function()
        return app.db.profile.combinedBags.scale
    end,
    set = function(_, value)
        if InCombatLockdown() or not app.combinedBags:IsEnabled() then
            return
        end
        app.db.profile.combinedBags.scale = math.max(0.75, math.min(2, value))
        app.combinedBags:Refresh()
    end,
}
app.optionPages.combinedBags = {
    defaults = { profile = { combinedBags = { layouts = {}, positionInCombat = false, scale = 1 } } },
    config = {
        type = "group",
        name = L["Combined bags"],
        order = 20,
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
            positionInCombat = {
                type = "toggle",
                order = 1,
                name = L["Keep position in combat"],
                default = false,
                get = function()
                    return app.db.profile.combinedBags.positionInCombat
                end,
                set = function(_, value)
                    app.db.profile.combinedBags.positionInCombat = value
                    app.combinedBags:Refresh()
                    app.core:RefreshOptions("SeamlessUI")
                end,
            },
            position = position,
            size = size,
        },
    },
}
