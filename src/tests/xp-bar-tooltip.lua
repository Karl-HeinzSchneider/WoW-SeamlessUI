-- XP tooltip assumptions belong to SeamlessUI, with one-way import from Core.
local module = {}
function module:SetEnabledState() end
local profile = { enabled = true, completedQuests = false, restedXPCap = 250 }
local coreProfile = { tweaks = { restedXPCap = 200, restedXPRate = 10, enhancedXPTooltip = false } }
local app = {
    addon = {
        NewModule = function()
            return module
        end,
    },
    core = {
        db = { profiles = { Default = coreProfile } },
        FeatureGroup = function(spec)
            return spec
        end,
    },
    db = { profile = { xpBarTooltip = profile }, profiles = { Default = { xpBarTooltip = profile } } },
}
function LibStub()
    return {
        GetLocale = function()
            return setmetatable({}, {
                __index = function(_, key)
                    return key
                end,
            })
        end,
    }
end
assert(loadfile("SeamlessUI/src/features/xpbartooltip.lua"))("SeamlessUI", app)
module:OnInitialize()
assert(profile.restedXPCap == 250 and profile.restedXPRate == 10)
assert(next(coreProfile.tweaks) == nil)
profile.restedXPRate = 5
module:OnInitialize()
assert(profile.restedXPRate == 5, "do not repeat migration")
local rows = {}
local tooltip = {
    NumLines = function()
        return 0
    end,
    AddLine = function() end,
    Show = function() end,
    AddDoubleLine = function(_, key, value)
        rows[key] = value
    end,
}
function GetAppropriateTooltip()
    return tooltip
end
function GameTooltip_SetDefaultAnchor() end
function GetRestState()
    return nil
end
function UnitXPMax()
    return 1000
end
function UnitXP()
    return 100
end
function GetXPExhaustion()
    return 500
end
function BreakUpLargeNumbers(value)
    return tostring(value)
end
GameRulesUtil = {
    IsPlayerAtEffectiveMaxLevel = function()
        return false
    end,
}
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
-- No Core db.profile/tweaks exists: tooltip calculations must be self-contained.
module:ShowTooltip()
assert(rows["Rested:"] == "500 (20.00%)")
assert(rows["Time to max rested:"] == "13d 8h 0m")
app.optionPages = {}
assert(loadfile("SeamlessUI/src/options/general.lua"))("SeamlessUI", app)
local options = app.optionPages.general.config.args.xpBarTooltip
assert(options.args.restedXPCap and options.args.restedXPRate)
assert(options.settings() == profile)
print("UI XP tooltip ownership and migration OK")
