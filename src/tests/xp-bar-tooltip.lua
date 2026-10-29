-- XP tooltip assumptions belong to SeamlessActionBars, with one-way import from Core.
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
assert(loadfile("SeamlessActionBars/src/xpbartooltip.lua"))("SeamlessActionBars", app)
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
assert(loadfile("SeamlessActionBars/src/options/xpbartooltip.lua"))("SeamlessActionBars", app)
local options = app.XPBarTooltipOptions()
assert(options.args.restedXPCap and options.args.restedXPRate)
assert(options.settings() == profile)
-- Every purchased rank changes both values; staged preview ranks are ignored.
Constants = { LegacyConsts = { LEGACY_TREE_ADVENTURE_ID = 1188 } }
local rank = 0
C_Traits = {
    GetConfigIDByTreeID = function(tree)
        assert(tree == 1188)
        return 1
    end,
    GetTreeNodes = function()
        return { 42 }
    end,
    GetNodeInfo = function()
        return { entryIDs = { 7 }, ranksPurchased = rank, ranksIncreased = 5 - rank }
    end,
    GetEntryInfo = function()
        return { definitionID = 9 }
    end,
    GetDefinitionInfo = function()
        return { spellID = 1225478 }
    end,
}
profile.automaticRestedXP = true
for value = 0, 5 do
    rank = value
    local cap, rate = module:GetRestedValues()
    assert(math.abs(cap - 150 * (1 + value * 0.04)) < 0.00001)
    assert(math.abs(rate - 5 * (1 + value * 0.04)) < 0.00001)
end
profile.automaticRestedXP = false
local cap, rate = module:GetRestedValues()
assert(cap == 250 and rate == 5)
-- Import UI profiles even when that addon is disabled, once only.
app.core.db.sv = {
    namespaces = { SeamlessUI = { profiles = { Other = { xpBarTooltip = { enabled = false, restedXPCap = 180 } } } } },
}
module:OnInitialize()
assert(app.db.profiles.Other.xpBarTooltip.enabled == false)
assert(app.db.profiles.Other.xpBarTooltip.restedXPCap == 180)
assert(app.core.db.sv.namespaces.SeamlessUI.profiles.Other.xpBarTooltip == nil)
print("Action Bars XP tooltip ownership, migration and Well Rested ranks OK")
