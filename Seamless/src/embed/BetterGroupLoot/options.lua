---@type string, SeamlessCore
local _, coreApp = ...
local app, core = coreApp.groupLoot, coreApp.addon
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local lib = core:GetEditModeLibrary()

app.defaults = {
    position = { point = "BOTTOM", relativePoint = "BOTTOM", relativeTo = "UIParent", x = 600, y = 420 },
    scale = 1,
    growUp = true,
    spacing = 8,
    showUndecided = true,
}
-- The same upstream rows supply both settings surfaces. Core's Position section
-- owns Scale, so the upstream helper contributes only the remaining style rows.
app.styleSettings = app.RollController.GetEditModeSettings(app, lib, {
    defaults = app.defaults,
    omitScale = true,
    strings = {
        spacing = L["Spacing"],
        spacingDescription = L["Gap between two rolls."],
        growUp = L["Stack upwards"],
        growUpDescription = L["New rolls appear above the first one. Off: below it."],
        showUndecided = L["List undecided players"],
        showUndecidedDescription = L["The roll buttons' tooltips also list who hasn't chosen yet."],
    },
})
local style = {}
for order, row in ipairs(app.styleSettings) do
    style[row.key] = {
        type = row.kind == lib.SettingType.Slider and "range" or "toggle",
        name = row.name,
        desc = row.desc,
        order = order,
        default = row.default,
        min = row.minValue,
        max = row.maxValue,
        step = row.valueStep,
        get = row.get,
        set = row.set,
        disabled = row.disabled,
    }
end
coreApp.optionPages.groupLoot = {
    defaults = { profile = { groupLoot = app.defaults } },
    config = {
        type = "group",
        name = L["Group loot"],
        order = 610,
        hidden = function()
            return not coreApp.db.profile.embed.BetterGroupLoot
        end,
        disabled = function()
            return not app.active
        end,
        editModeVisibility = app.editModeVisibility,
        buttonSection = core:GetEditModeButtonSection({
            core:GetEditModePositionButton("revert"),
            core:GetEditModePositionButton("resetPosition"),
        }),
        args = {
            position = core:GetPositionOptions(app.positionSpec),
            style = { type = "group", name = L["Style"], inline = true, order = 20, args = style },
        },
    },
}
