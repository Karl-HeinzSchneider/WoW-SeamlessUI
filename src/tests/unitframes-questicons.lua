-- Run from the repository root: lua src/tests/unitframes-questicons.lua
local app = {}
local secret = setmetatable({}, {
    __index = function()
        error("restricted text must not be inspected")
    end,
})
canaccessvalue = function(value)
    return value ~= secret
end
Enum = { TooltipDataLineType = { QuestObjective = 8 } }
local lines, scans = {}, 0
UnitExists = function()
    return true
end
C_TooltipInfo = {
    GetUnit = function()
        return { lines = lines }
    end,
}
C_QuestLog = {
    GetNumQuestLogEntries = function()
        scans = scans + 1
        return 1
    end,
    GetInfo = function()
        return { questID = 1 }
    end,
    GetQuestObjectives = function()
        return { { text = "Wolves: 0/3", type = "monster", finished = false } }
    end,
}
assert(loadfile("SeamlessUnitframes/src/core/questicons.lua"))("SeamlessUnitframes", app)
local function check(expected, ...)
    lines = { ... }
    assert(app.questIcons:ForUnit("target") == expected)
end
local slay = { type = 8, completed = false, leftText = "- Wolves: 0/3  " }
check("slay", slay)
check(nil, { type = 8, completed = true })
scans = 0
check(nil, { type = 8, completed = secret, leftText = secret })
assert(scans == 0, "restricted completion must not trigger quest-log matching")
check(nil, { type = secret, completed = false, leftText = secret })
check("slay", { type = 8, completed = secret }, slay)
check("loot", { type = 8, completed = false, leftText = secret })
check("loot", { type = 8, completed = false, leftText = "Unknown objective" })
check("loot", { type = 8, completed = false })
check(nil)
canaccessvalue = nil
check("slay", slay)
print("unitframes-questicons: OK")
