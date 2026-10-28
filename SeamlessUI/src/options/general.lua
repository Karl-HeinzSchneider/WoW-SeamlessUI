---@type string, SeamlessUI
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local editModeKeyboardOption
do
    local module = app.editModeKeyboard
    editModeKeyboardOption = {
        type = "toggle",
        order = 30,
        width = "full",
        name = L["Pass unused Edit Mode keys through"],
        desc = L["Let normal key bindings work while a Blizzard frame is selected in Edit Mode. Arrow adjustments, Shift, Escape and screenshots keep their normal behavior."],
        disabled = InCombatLockdown,
        get = function()
            return app.db.profile.editModeKeyboard
        end,
        set = function(_, value)
            app.db.profile.editModeKeyboard = value
            module:OnProfileRefresh()
        end,
    }
end
local xpBarTooltipOption
do
    local module = app.xpBarTooltip
    local function settings()
        return app.db.profile.xpBarTooltip
    end
    xpBarTooltipOption = {
        type = "group",
        feature = true,
        name = L["XP bar tooltip"],
        desc = L["Replaces the XP bar tooltip with a detailed one: rest state, XP and XP left, rested XP and the time to max rested. Configure the rested XP cap and accumulation rate below."],
        order = 20,
        args = {
            restedXPCap = {
                type = "range",
                order = 20,
                name = L["Rested XP cap (%)"],
                desc = L["Percentage of one level's XP. Default: 150%. Adjust for perks that increase your cap; the client does not expose the cap directly."],
                min = 1,
                max = 500,
                step = 1,
            },
            restedXPRate = {
                type = "range",
                order = 30,
                name = L["Rested XP per 8 hours (%)"],
                desc = L["Percentage of one level accumulated per eight hours in an inn or city. Default: 5%. Adjust for perks or other bonuses; the estimate assumes no rested XP is spent."],
                min = 0.1,
                max = 100,
                step = 0.1,
            },
            completedQuests = {
                type = "toggle",
                order = 10,
                width = "full",
                name = L["Show completed quests"],
                desc = L["Adds the number of completed quests in your log and their total XP reward."],
                descStyle = "inline",
            },
        },
        settings = settings,
        toggled = function()
            module:OnProfileRefresh()
        end,
    }
end
---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        return app.core:GetOptionDefault(app.dbDefaults.profile, path, 2)
    end,
    defaults = {
        profile = {
            editModeKeyboard = true,
            editModeHistory = true,
            xpBarTooltip = {
                enabled = true,
                completedQuests = true,
                restedXPCap = 150,
                restedXPRate = 5,
            },
        },
    },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
            editModeKeyboard = editModeKeyboardOption,
            editModeHistory = {
                type = "toggle",
                order = 40,
                width = "full",
                name = L["Edit Mode history"],
                desc = L["Show the last 25 frame changes beside Edit Mode and undo the latest change. History resets when you leave Edit Mode or change layouts or profiles."],
                disabled = InCombatLockdown,
                get = function()
                    return app.db.profile.editModeHistory
                end,
                set = function(_, value)
                    app.db.profile.editModeHistory = value
                    app.editModeHistory:OnProfileRefresh()
                end,
            },
            xpBarTooltip = xpBarTooltipOption,
        },
    },
}
