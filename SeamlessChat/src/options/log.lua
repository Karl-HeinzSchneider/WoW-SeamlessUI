---@type string, SeamlessChat
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local logOptions
do
    local self = app.addon:GetModule("log")
    logOptions = {
        status = {
            type = "description",
            order = 5,
            fontSize = "medium",
            name = function()
                local count = self:Count()
                if count == 0 then
                    return L["The log is empty.\n"]
                end
                local oldest = self.db.records[self.first].time
                return (L["%d messages, the oldest from %s.\n"]):format(count, date("%Y-%m-%d %H:%M", oldest))
            end,
        },
        open = {
            type = "execute",
            order = 6,
            name = L["Open the chat log"],
            desc = L["Search and filter the logged messages. Same as /seamlesschat log."],
            func = function()
                SeamlessChatLogWindow:Open()
            end,
        },
        showButton = {
            type = "toggle",
            order = 7,
            width = "full",
            name = L["Chat log button beside the chat"],
            desc = L["A button in the main chat window's button column, above the chat menu button, that opens the chat log."],
        },
        maxMessages = {
            type = "range",
            order = 10,
            width = "double",
            name = L["Messages kept"],
            desc = L["The oldest messages are dropped past this many. A big log makes the login a little slower."],
            min = 1000,
            max = 200000,
            softMax = 100000,
            step = 1,
            bigStep = 1000,
        },
        maxDays = {
            type = "range",
            order = 20,
            width = "double",
            name = L["Days kept"],
            desc = L["Messages older than this are dropped."],
            min = 1,
            max = 365,
            step = 1,
        },
        clear = {
            type = "execute",
            order = 30,
            name = L["Delete the log"],
            desc = L["Deletes every logged message of this character."],
            confirm = true,
            confirmText = L["Delete every logged chat message of this character?"],
            func = function()
                self:Clear()
            end,
        },
    }
end
local logFeature = app.addon:GetModule("log")
---@type SeamlessCore.SettingsPage
app.optionPages.log = {
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
                log = {
                    enabled = true,
                    maxMessages = 25000,
                    maxDays = 30,
                    showButton = true, -- the chat log button beside the chat
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Log"],
        order = 40,
        args = {
            log = {
                type = "group",
                feature = true,
                name = L["Chat log"],
                desc = L["Records every chat message of this character into a database you can search (/seamlesschat search <text>). Kept across sessions, per character."],
                order = 1,
                args = logOptions,
                settings = function()
                    return logFeature:GetSettings()
                end,
                toggled = function()
                    logFeature:OnProfileRefresh()
                end,
                changed = function()
                    if logFeature:IsEnabled() then
                        logFeature:Refresh()
                    end
                end,
            },
        },
    },
}
