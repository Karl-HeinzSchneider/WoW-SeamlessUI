---@type string, SeamlessUnitframes
local appName, app = ...

app.optionPages = {}
app.dbDefaults = {
    profile = {
        unitFrames = {
            ["**"] = { healthBarColor = "classReaction", nameDisplay = "full", classIcon = false, hidePvPIcon = false },
        },
        totPositions = { ["*"] = {} },
    },
    char = {},
    global = { dbVersion = 1 },
}
