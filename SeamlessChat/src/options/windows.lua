---@type string, SeamlessChat
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local backgroundOptions
do
    local self = app.addon:GetModule("background")
    backgroundOptions = {
        color = {
            type = "color",
            order = 10,
            name = L["Background"],
            desc = L["Color and opacity of every chat window's background. Opacity 0 hides it; the game shows it at least at 25% while the mouse is over the chat."],
            hasAlpha = true,
            get = function()
                local color = self:Settings().color
                return color.r, color.g, color.b, color.a
            end,
            set = function(_, r, g, b, a)
                local color = self:Settings().color
                color.r, color.g, color.b, color.a = r, g, b, a
                self:Refresh()
            end,
        },
        reset = {
            type = "execute",
            order = 20,
            name = L["Black"],
            desc = L["Back to black, fully opaque."],
            func = function()
                local color = self:Settings().color
                color.r, color.g, color.b, color.a = 0, 0, 0, 1
                self:Refresh()
                app.options:Refresh()
            end,
        },
    }
end
local backgroundFeature = app.addon:GetModule("background")
local copyOptions
do
    local self = app.addon:GetModule("copy")
    copyOptions = {
        clickTimestamp = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Click a timestamp to copy its message"],
            desc = L["Needs Timestamps to be enabled."],
        },
        showButton = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["Copy button in the chat windows"],
            desc = L["A button in the top right corner of each chat window, shown while the mouse is over the chat. It opens a window with the last messages, selected, ready for Ctrl+C."],
        },
        windowLines = {
            type = "range",
            order = 30,
            width = "double",
            name = L["Messages in the copy window"],
            desc = L["How many of the last messages the copy window shows, at most as many as the chat window keeps (Chat history)."],
            min = 10,
            max = 10000,
            softMax = 2000,
            step = 1,
            bigStep = 50,
        },
    }
end
local copyFeature = app.addon:GetModule("copy")
local fadingOptions
do
    local self = app.addon:GetModule("fading")
    local function fadingOff()
        local settings = self:Settings()
        return not (settings.enabled and settings.fade)
    end
    fadingOptions = {
        fade = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Fade out old messages"],
            desc = L["Off keeps every message visible."],
        },
        timeVisible = {
            type = "range",
            order = 20,
            width = "double",
            name = L["Seconds visible"],
            desc = L["How long a message stays before it fades out. The game uses 120."],
            min = 5,
            max = 3600,
            softMax = 600,
            step = 1,
            bigStep = 5,
            disabled = fadingOff,
        },
        fadeDuration = {
            type = "range",
            order = 30,
            width = "double",
            name = L["Fade duration"],
            desc = L["How many seconds the fade itself takes. The game uses 3."],
            min = 0,
            max = 10,
            step = 0.5,
            disabled = fadingOff,
        },
    }
end
local fadingFeature = app.addon:GetModule("fading")
local historyOptions
do
    local self = app.addon:GetModule("history")
    local BLIZZARD_MAX_LINES = 128
    historyOptions = {
        maxLines = {
            type = "range",
            order = 10,
            width = "double",
            name = L["Messages per chat window"],
            desc = L["How many messages each chat window keeps. Lowering it drops the oldest ones."],
            min = BLIZZARD_MAX_LINES,
            max = 10000,
            softMax = 5000,
            step = 1,
            bigStep = 100,
        },
        persist = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["Keep the chat across logins and reloads"],
            desc = L["Saves each chat window's messages when you log out or reload and puts them back at the next login of the same character, above a divider line."],
        },
        savedLines = {
            type = "range",
            order = 30,
            width = "double",
            name = L["Messages saved per chat window"],
            desc = L["How many of the last messages of each chat window are saved. At login, a window takes back as many as fit into Messages per chat window."],
            min = 10,
            max = 10000,
            softMax = 5000,
            step = 1,
            bigStep = 100,
            disabled = function()
                return not (self:Settings().enabled and self:Settings().persist)
            end,
        },
    }
