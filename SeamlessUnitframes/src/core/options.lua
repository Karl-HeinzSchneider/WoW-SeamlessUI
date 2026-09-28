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
    },
}

-- The choices of the health bar color option (src/healthcolor), in this order.
local healthBarColorNames = {
    default = "Default",
    class = "Class",
    reaction = "Reaction",
    classReaction = "Class, reaction for NPCs",
}
local healthBarColorOrder = { "default", "class", "reaction", "classReaction" }

-- The options of one unit frame, stored in profile.unitFrames[entry.key]. A new per-frame option
-- goes here.
---@param entry SeamlessUnitframes.UnitFrame
---@param order integer
local function UnitFrameOptions(entry, order)
    local function settings()
        return app.db.profile.unitFrames[entry.key]
    end

    local healthBarColorDesc = "Default: the game's green."
        .. "\nClass: players in their class color, NPCs keep the default."
        .. "\nReaction: red for hostile, yellow for neutral, green for friendly, grey for a mob"
        .. " someone else tagged."
        .. "\nClass, reaction for NPCs: both."
    if entry.key == "pet" then
        healthBarColorDesc = healthBarColorDesc .. "\n\nA pet takes its owner's class color."
    end

    return {
        type = "group",
        order = order,
        name = entry.name,
        -- A frame this client doesn't have gets no options.
        hidden = function()
            return not app.unitFrames:Exists(entry)
        end,
        args = {
            healthBarColor = {
                type = "select",
                order = 10,
                name = "Health bar color",
                desc = healthBarColorDesc,
                values = healthBarColorNames,
                sorting = healthBarColorOrder,
                get = function()
                    return settings().healthBarColor
                end,
                set = function(_, value)
                    settings().healthBarColor = value
                    app.healthColor:Refresh()
                end,
            },
            threatPercentage = {
                type = "toggle",
                order = 20,
                name = "Show threat percentage",
                desc = "Show the game's threat percentage badge above the target frame. This is"
                    .. " the client-wide numeric threat setting and can also affect other stock"
                    .. " frames that support it.",
                hidden = entry.key ~= "target",
                get = function()
                    return GetCVarBool("threatShowNumeric")
                end,
                set = function(_, value)
                    SetCVar("threatShowNumeric", value and "1" or "0")
                end,
            },
        },
    }
end

-- A group per unit frame, after the general options and before the profiles.
for i, entry in ipairs(app.unitFrames.list) do
    options.args[entry.key] = UnitFrameOptions(entry, 30 + i)
end

-- Runs after addon:OnInitialize, so app.db is available.
function module:OnInitialize()
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
