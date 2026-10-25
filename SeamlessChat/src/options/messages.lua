---@type string, SeamlessChat
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local channelsOptions
do
    local self = app.addon:GetModule("channels")
    local NUMBERED_ORDER = { "number", "name", "numberName", "full" }
    local NUMBERED_LABELS =
        { number = "[2]", name = L["[Trade]"], numberName = L["[2. Trade]"], full = L["[2. Trade - City]"] }

    -- The group channels in the options' order, with what they are called there.
    local GROUP_ORDER = {
        "GUILD",
        "OFFICER",
        "PARTY",
        "PARTY_LEADER",
        "PARTY_GUIDE",
        "RAID",
        "RAID_LEADER",
        "INSTANCE_CHAT",
        "INSTANCE_CHAT_LEADER",
    }
    local GROUP_LABELS = {
        GUILD = L["Guild"],
        OFFICER = L["Officer"],
        PARTY = L["Party"],
        PARTY_LEADER = L["Party leader"],
        PARTY_GUIDE = L["Dungeon guide"],
        RAID = L["Raid"],
        RAID_LEADER = L["Raid leader"],
        INSTANCE_CHAT = L["Instance"],
        INSTANCE_CHAT_LEADER = L["Instance leader"],
    }

    -- The short name for one channel link, or nil to keep it.
    ---@param data string the link's data: "channel:2" or "GUILD", "PARTY", ...
    ---@param display string the shown name, without brackets: "2. Trade - City", "Party Leader"
    ---@param chatType string? the line's chat type, which tells PARTY_LEADER from PARTY
    local args = {
        numbered = {
            type = "select",
            order = 10,
            name = L["Numbered channels"],
            desc = L["How General, Trade and the other numbered channels are shown."],
            values = NUMBERED_LABELS,
            sorting = NUMBERED_ORDER,
        },
        groups = {
            type = "toggle",
            order = 20,
            width = "full",
            name = L["Shorten guild, party, raid and instance"],
        },
        shortHeader = {
            type = "header",
            order = 30,
            name = L["Short names"],
        },
    }
    for i, chatType in ipairs(GROUP_ORDER) do
        args["short" .. chatType] = {
            type = "input",
            order = 30 + i,
            width = "half",
            name = GROUP_LABELS[chatType],
            desc = L["Empty keeps the game's name."],
            disabled = function()
                local settings = self:Settings()
                return not (settings.enabled and settings.groups)
            end,
            get = function()
                return self:Settings().short[chatType]
            end,
            set = function(_, value)
                self:Settings().short[chatType] = value
            end,
        }
    end
    channelsOptions = args
end
local channelsFeature = app.addon:GetModule("channels")
local classColorsFeature = app.addon:GetModule("classColors")
local timestampsOptions
do
    local self = app.addon:GetModule("timestamps")
    local FORMATS = { "%H:%M:%S", "%H:%M", "%I:%M:%S %p", "%I:%M %p" }

    local BRACKETS = {
        square = { "[", "]" },
        round = { "(", ")" },
        angle = { "<", ">" },
        none = { "", "" },
    }
    local BRACKET_ORDER = { "square", "round", "angle", "none" }

    -- 18:14:31 today, for the previews in the options.
    local EXAMPLE_TIME = time({ year = 2026, month = 1, day = 1, hour = 18, min = 14, sec = 31 })

    local settings = function()
        return self:GetSettings() --[[@as SeamlessChat.TimestampSettings]]
    end

    timestampsOptions = {
        preview = {
            type = "description",
            order = 5,
            fontSize = "medium",
            name = function()
                return L["Preview:  %s [Thrall]: Lok'tar!\n"]:format(self:FormatStamp(settings(), EXAMPLE_TIME))
            end,
        },
        format = {
            type = "select",
            order = 10,
            name = L["Format"],
            values = function()
                local values = { custom = L["Custom"] }
                for _, pattern in ipairs(FORMATS) do
                    values[pattern] = TimeUtil.BetterDate(pattern, EXAMPLE_TIME)
                end
                return values
            end,
            sorting = { FORMATS[1], FORMATS[2], FORMATS[3], FORMATS[4], "custom" },
        },
        customFormat = {
            type = "input",
            order = 11,
            name = L["Custom format"],
            desc = L["A date() pattern: %H hour (00-23), %I hour (01-12), %M minute, %S second, %p AM/PM, %d day, %m month."],
            hidden = function()
                return settings().format ~= "custom"
            end,
            validate = function(_, value)
                if value == "" or not pcall(date, value) then
                    return L["Not a valid time format."]
                end
                return true
            end,
        },
        brackets = {
            type = "select",
            order = 20,
            name = L["Brackets"],
            values = function()
                local values = {}
                for key, brackets in pairs(BRACKETS) do
                    values[key] = brackets[1] .. "18:14" .. brackets[2]
                end
                return values
            end,
            sorting = BRACKET_ORDER,
        },
        colored = {
            type = "toggle",
            order = 30,
            name = L["Own color"],
            desc = L["Color the timestamp instead of showing it in the message's color."],
        },
        color = {
            type = "color",
            order = 31,
            name = L["Color"],
            disabled = function()
                return not (settings().enabled and settings().colored)
            end,
            get = function()
                local color = settings().color
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = settings().color
                color.r, color.g, color.b = r, g, b
                self:Refresh()
            end,
        },
    }
