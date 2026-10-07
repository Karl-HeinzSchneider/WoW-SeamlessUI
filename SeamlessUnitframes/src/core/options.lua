---@type string, SeamlessUnitframes
local appName, app = ...

---@class SeamlessUnitframes.Options : AceModule
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessUnitframes.Options]]

local options = { type = "group", name = "Unit frames", order = 100, args = {} }

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

function module:OnInitialize()
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(app.db)
    options.args.profiles.order = 100
    app.core:RegisterOptions(appName, options)
end

function module:Open()
    app.core:OpenOptions(appName)
end

function module:Refresh()
    app.core:RefreshOptions()
end

function module:OnProfileRefresh()
    self:Refresh()
end
