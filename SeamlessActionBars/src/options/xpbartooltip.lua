---@type string, SeamlessActionBars
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

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
        desc = L["Replaces the XP bar tooltip with a detailed one: rest state, XP and XP left, rested XP and the time to max rested. Detect Well Rested automatically or configure the rested XP cap and accumulation rate below."],
        order = 20,
        args = {
            automaticRestedXP = {
                type = "toggle",
                order = 15,
                width = "full",
                name = L["Detect Well Rested automatically"],
                desc = L["Uses your purchased Well Rested ranks for the rested XP cap and rate. The manual values are used if Legacy data is unavailable."],
            },
            restedXPCap = {
                disabled = function()
                    return not settings().enabled or settings().automaticRestedXP
                end,
                type = "range",
                order = 20,
                name = L["Rested XP cap (%)"],
                desc = L["Percentage of one level's XP. Default: 150%. Adjust for perks that increase your cap; the client does not expose the cap directly."],
                min = 1,
                max = 500,
                step = 1,
            },
            restedXPRate = {
                disabled = function()
                    return not settings().enabled or settings().automaticRestedXP
                end,
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
app.XPBarTooltipOptions = function()
    return xpBarTooltipOption
end

-- Derive Edit Mode rows from the same prepared declaration used by both settings pages.
local registered = false
function app.RegisterXPTooltipEditMode()
    if registered or not (Enum.EditModeSystem and Enum.EditModeSystem.StatusTrackingBar) then
        return
    end
    local page = app.optionPages.statusBar1
    local root = { type = "group", args = { statusBar1 = page.config } }
    local group = app.core:GetSettingsOption(root, { "statusBar1", "xpBarTooltip" }, "SeamlessActionBars")
    local rows = {}
    for _, option in ipairs(group:Children()) do
        local key = option.path[#option.path]
        rows[#rows + 1] = {
            key = key,
            type = option:Read("type"),
            name = option:Read("name"),
            desc = option:Read("desc"),
            min = option:Read("min"),
            max = option:Read("max"),
            step = option:Read("step"),
            get = function()
                return option:Read("get")
            end,
            set = function(value)
                option:Read("set", value)
                app.core:RefreshOptions("SeamlessActionBars")
            end,
            disabled = function()
                return option:Read("disabled")
            end,
            default = function()
                return page.tooltip(option.path)
            end,
        }
    end
    app.core:RegisterEditModeSystemOptions("SeamlessActionBars:xpBarTooltip", {
        system = Enum.EditModeSystem.StatusTrackingBar,
        name = xpBarTooltipOption.name,
        key = "SeamlessActionBars:xpBarTooltip",
        enabled = function()
            return app.addon:IsEnabled()
        end,
        options = rows,
    })
    registered = true
end
