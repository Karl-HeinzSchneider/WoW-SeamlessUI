---@type string, SeamlessUnitframes
local appName, app = ...

local log = app.logger
local addon = app.addon

-- The addon's options as one AceConfig table, shown in the game's Settings panel (AddOns tab) and
-- in a standalone window (`/seamlessunitframes`), so an option is added here once.
---@class SeamlessUnitframes.Options : AceModule
local module = {}
app.options = addon:NewModule("Options", module) --[[@as SeamlessUnitframes.Options]]

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
    name = appName,
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
            desc = "How much "
                .. appName
                .. " writes to the chat window. Same as /seamlessunitframes loglevel <level>.",
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
        classColor = {
            type = "group",
            order = 30,
            name = "Class Colors",
            args = {
                enabled = {
                    type = "toggle",
                    order = 10,
                    width = "full",
                    name = "Class colored health bars",
                    desc = "Colors the health bar of a player in their class color. NPCs keep the default green.",
                    get = function()
                        return app.db.profile.classColor.enabled
                    end,
                    set = function(_, value)
                        app.db.profile.classColor.enabled = value
                        app.classColor:Refresh()
                    end,
                },
                frames = {
                    type = "group",
                    inline = true,
                    order = 20,
                    name = "Unit frames",
                    disabled = function()
                        return not app.db.profile.classColor.enabled
                    end,
                    args = {}, -- one toggle per app.classColor.frames entry, added in OnInitialize
                },
            },
        },
    },
}

-- A toggle for every unit frame class colors can be switched on, in app.classColor.frames order.
local function AddClassColorFrameToggles()
    local args = options.args.classColor.args.frames.args
    for i, entry in ipairs(app.classColor.frames) do
        args[entry.key] = {
            type = "toggle",
            order = i,
            name = entry.name,
            desc = entry.key == "pet" and "A pet takes its owner's class color." or nil,
            -- A frame this client doesn't have gets no option.
            hidden = function()
                return entry.frameName ~= nil and _G[entry.frameName] == nil
            end,
            get = function()
                return app.db.profile.classColor.frames[entry.key]
            end,
            set = function(_, value)
                app.db.profile.classColor.frames[entry.key] = value
                app.classColor:Refresh()
            end,
        }
    end
end

-- Runs after addon:OnInitialize, so app.db is available.
function module:OnInitialize()
    AddClassColorFrameToggles()

    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(app.db)
    options.args.profiles.order = 100

    LibStub("AceConfig-3.0"):RegisterOptionsTable(appName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(appName)
end

-- Toggles the options in a standalone window.
function module:Open()
    local dialog = LibStub("AceConfigDialog-3.0")
    if dialog.OpenFrames[appName] then
        dialog:Close(appName)
    else
        dialog:Open(appName)
    end
end

-- Redraws the options wherever they are shown, after a setting changed outside of them.
function module:Refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
end

-- A profile switch, copy or reset changes every value.
function module:OnProfileRefresh()
    self:Refresh()
end