end
local historyFeature = app.addon:GetModule("history")
local unreadOptions
do
    local self = app.addon:GetModule("unread")
    unreadOptions = {
        channels = {
            type = "toggle",
            order = 10,
            width = "full",
            name = L["Count channel messages"],
            desc = L["Messages in numbered channels such as General and Trade count too."],
        },
        color = {
            type = "color",
            order = 20,
            name = L["Badge color"],
            desc = L["The background of the unread count."],
            get = function()
                local color = self:Settings().color
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = self:Settings().color
                color.r, color.g, color.b = r, g, b
                self:Refresh()
            end,
        },
    }
end
local unreadFeature = app.addon:GetModule("unread")
---@type SeamlessCore.SettingsPage
app.optionPages.windows = {
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
                background = {
                    enabled = true,
                    color = { r = 0, g = 0, b = 0, a = 1 }, -- black, fully opaque
                },
                copy = {
                    enabled = true,
                    clickTimestamp = true, -- clicking a line's timestamp copies the line
                    showButton = true, -- the copy button in the chat windows
                    windowLines = 500, -- how many of the last lines the copy window shows
                },
                fading = {
                    enabled = true,
                    fade = true, -- messages fade out at all
                    timeVisible = 120, -- seconds a message stays before fading (the game's value)
                    fadeDuration = 3, -- seconds the fade takes (the game's value)
                },
                history = {
                    enabled = true,
                    maxLines = 1000, -- messages each chat window keeps
                    persist = true, -- save the chat at logout and put it back at login
                    savedLines = 1000, -- messages saved per chat window
                },
                unread = {
                    enabled = false,
                    channels = true, -- numbered channels (General, Trade, ...) count too
                    color = { r = 0.75, g = 0.12, b = 0.1 }, -- the badge
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Windows"],
        order = 20,
        args = {
            background = {
                type = "group",
                feature = true,
                name = L["Background"],
                desc = L["The same background color and opacity for every chat window and tab, black by default. While on, the Background setting in a tab's menu has no visible effect."],
                order = 1,
                args = backgroundOptions,
                settings = function()
                    return backgroundFeature:GetSettings()
                end,
                toggled = function()
                    backgroundFeature:OnProfileRefresh()
                end,
                changed = function()
                    if backgroundFeature:IsEnabled() then
                        backgroundFeature:Refresh()
                    end
                end,
            },
            copy = {
                type = "group",
                feature = true,
                name = L["Copy chat"],
                desc = L["Copy chat messages: one by clicking its timestamp (it lands in the chat input), or many at once with the copy button in the top right corner of a chat window. The text is selected, ready for Ctrl+C."],
                order = 2,
                args = copyOptions,
                settings = function()
                    return copyFeature:GetSettings()
                end,
                toggled = function()
                    copyFeature:OnProfileRefresh()
                end,
                changed = function()
                    if copyFeature:IsEnabled() then
                        copyFeature:Refresh()
                    end
                end,
            },
            fading = {
                type = "group",
                feature = true,
                name = L["Fade-out"],
                desc = L["Whether chat messages fade out after a while, how long they stay, and how long the fade takes."],
                order = 3,
                args = fadingOptions,
                settings = function()
                    return fadingFeature:GetSettings()
                end,
                toggled = function()
                    fadingFeature:OnProfileRefresh()
                end,
                changed = function()
                    if fadingFeature:IsEnabled() then
                        fadingFeature:Refresh()
                    end
                end,
            },
            history = {
                type = "group",
                feature = true,
                name = L["Chat history"],
                desc = L["Keeps more messages in every chat window, and keeps them across logins and reloads (per character), so scrolling back and the copy window reach into your last session."],
                order = 4,
                args = historyOptions,
                settings = function()
                    return historyFeature:GetSettings()
                end,
                toggled = function()
                    historyFeature:OnProfileRefresh()
                end,
                changed = function()
                    if historyFeature:IsEnabled() then
                        historyFeature:Refresh()
                    end
                end,
            },
            unread = {
                type = "group",
                feature = true,
                name = L["Unread counts"],
                desc = L["Shows how many messages came in on a chat tab while another tab was selected, as a badge on its corner. Selecting the tab clears it."],
                order = 5,
                args = unreadOptions,
                settings = function()
                    return unreadFeature:GetSettings()
                end,
                toggled = function()
                    unreadFeature:OnProfileRefresh()
                end,
                changed = function()
                    if unreadFeature:IsEnabled() then
                        unreadFeature:Refresh()
                    end
                end,
            },
        },
    },
}
