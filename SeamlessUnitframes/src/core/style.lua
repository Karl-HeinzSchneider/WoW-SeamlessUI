---@type string, SeamlessUnitframes
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local linkedNames = {
    targettarget = {
        nameDisplay = L["Target of Target name display"],
        classIcon = L["Target of Target class icon"],
        healthBarColor = L["Target of Target health bar color"],
    },
    focustarget = {
        nameDisplay = L["Target of Focus name display"],
        classIcon = L["Target of Focus class icon"],
        healthBarColor = L["Target of Focus health bar color"],
    },
}

local function rowsFor(key)
    local config = app.optionPages[key].config
    local root = { type = "group", args = { [key] = { type = "group", args = config.args } } }
    local rows = {}
    local function visit(option)
        local kind = option:Read("type")
        if kind == "group" then
            for _, child in ipairs(option:Children()) do
                visit(child)
            end
        elseif kind == "toggle" or kind == "select" or kind == "range" then
            local path = option.path
            local id = path[#path]
            local frame, field = id:match("^([^_]+)_(.+)$")
            local row = {
                key = frame and (frame .. "." .. field) or id,
                type = kind,
                name = option:Read("name"),
                desc = option:Read("desc"),
                get = function()
                    return option:Read("get")
                end,
                set = function(value)
                    option:Read("set", value)
                end,
                disabled = function()
                    return option:Read("disabled")
                end,
                default = function()
                    if id == "threatPercentage" then
                        return app.core:GetCVarOptionInfo("threatShowNumeric")
                    end
                    local defaults = app.dbDefaults.profile
                    if frame == "questIcon" then
                        return defaults.targetQuestIcon[field]
                    end
                    return defaults.unitFrames[key][field]
                end,
            }
            if kind == "select" then
                row.values = {}
                for _, choice in ipairs(option:Choices()) do
                    row.values[#row.values + 1] = { value = choice.value, text = choice.text }
                end
            elseif kind == "range" then
                row.min, row.max, row.step = option:Read("min"), option:Read("max"), option:Read("step")
                if row.step < 1 then
                    row.format = function(value)
                        return ("%.1f"):format(value)
                    end
                end
            end
            rows[#rows + 1] = row
        end
    end
    -- Position is handled separately by Edit Mode's shared position section.
    local style = config.args.style and { key, "style" } or { key }
    visit(app.core:GetSettingsOption(root, style, appName))
    return rows
end

function app.StyleOptions(entry)
    local rows = rowsFor(entry.key)
    for _, linked in ipairs(app.unitFrames.list) do
        if linked.linkedTo == entry.key then
            for _, row in ipairs(rowsFor(linked.key)) do
                row.name = linkedNames[linked.key][row.key:match("%.(.+)$")] or row.name
                row.hidden = function()
                    return not app.unitFrames:Exists(linked)
                end
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end
