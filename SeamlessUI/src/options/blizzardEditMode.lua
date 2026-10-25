---@type string, SeamlessUI
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local module = app.blizzardEditMode
local frames, categories = module:GetOptionsFrames()
local function settings()
    return app.db.profile.blizzardEditMode
end
local function available(spec)
    return module:IsOptionsFrameAvailable(spec)
end
local function globalToggle(order, key, name, desc)
    return {
        type = "toggle",
        order = order,
        width = "full",
        name = name,
        desc = desc,
        descStyle = "inline",
        disabled = order > 1 and function()
            return not settings().enabled
        end or nil,
        get = function()
            return settings()[key]
        end,
        set = function(_, value)
            settings()[key] = value
            if key == "enabled" then
                module:OnProfileRefresh()
            else
                module:SyncSettingsDialogs()
                module:RefreshPanel()
            end
        end,
    }
end
local args = {
    enabled = globalToggle(
        1,
        "enabled",
        L["Enable Blizzard Edit Mode extensions"],
        L["Adds a SeamlessUI window below the selected Blizzard frame's Edit Mode settings. Turn off to disable all extensions."]
    ),
    addPosition = globalToggle(
        2,
        "addPosition",
        L["Add position"],
        L["Adds Scale, Anchor, AnchorParent, AnchorFrame, X and Y controls to every frame's Edit Mode extension."]
    ),
    addMoreOptions = globalToggle(
        3,
        "addMoreOptions",
        L["Add more options"],
        L["Reserved for future frame options. This setting has no effect yet."]
    ),
    snapSettingsDialog = globalToggle(
        4,
        "snapSettingsDialog",
        L["Move settings next to the Edit Mode window"],
        L["Places a frame's Edit Mode settings to the right of the Edit Mode window each time you select a frame. You can still drag them anywhere."]
    ),
}
for categoryOrder, category in ipairs(categories) do
    args[category.key .. "Heading"] = {
        type = "header",
        order = categoryOrder * 1000,
        name = category.name,
        hidden = function()
            for _, spec in ipairs(frames) do
                if spec.category == category.key and available(spec) then
                    return false
                end
            end
            return true
        end,
    }
end
for order, spec in ipairs(frames) do
    local key = spec.key
    local categoryOrder = 1
    for index, category in ipairs(categories) do
        if category.key == spec.category then
            categoryOrder = index
        end
    end
    args[key] = {
        type = "toggle",
        order = categoryOrder * 1000 + order,
        width = "full",
        name = string.format(L["%s - Extend Edit Mode"], spec.name),
        desc = L["Show the SeamlessUI extension when this frame is selected in Edit Mode. Turn off if this frame causes issues."],
        hidden = function()
            return not available(spec)
        end,
        disabled = function()
            return not settings().enabled
        end,
        get = function()
            return settings().frames[key].enabled
        end,
        set = function(_, value)
            settings().frames[key].enabled = value
            module:RefreshPanel()
        end,
    }
end
---@type SeamlessCore.SettingsPage
app.optionPages.blizzardEditMode = {
    tooltip = function(path)
        local defaults = app.dbDefaults.profile.blizzardEditMode
        if defaults[path[2]] ~= nil then
            return defaults[path[2]]
        end
        return app.core:GetOptionDefault(defaults.frames, { path[2], "enabled" })
    end,
    defaults = {
        profile = {
            blizzardEditMode = {
                enabled = true,
                -- Global switches for every frame's extension; combined with the internal per-frame
                -- values below (addMoreOptions only stores a preference for future controls).
                addPosition = true,
                addMoreOptions = true,
                -- Snaps the native settings dialog right of the Edit Mode window on each selection.
                snapSettingsDialog = true,
                frames = {
                    ["*"] = { enabled = true, addPosition = true, addMoreOptions = true },
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Blizzard Edit Mode Extensions"],
        order = 30,
        args = args,
    },
}
