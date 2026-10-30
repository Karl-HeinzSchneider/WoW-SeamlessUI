---@type string, SeamlessCore
local _, coreApp = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessCore.GroupLoot : BetterGroupLoot, AceEvent-3.0
---@field controller? BetterGroupLoot.Rolls
---@field active? boolean
---@field requested? boolean
---@field preview boolean
---@field defaults table
---@field positionSpec SeamlessCore.EditModePosition
---@field styleSettings table[]
---@field editModeVisibility fun(value?: boolean): boolean?
local app = { preview = true }
coreApp.groupLoot = app
LibStub("AceEvent-3.0"):Embed(app)

app.logger = {}
for _, level in ipairs({ "debug", "error", "chat" }) do
    app.logger[level] = function(_, message, ...)
        coreApp.logger[level](coreApp.logger, L[message], ...)
    end
end
app.rollStrings = {
    need = NEED or L["Need"],
    greed = GREED or L["Greed"],
    transmog = TRANSMOGRIFICATION or L["Transmog"],
    disenchant = ROLL_DISENCHANT or L["Disenchant"],
    pass = PASS or L["Pass"],
    undecided = L["Undecided"],
    offSpec = L["off spec"],
    noData = L["No roll data yet."],
    nobody = L["Nobody yet."],
}
