---@type string, SeamlessTooltip
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local media = app.media
local LSM = media.LSM
local actionButtonAnchor = app.features:GetModule("ActionButtonAnchor")
local backdrop = app.features:GetModule("Backdrop")
local cursorAnchor = app.features:GetModule("CursorAnchor")
local scale = app.features:GetModule("Scale")
---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        if path[2] == "game" then
            return app.core:GetCVarOptionInfo(path[3])
        end
        local defaults = app.dbDefaults.profile.features[path[2]]
        return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
    end,
    defaults = {
        profile = {
            features = {
                ActionButtonAnchor = {
                    enabled = true,
                    position = "ANCHOR_RIGHT",
                },
                Backdrop = {
                    enabled = true,
                    background = "Blizzard Collections Background",
                    backgroundColor = { r = 0.09, g = 0.09, b = 0.19, a = 1 },
                    border = "Blizzard Tooltip",
                    borderColor = { r = 1, g = 1, b = 1, a = 1 },
                    edgeSize = 16,
                    inset = 4,
                },
                CursorAnchor = {
                    enabled = false,
                    position = "ANCHOR_CURSOR_RIGHT",
                    offsetX = 16,
                    offsetY = 0,
                },
                Scale = {
                    enabled = false,
                    scale = 1,
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
            ActionButtonAnchor = {
                type = "group",
                feature = true,
                name = L["Anchor to action buttons"],
                desc = L["Shows the tooltip of an action bar, pet bar or stance bar button next to that button."],
                order = 20,
                settings = function()
                    return actionButtonAnchor:Settings()
                end,
                toggled = function()
                    actionButtonAnchor:Refresh()
                end,
                changed = function()
                    actionButtonAnchor:SettingsChanged()
                end,
                args = {
                    position = {
                        type = "select",
                        order = 10,
                        name = L["Position"],
                        values = {
                            AUTO = L["Above or below (toward the screen center)"],
                            ANCHOR_TOP = L["Above"],
                            ANCHOR_BOTTOM = L["Below"],
                            ANCHOR_LEFT = L["Above, to the left"],
                            ANCHOR_RIGHT = L["Above, to the right"],
                        },
                        sorting = { "AUTO", "ANCHOR_TOP", "ANCHOR_BOTTOM", "ANCHOR_LEFT", "ANCHOR_RIGHT" },
                    },
                },
            },
            Backdrop = {
                type = "group",
                feature = true,
                name = L["Border and background"],
                desc = L["Draws the tooltips with a border and background of your choice. More textures come with addons that register them with LibSharedMedia (e.g. SharedMedia)."],
                order = 30,
                settings = function()
                    return backdrop:Settings()
                end,
                toggled = function()
                    backdrop:Refresh()
                end,
                changed = function()
                    backdrop:SettingsChanged()
                end,
                args = {
                    background = {
                        type = "select",
                        order = 10,
                        name = L["Background"],
                        values = media.Values(LSM.MediaType.BACKGROUND),
                    },
                    backgroundColor = {
                        type = "color",
                        order = 20,
                        name = L["Background color"],
                        hasAlpha = true,
                    },
                    border = {
                        type = "select",
                        order = 30,
                        name = L["Border"],
                        values = media.Values(LSM.MediaType.BORDER),
                    },
                    borderColor = {
                        type = "color",
                        order = 40,
                        name = L["Border color"],
                        hasAlpha = true,
                    },
                    edgeSize = {
                        type = "range",
                        order = 50,
                        name = L["Border size"],
                        min = 1,
                        max = 32,
                        step = 1,
                    },
                    inset = {
                        type = "range",
                        order = 60,
                        name = L["Background inset"],
                        desc = L["How far the background stays inside the tooltip's edge."],
                        min = 0,
                        max = 16,
                        step = 1,
                    },
                },
            },
            CursorAnchor = {
                type = "group",
                feature = true,
                name = L["Anchor to the cursor"],
                desc = L['Shows tooltips at the mouse cursor instead of the screen corner. Unit frame tooltips stay in the corner; action button tooltips follow "Anchor to action buttons" while that is on.'],
                order = 10,
                settings = function()
                    return cursorAnchor:Settings()
                end,
                toggled = function()
                    cursorAnchor:Refresh()
                end,
                changed = function()
                    cursorAnchor:SettingsChanged()
                end,
                args = {
                    position = {
                        type = "select",
                        order = 10,
                        name = L["Position"],
                        values = {
                            ANCHOR_CURSOR = L["At the cursor"],
                            ANCHOR_CURSOR_LEFT = L["Left of the cursor"],
                            ANCHOR_CURSOR_RIGHT = L["Right of the cursor"],
                        },
                        sorting = { "ANCHOR_CURSOR", "ANCHOR_CURSOR_LEFT", "ANCHOR_CURSOR_RIGHT" },
                    },
                    offsetX = {
                        type = "range",
                        order = 20,
                        name = L["X offset"],
                        min = -1000,
                        max = 1000,
                        softMin = -400,
                        softMax = 400,
                        step = 1,
                        bigStep = 10,
                    },
                    offsetY = {
                        type = "range",
                        order = 30,
                        name = L["Y offset"],
                        min = -1000,
                        max = 1000,
                        softMin = -400,
                        softMax = 400,
                        step = 1,
                        bigStep = 10,
                    },
                },
            },
            Scale = {
                type = "group",
                feature = true,
                name = L["Scale"],
                desc = L["Makes the tooltips bigger or smaller, apart from the rest of the interface."],
                order = 40,
                settings = function()
                    return scale:Settings()
                end,
                toggled = function()
                    scale:Refresh()
                end,
                changed = function()
                    scale:SettingsChanged()
                end,
                args = {
                    scale = {
                        type = "range",
                        order = 10,
                        name = L["Scale"],
                        min = 0.5,
                        max = 2,
                        step = 0.05,
                        isPercent = true,
                    },
                },
            },
        },
    },
}
