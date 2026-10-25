---@type string, SeamlessChat
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local skinOptions
do
    local self = app.addon:GetModule("skin")
    local BUTTONS = self:GetOptionButtons()
    local options = {
        accent = {
            type = "color",
            order = 10,
            name = L["Accent color"],
            desc = L["The edge of a button under the mouse."],
            get = function()
                local color = self:Settings().accent
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = self:Settings().accent
                color.r, color.g, color.b = r, g, b
            end,
        },
    }
    for i, entry in ipairs(BUTTONS) do
        options["show_" .. entry.key] = {
            type = "toggle",
            order = 20 + i,
            name = entry.name,
            desc = entry.key == "log" and L["Same as the Chat log setting of the same name."]
                or entry.key == "copy" and L["Opens the copy window for the selected chat tab. Needs Copy to be enabled."]
                or entry.key == "options" and L["Opens the Chat settings."]
                or L["Show this button in the bar."],
            get = function()
                if entry.key == "log" then
                    return app.chatLog:GetSettings().showButton
                end
                return self:Settings().show[entry.key] ~= false
            end,
            set = function(_, value)
                if entry.key == "log" then
                    app.chatLog:GetSettings().showButton = value
                    app.chatLog:UpdateButton()
                else
                    self:Settings().show[entry.key] = value
                    -- A button switched back on comes back; the game decides for its own.
                    local button = entry.frame()
                    if value and button and not entry.own and not entry.game then
                        button:Show()
                    end
                end
                self:Arrange()
            end,
        }
    end
    skinOptions = options
end
local skinFeature = app.addon:GetModule("skin")
---@type SeamlessCore.SettingsPage
app.optionPages.buttons = {
    tooltip = function(path)
        local defaults, field = app.dbDefaults.profile.features[path[2]], path[3]
        if path[2] == "channels" and field and field:match("^short.+") then
            return defaults.short[field:sub(6)]
        end
        if path[2] == "skin" and field and field:match("^show_") then
            if field == "show_log" then
                return app.dbDefaults.profile.features.log.showButton
            end
            return app.core:GetOptionDefault(defaults.show, { field:sub(6) })
        end
        return app.core:GetOptionDefault(defaults, #path == 2 and { "enabled" } or path, #path == 2 and 1 or 3)
    end,
    defaults = {
        profile = {
            features = {
                skin = {
                    enabled = true,
                    accent = { r = 1, g = 0.82, b = 0 }, -- the game's gold
                    -- Which buttons the bar shows, by BUTTONS key (the log button's switch is the log feature's).
                    show = {
                        social = true,
                        channels = true,
                        tts = true,
                        voiceDeafen = true,
                        voiceMute = true,
                        copy = true,
                        menu = true,
                        options = true,
                    },
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Buttons"],
        order = 30,
        args = {
            skin = {
                type = "group",
                feature = true,
                name = L["Chat buttons"],
                desc = L["The buttons left of the main chat window in one bar and one style. Hidden buttons leave no gap."],
                order = 1,
                args = skinOptions,
                settings = function()
                    return skinFeature:GetSettings()
                end,
                toggled = function()
                    skinFeature:OnProfileRefresh()
                end,
                changed = function()
                    if skinFeature:IsEnabled() then
                        skinFeature:Refresh()
                    end
                end,
            },
        },
    },
}
