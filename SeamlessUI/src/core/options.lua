---@type string, SeamlessUI
local appName, app = ...

---@class SeamlessUI.Options : AceModule
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessUI.Options]]

function module:OnInitialize()
    app.core:RegisterOptions(appName, {
        title = "UI",
        general = {
            description = {
                type = "description",
                order = 10,
                name = "General UI improvements for the Seamless suite. No improvements are available yet.",
                fontSize = "medium",
            },
        },
        db = app.db,
    })
end

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end
