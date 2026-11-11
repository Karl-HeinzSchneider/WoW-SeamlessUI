---@type string, SeamlessUI
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local position, size = app.core:GetPositionOptions(app.combinedBags:GetPositionBinding())
-- ContainerFrame.lua starts at native scale and may shrink bags to fit the screen.
-- This setting multiplies that native scale.
size.args.scale = {
    type = "range",
    name = L["Scale"],
    order = 1,
    min = 0.5,
    max = 2,
    step = 0.05,
    default = 1,
    disabled = InCombatLockdown,
    get = function()
        return app.db.profile.combinedBags.scale or 1
    end,
    set = function(_, value)
        if not InCombatLockdown() then
            app.db.profile.combinedBags.scale = value
            app.combinedBags:Refresh()
            app.core:RefreshOptions("SeamlessUI")
        end
    end,
}

app.optionPages.combinedBags = {
    defaults = { profile = { combinedBags = { layouts = {}, positionInCombat = false, scale = 1 } } },
    config = {
        type = "group",
        name = L["Bags"],
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
            useCombinedBags = {
                type = "toggle",
                order = 1,
                name = L["Combined bags"],
                default = function()
                    return app.core:GetCVarOptionInfo("combinedBags")
                end,
                disabled = function()
                    return InCombatLockdown() or (InputUtil and InputUtil.IsGamepadUIEnabled())
                end,
                get = function()
                    return GetCVarBool("combinedBags")
                end,
                set = function(_, value)
                    SetCVar("combinedBags", value)
                end,
            },
            positionInCombat = {
                type = "toggle",
                order = 2,
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
