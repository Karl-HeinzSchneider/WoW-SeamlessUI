---@type string, SeamlessUI
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUI.Options : AceModule
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessUI.Options]]

function module:OnInitialize()
    app.core:RegisterOptions(appName, {
        title = L["UI"],
        general = {
            description = {
                type = "description",
                order = 10,
                name = L["General UI improvements for the Seamless suite."],
                fontSize = "medium",
            },
            xpBarTooltip = app.xpBarTooltip:Options(),
        },
        tabs = {
            blizzardEditMode = app.blizzardEditMode:Options(),
        },
        db = app.db,
    })
end

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end
