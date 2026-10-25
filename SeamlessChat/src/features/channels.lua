---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Short channel names: "[2. Trade - City]" -> "[2]", "[Guild]" -> "[G]". Rewrites the channel link
-- at the start of a chat line (|Hchannel:...|h[...]|h); the link stays, so clicking it still
-- switches the chat input to that channel.
---@class SeamlessChat.Channels : SeamlessChat.Feature
local module = {}

---@class SeamlessChat.ChannelSettings : SeamlessChat.FeatureSettings
local channels = app.features:New("channels", module) --[[@as SeamlessChat.Channels]]

---@return SeamlessChat.ChannelSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.ChannelSettings]]
end

-- How a numbered channel ("2. Trade - City") is shown, by style.
local NUMBERED_STYLES = {
    number = function(number)
        return number
    end,
    name = function(_, name)
        return name
    end,
    numberName = function(number, name)
        return number .. ". " .. name
    end,
    full = function(_, _, display)
        return display
    end,
}
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
function module:ShortName(data, display, chatType)
    local settings = self:Settings()
    if data:find("^channel:%d+$") then
        local number, name = display:match("^(%d+)%.%s*(.-)$")
        if not number then
            return nil
        end
        -- "Trade - City" -> "Trade", like the game does for the channel list.
        name = name:gsub("%s%-%s.*$", "")
        local style = NUMBERED_STYLES[settings.numbered] or NUMBERED_STYLES.number
        return style(number, name, display)
    end
    if settings.groups then
        local short = settings.short[chatType] or settings.short[data]
        if short and short ~= "" then
            return short
        end
    end
    return nil
end

app.lines:Register(20, function(_, message, chatType)
    if not channels:IsEnabled() then
        return message
    end
    return (
        message:gsub("|Hchannel:([^|]+)|h%[([^%]]*)%]|h", function(data, display)
            local short = channels:ShortName(data, display, chatType)
            if short then
                return ("|Hchannel:%s|h[%s]|h"):format(data, short)
            end
        end)
    )
end)
