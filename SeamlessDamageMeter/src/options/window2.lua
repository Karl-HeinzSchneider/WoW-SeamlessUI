---@type string, SeamlessDamageMeter
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local function config()
    return app.db.profile.windows[2]
end
local buttons = app.WindowEditModeButtons()
local layout = app.WindowAppearanceOptions(2)
---@type SeamlessCore.SettingsPage
app.optionPages.window2 = {
    tooltip = function(path)
        local key = path[#path]
        if key == "override" or key == "hidden" then
            return false
        end
        if key == "skin" then
            return "default"
        end
        if key == "enabled" then
            return path[1] == "window1"
        end
        if key == "default" or key == "value" then
            return app.db.profile.windowDefaults[path[#path - 1]]
        end
        return app.windowDefaults[key]
    end,
    defaults = {},
    config = {
        buttonSection = app.core:GetEditModeButtonSection({
            app.core:GetEditModePositionButton("revert"),
            app.core:GetEditModePositionButton("resetPosition"),
            buttons.editSkin,
            buttons.createWindow,
            buttons.removeWindow,
        }),
        type = "group",
        name = L["Window %d"]:format(2),
        order = 12,
        args = {
            management = {
                type = "group",
                inline = true,
                name = L["Window"],
                order = 1,
                args = {
                    hidden = {
                        type = "toggle",
                        name = L["Hide window"],
                        order = 1,
                        get = function()
                            return config().hidden or false
                        end,
                        set = function(_, value)
                            config().hidden = value
                            app:RebuildWindows()
                        end,
                    },
                    reset = {
                        type = "execute",
                        name = L["Clear all overrides"],
                        order = 2,
                        confirm = true,
                        func = function()
                            config().overrides = {}
                            config().styleOverrides = nil
                            config().modifyGlobalStyle = nil
                            app:RebuildWindows()
                        end,
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Use this window"],
                        desc = L["Deactivation hides the window and preserves its settings and attachments."],
                        order = 0,
                        get = function()
                            return config().enabled
                        end,
                        set = function(_, value)
                            app:SetWindowEnabled(config(), value)
                        end,
                    },
                    skin = {
                        type = "select",
                        name = L["Skin"],
                        order = 3,
                        width = "full",
                        values = function()
                            local values = {}
                            for key, skin in pairs(app.db.profile.skins) do
                                values[key] = skin.name
                            end
                            return values
                        end,
                        get = function()
                            return config().skin
                        end,
                        set = function(_, value)
                            config().skin = value
                            app:RebuildWindows()
                        end,
                    },
                },
            },
            position = app.WindowPositionOptions(2),
            info = layout.info,
            width = layout.width,
            height = layout.height,
            fixedHeight = layout.fixedHeight,
            visibleLines = layout.visibleLines,
            showResizeHandle = layout.showResizeHandle,
            lockSize = layout.lockSize,
            lockPosition = layout.lockPosition,
            numbers = layout.numbers,
        },
    },
}
