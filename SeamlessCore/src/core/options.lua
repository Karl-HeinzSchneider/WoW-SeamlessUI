---@type string, SeamlessCore
local appName, app = ...

local log = app.logger
local addon = app.addon

-- The addon's options as one AceConfig table, shown in the game's Settings panel (AddOns tab) and
-- in a standalone window (`/seamless`), so an option is added here once.
---@class SeamlessCore.Options : AceModule
local module = {}
app.options = addon:NewModule("Options", module) --[[@as SeamlessCore.Options]]

-- The log levels for the select, quietest first, shown as "Info" for "INFO".
local levelNames, levelOrder = {}, {}
for name in pairs(log.level) do
    levelNames[name] = name:sub(1, 1) .. name:sub(2):lower()
    levelOrder[#levelOrder + 1] = name
end
table.sort(levelOrder, function(a, b)
    return log.level[a] < log.level[b]
end)

local options = {
    type = "group",
    name = "Seamless",
    args = {
        minimap = {
            type = "toggle",
            order = 10,
            width = "full",
            name = "Show minimap button",
            desc = "The minimap button opens these options.",
            get = function()
                return not app.db.profile.minimap.hide
            end,
            set = function(_, value)
                app.db.profile.minimap.hide = not value
                app.minimapButton:OnProfileRefresh()
            end,
        },
        logLevel = {
            type = "select",
            order = 20,
            name = "Log level",
            desc = "How much " .. appName .. " writes to the chat window. Same as /seamless loglevel <level>.",
            values = levelNames,
            sorting = levelOrder,
            get = function()
                return app.db.profile.logLevel
            end,
            set = function(_, value)
                if log:setLevel(value) then
                    app.db.profile.logLevel = log:getLevelName()
                end
            end,
        },
    },
}

-- Each enabled addon contributes a group; disabled addons never load or register.
---@param name string
---@param group table
function module:RegisterAddon(name, group)
    assert(not options.args[name], "Duplicate Seamless options: " .. name)
    options.args[name] = group
    self:Refresh()
end

function module:OnInitialize()
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(app.db)
    options.args.profiles.name = "Core profiles"
    options.args.profiles.order = 1000
    LibStub("AceConfig-3.0"):RegisterOptionsTable(appName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(appName, "Seamless")
end

function module:Open(group)
    local dialog = LibStub("AceConfigDialog-3.0")
    if not group and dialog.OpenFrames[appName] then
        dialog:Close(appName)
    else
        dialog:Open(appName)
        if group then
            dialog:SelectGroup(appName, group)
        end
    end
end

function module:Refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
end

function module:OnProfileRefresh()
    self:Refresh()
end
