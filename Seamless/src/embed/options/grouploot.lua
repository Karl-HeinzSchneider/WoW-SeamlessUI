---@type string, SeamlessCore
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local defaults = LibStub("BetterGroupLoot-1.0").defaults
local options = app.embed.groupLoot

-- Both the custom panel and Edit Mode consume this page through the option model.
local position, size = app.addon:GetPositionOptions(options.position)
-- Bounds and steps match BetterGroupLoot-1.0/rolls/editmode.lua.
size.args = {
    scale = { type = "range", name = L["Scale"], order = 1, min = 0.5, max = 2, step = 0.05, default = defaults.scale },
    spacing = {
        type = "range",
        name = L["Spacing"],
        desc = L["Gap between two rolls."],
        order = 2,
        min = 0,
        max = 40,
        step = 1,
        default = defaults.spacing,
    },
}

app.embed:RegisterOptions("groupLoot", {
    -- Values live in the existing GroupLoot namespace, whose defaults come from the library.
    defaults = { profile = {} },
    config = {
        type = "group",
        name = L["Group loot"],
        order = 10,
        editModeFrame = function()
            return options:GetFrame()
        end,
        buttonSection = app.addon:GetEditModeButtonSection({
            app.addon:GetEditModePositionButton("revert"),
            app.addon:GetEditModePositionButton("resetPosition"),
        }),
        disabled = function()
            return options:Disabled()
        end,
        get = function(info)
            return options:GetProfile()[info[#info]]
        end,
        set = function(info, value)
            if not options:Disabled() then
                options:GetProfile()[info[#info]] = value
                options:Changed()
            end
        end,
        args = {
            position = position,
            size = size,
            style = {
                type = "group",
                name = L["Style"],
                inline = true,
                order = 20,
                args = {
                    growUp = {
                        type = "toggle",
                        name = L["Stack upwards"],
                        desc = L["New rolls appear above the first one. Off: below it."],
                        order = 1,
                        default = defaults.growUp,
                    },
                    showUndecided = {
                        type = "toggle",
                        name = L["List undecided players"],
                        desc = L["The roll buttons' tooltips also list who hasn't chosen yet."],
                        order = 2,
                        default = defaults.showUndecided,
                    },
                },
            },
        },
    },
})
