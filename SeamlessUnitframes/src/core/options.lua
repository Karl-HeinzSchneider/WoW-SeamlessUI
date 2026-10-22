---@type string, SeamlessUnitframes
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

---@class SeamlessUnitframes.Options : AceModule, AceEvent-3.0
local module = {}
app.options = app.addon:NewModule("Options", module, "AceEvent-3.0") --[[@as SeamlessUnitframes.Options]]

---One style row (style.lua) as an AceConfig option.
---@param row SeamlessCore.EditModeSystemOption
---@param order number
local function Option(row, order)
    local option = {
        type = row.type,
        order = order,
        name = row.name,
        new = row.new,
        blizzard = row.blizzard,
        desc = row.desc,
        get = function()
            return row.get()
        end,
        set = function(_, value)
            row.set(value)
        end,
        hidden = row.hidden,
        disabled = row.disabled,
    }
    if row.type == "toggle" then
        option.width = "full"
        option.descStyle = "inline"
    elseif row.type == "select" then
        option.values, option.sorting = {}, {}
        for _, entry in ipairs(row.values) do
            option.values[entry.value] = entry.text
            option.sorting[#option.sorting + 1] = entry.value
        end
    elseif row.type == "range" then
        option.min, option.max, option.step = row.min, row.max, row.step
    end
    return option
end

-- Standalone style rows need no heading; keep groups for related controls.
---@param entry SeamlessUnitframes.UnitFrame
---@param order number
local function FrameTab(entry, order)
    local args = {}
    for i, group in ipairs(app.StyleGroups(entry.key)) do
        if #group.rows == 1 then
            local row = group.rows[1]
            args[row.key:gsub("%.", "_")] = Option(row, i * 10)
        else
            local groupArgs = {}
            for j, row in ipairs(group.rows) do
                groupArgs[row.key:gsub("%.", "_")] = Option(row, j * 10)
            end
            args["group" .. i] = { type = "group", inline = true, order = i * 10, name = group.name, args = groupArgs }
        end
    end
    return {
        order = order,
        name = entry.name,
        hidden = function()
            return not app.unitFrames:Exists(entry)
        end,
        args = args,
    }
end

function module:OnInitialize()
    local tabs = {}
    for i, entry in ipairs(app.unitFrames.list) do
        tabs[entry.key] = FrameTab(entry, i * 10)
    end
    app.core:RegisterOptions(appName, {
        tooltip = function(path)
            local key = path[#path]
            local defaults = app.dbDefaults.profile
            if path[1] == "general" then
                return defaults[key]
            end
            if key == "threatPercentage" then
                return app.core:GetCVarOptionInfo("threatShowNumeric")
            end
            local questKey = key:match("^questIcon_(.+)$")
            if questKey then
                return defaults.targetQuestIcon[questKey]
            end
            local field = key:match("^[^_]+_(.+)$")
            local frame = defaults.unitFrames[path[1]] or {}
            if frame[field] ~= nil then
                return frame[field]
            end
            return defaults.unitFrames["**"][field]
        end,
        title = L["Unit Frames"],
        general = {
            layout = {
                type = "select",
                order = 1,
                name = L["Unit frame layout"],
                desc = L["Current leaves the game's layout unchanged. Legacy restores the exported pre-70425 artwork and layout. Changes made during combat apply when combat ends."],
                values = { current = L["Current (70425)"], legacy = L["Legacy (before 70425)"] },
                sorting = { "current", "legacy" },
                get = function()
                    return app.db.profile.layout
                end,
                set = function(_, value)
                    app.db.profile.layout = value
                    app.legacyLayout:Refresh()
                end,
            },
        },
        tabs = tabs,
    })
end

function module:OnEnable()
    self:RegisterEvent("CVAR_UPDATE", function(_, name)
        if name:lower() == "threatshownumeric" then
            self:Refresh()
        end
    end)
end

function module:OnProfileRefresh()
    app.core:RefreshEditModeSystemOptions()
end

---@param tab? string
function module:Open(tab)
    app.core:OpenOptions(appName, tab)
end

function module:Refresh()
    app.core:RefreshOptions(appName)
    app.core:RefreshEditModeSystemOptions()
end