end
local timestampsFeature = app.addon:GetModule("timestamps")
local urlsOptions
do
    local self = app.addon:GetModule("urls")
    urlsOptions = {
        color = {
            type = "color",
            order = 10,
            name = L["Link color"],
            get = function()
                local color = self:Settings().color
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                local color = self:Settings().color
                color.r, color.g, color.b = r, g, b
            end,
        },
    }
end
local urlsFeature = app.addon:GetModule("urls")
---@type SeamlessCore.SettingsPage
app.optionPages.messages = {
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
                channels = {
                    enabled = true,
                    numbered = "number", -- numbered channels: key of NUMBERED_STYLES
                    groups = true, -- guild, party, raid, instance as in `short`
                    short = {
                        GUILD = "G",
                        OFFICER = "O",
                        PARTY = "P",
                        PARTY_LEADER = "PL",
                        PARTY_GUIDE = "PG",
                        RAID = "R",
                        RAID_LEADER = "RL",
                        INSTANCE_CHAT = "I",
                        INSTANCE_CHAT_LEADER = "IL",
                    },
                },
                classColors = {
                    enabled = true,
                },
                timestamps = {
                    enabled = true,
                    format = "%H:%M:%S", -- one of FORMATS, or "custom" for customFormat
                    customFormat = "%H:%M:%S",
                    brackets = "square", -- key of BRACKETS
                    colored = false, -- own color instead of the message's
                    color = { r = 0.6, g = 0.6, b = 0.6 },
                },
                urls = {
                    enabled = true,
                    color = { r = 0.25, g = 0.66, b = 0.96 },
                },
            },
        },
    },
    config = {
        type = "group",
        name = L["Messages"],
        order = 10,
        args = {
            channels = {
                type = "group",
                feature = true,
                name = L["Short channel names"],
                desc = L['Shortens the channel names in front of chat messages: "[2. Trade - City]" to "[2]", "[Guild]" to "[G]".'],
                order = 1,
                args = channelsOptions,
                settings = function()
                    return channelsFeature:GetSettings()
                end,
                toggled = function()
                    channelsFeature:OnProfileRefresh()
                end,
                changed = function()
                    if channelsFeature:IsEnabled() then
                        channelsFeature:Refresh()
                    end
                end,
            },
            classColors = {
                type = "group",
                feature = true,
                name = L["Class colored names"],
                desc = L["Shows every player name in the chat in its class color, in all chat types and channels."],
                order = 2,
                args = {},
                settings = function()
                    return classColorsFeature:GetSettings()
                end,
                toggled = function()
                    classColorsFeature:OnProfileRefresh()
                end,
                changed = function()
                    if classColorsFeature:IsEnabled() then
                        classColorsFeature:Refresh()
                    end
                end,
            },
            timestamps = {
                type = "group",
                feature = true,
                name = L["Timestamps"],
                desc = L["Shows the time in front of every chat message. Replaces the game's own chat timestamps while enabled."],
                order = 3,
                args = timestampsOptions,
                settings = function()
                    return timestampsFeature:GetSettings()
                end,
                toggled = function()
                    timestampsFeature:OnProfileRefresh()
                end,
                changed = function()
                    if timestampsFeature:IsEnabled() then
                        timestampsFeature:Refresh()
                    end
                end,
            },
            urls = {
                type = "group",
                feature = true,
                name = L["Clickable URLs"],
                desc = L["Web addresses in the chat become links. Clicking one puts it into the chat input, selected, ready for Ctrl+C."],
                order = 4,
                args = urlsOptions,
                settings = function()
                    return urlsFeature:GetSettings()
                end,
                toggled = function()
                    urlsFeature:OnProfileRefresh()
                end,
                changed = function()
                    if urlsFeature:IsEnabled() then
                        urlsFeature:Refresh()
                    end
                end,
            },
        },
    },
}
