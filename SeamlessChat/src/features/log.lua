---@type string, SeamlessChat
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Chat log: a searchable database of every chat message this character receives or sends. It
-- records the game's chat events themselves (CHAT_MSG_*), before any chat window formats them, so a
-- message is one record with its fields (time, type, channel, sender, ...), stored once no matter
-- how many windows show it.
--
-- Saved in SeamlessChatLogDB (## SavedVariablesPerCharacter). The oldest records are dropped past
-- maxMessages or maxDays. Messages the game hides as secret values can't be stored.
---@class SeamlessChat.ChatLog : SeamlessChat.Feature
---@field db SeamlessChat.LogDB
---@field first integer index of the oldest record in db.records
---@field last integer index of the newest
---@field onAdd fun(record: SeamlessChat.LogRecord)? called for every new record (the log window)
local module = { optionsTab = "log" }

---@class SeamlessChat.LogSettings : SeamlessChat.FeatureSettings
local defaults = {
    enabled = true,
    maxMessages = 25000,
    maxDays = 30,
    showButton = true, -- the chat log button beside the chat
}

app.chatLog = app.features:New(
    "log",
    module,
    L["Chat log"],
    L["Records every chat message of this character into a database you can search (/seamlesschat search <text>). Kept across sessions, per character."],
    defaults
) --[[@as SeamlessChat.ChatLog]]

---@class SeamlessChat.LogDB
---@field version integer
---@field records SeamlessChat.LogRecord[] oldest first

-- One chat message. Fields the event didn't have (or had empty) are nil.
---@class SeamlessChat.LogRecord
---@field time integer time() it arrived
---@field type string chat type: the event without CHAT_MSG_ (SAY, WHISPER, WHISPER_INFORM, CHANNEL, SYSTEM, LOOT, ...)
---@field text string the message as the game sent it, links and color codes included
---@field sender string? "Name-Realm"; for whispers you sent, the recipient; for Battle.net messages the BattleTag
---@field channel string? channel name without number ("Trade", "General", a custom channel)
---@field channelNum integer? the channel's number at the time
---@field guid string? the sender's GUID
---@field class string? the sender's class file name ("SHAMAN"), when the game knew it
---@field lang string? language, when not the default
---@field flags string? special flags (GM, DEV, AFK, DND, ...)

local DB_VERSION = 1
local DAY = 24 * 60 * 60

-- Every event a chat window can show, plus community channels (registered by the chat frames
-- directly). CHAT_MSG_ADDON isn't chat and isn't among them.
local EXTRA_EVENTS = { "CHAT_MSG_COMMUNITIES_CHANNEL" }

-- `value` unless it is a secret value, which tainted code can't even test for truth.
local function readable(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- Whether the sender is this character or in its party or raid. By GUID; by name when the event
-- has none. What the game won't tell (secret values) counts as no.
---@param playerName string?
---@param guid string?
local function isSelfOrGroup(playerName, guid)
    if guid then
        if guid == readable(UnitGUID("player")) then
            return true
        end
        local ok, inGroup = pcall(C_PartyInfo.IsGUIDInGroup, guid)
        return ok and readable(inGroup) == true
    end
    if playerName then
        if playerName:match("^[^-]+") == readable(UnitName("player")) then
            return true
        end
        local ok, inParty, inRaid = pcall(function()
            return UnitInParty(playerName), UnitInRaid(playerName)
        end)
        return ok and (readable(inParty) == true or readable(inRaid) ~= nil)
    end
    return false
end

-- Chat types recorded only when their condition holds for the sender. Trade skill messages
-- ("X creates Y") of strangers nearby are noise; yours and your group's say who made what.
---@type table<string, fun(playerName: string?, guid: string?): boolean>
local RECORD_ONLY_IF = {
    TRADESKILLS = isSelfOrGroup,
}

---@return SeamlessChat.LogSettings
function module:Settings()
    return self:GetSettings() --[[@as SeamlessChat.LogSettings]]
end

-- Recording ----------------------------------------------------------------------------------------

-- `value` if it can be stored: not secret, not an empty string.
local function storable(value)
    if value == nil or (issecretvalue and issecretvalue(value)) or value == "" then
        return nil
    end
    return value
end

local function battleTag(bnSenderID)
    if not (storable(bnSenderID) and C_BattleNet and C_BattleNet.GetAccountInfoByID) then
        return nil
    end
    local ok, info = pcall(C_BattleNet.GetAccountInfoByID, bnSenderID)
    return ok and info and storable(info.battleTag) or nil
end

local function classOf(guid)
    if not guid then
        return nil
    end
    local ok, _, englishClass = pcall(GetPlayerInfoByGUID, guid)
    return ok and storable(englishClass) or nil
end

function module:OnChatEvent(
    event,
    text,
    playerName,
    languageName,
    _,
    _,
    specialFlags,
    _,
    channelIndex,
    channelBaseName,
    _,
    _,
    guid,
    bnSenderID
)
    if not self:IsEnabled() then
        return
    end
    text = storable(text)
    if type(text) ~= "string" then
        return
    end
    local chatType = event:sub(10) -- after "CHAT_MSG_"
    guid = storable(guid)
    local condition = RECORD_ONLY_IF[chatType]
    if condition and not condition(storable(playerName), guid) then
        return
    end
    ---@type SeamlessChat.LogRecord
    local record = {
        time = time(),
        type = chatType,
        text = text,
        sender = chatType:find("^BN_") and battleTag(bnSenderID) or storable(playerName),
        guid = guid,
        class = classOf(guid),
        lang = storable(languageName),
        flags = storable(specialFlags),
    }
    if storable(channelBaseName) then
        record.channel = channelBaseName
        local channelNum = storable(channelIndex)
        record.channelNum = channelNum ~= 0 and channelNum or nil
    end
    self:Add(record)
end

---@param record SeamlessChat.LogRecord
function module:Add(record)
    self.last = self.last + 1
    self.db.records[self.last] = record
    self:Prune()
    if self.onAdd then
        self.onAdd(record)
    end
end

-- Drops the oldest records past maxMessages or maxDays. Dropping only moves `first`, so the array
-- has a hole at its start until Compact.
function module:Prune()
    local settings = self:Settings()
    local records = self.db.records
    local oldest = time() - settings.maxDays * DAY
    while self.first <= self.last do
        local record = records[self.first]
        if self.last - self.first + 1 <= settings.maxMessages and record.time >= oldest then
            break
        end
        records[self.first] = nil
        self.first = self.first + 1
    end
end

-- Closes the hole Prune left, so the saved array is a plain list again.
function module:Compact()
    if self.first == 1 then
        return
    end
    local compacted = {}
    for i = self.first, self.last do
        compacted[#compacted + 1] = self.db.records[i]
    end
    self.db.records = compacted
    self.first, self.last = 1, #compacted
end

-- Groups -------------------------------------------------------------------------------------------

-- The kinds of messages the log window lists, in its order. A record belongs to the first group
-- whose `types` has its type; otherwise to "channel" if it has a channel, "bnet" for other
-- Battle.net types, "npc" for NPC speech, and "system" for the rest.
---@class SeamlessChat.LogGroup
---@field key string
---@field name string
---@field types table<string, true>?

---@type SeamlessChat.LogGroup[]
local GROUPS = {
    {
        key = "whisper",
        name = L["Whispers"],
        types = {
            WHISPER = true,
            WHISPER_INFORM = true,
            BN_WHISPER = true,
            BN_WHISPER_INFORM = true,
            AFK = true,
            DND = true,
        },
    },
    {
        key = "guild",
        name = L["Guild"],
        types = {
            GUILD = true,
            OFFICER = true,
            GUILD_ACHIEVEMENT = true,
            GUILD_ITEM_LOOTED = true,
            GUILD_DISCORD = true,
        },
    },
    { key = "party", name = L["Party"], types = { PARTY = true, PARTY_LEADER = true } },
    { key = "raid", name = L["Raid"], types = { RAID = true, RAID_LEADER = true, RAID_WARNING = true } },
    { key = "instance", name = L["Instance"], types = { INSTANCE_CHAT = true, INSTANCE_CHAT_LEADER = true } },
    {
        key = "say",
        name = L["Say, yell & emotes"],
        types = { SAY = true, YELL = true, EMOTE = true, TEXT_EMOTE = true },
    },
    { key = "community", name = L["Communities"], types = { COMMUNITIES_CHANNEL = true } },
    { key = "channel", name = L["Channels"] },
    { key = "bnet", name = L["Battle.net"] },
    { key = "npc", name = L["NPCs"] },
    {
        key = "loot",
        name = L["Loot & rewards"],
        types = {
            LOOT = true,
            MONEY = true,
            CURRENCY = true,
            COMBAT_XP_GAIN = true,
            COMBAT_HONOR_GAIN = true,
            COMBAT_FACTION_CHANGE = true,
            SKILL = true,
            TRADESKILLS = true,
            OPENING = true,
            PET_INFO = true,
            COMBAT_MISC_INFO = true,
            ACHIEVEMENT = true,
        },
    },
    { key = "system", name = L["System & other"] },
}
module.GROUPS = GROUPS

local groupOfType = {}
for _, group in ipairs(GROUPS) do
    for chatType in pairs(group.types or {}) do
        groupOfType[chatType] = group.key
    end
end

-- The group key of a record (a key of GROUPS).
---@param record SeamlessChat.LogRecord
---@return string
local function groupOf(record)
    local key = groupOfType[record.type]
    if key then
        return key
    elseif record.channel then
        return "channel"
    elseif record.type:find("^BN_") then
        return "bnet"
    elseif record.type:find("^MONSTER_") or record.type:find("^RAID_BOSS_") then
        return "npc"
    end
    return "system"
end

-- How many records each group has, and each channel.
---@return table<string, integer> groups
---@return table<string, integer> channels by channel name
function module:CountGroups()
    local groups, channels = {}, {}
    for i = self.first, self.last do
        local record = self.db.records[i]
        local key = groupOf(record)
        groups[key] = (groups[key] or 0) + 1
        if key == "channel" then
            channels[record.channel] = (channels[record.channel] or 0) + 1
        end
    end
    return groups, channels
end

-- Searching ----------------------------------------------------------------------------------------

---@class SeamlessChat.LogFilter
---@field search string? part of the message or of the sender, any case
---@field text string? part of the message, any case
---@field sender string? part of the sender, any case
---@field group string? a key of GROUPS
---@field channel string? channel name, any case
---@field types table<string, true>? chat types to include (keys like "WHISPER")
---@field since integer? time() from
---@field before integer? time() until
---@field limit integer? only the newest this many matches

-- Part of `haystack`, any case (`needle` already lowercase).
local function contains(haystack, needle)
    return haystack ~= nil and haystack:lower():find(needle, 1, true) ~= nil
end

-- The records matching `filter`, oldest first, and how many matched in all (more than returned
-- when `limit` cut them off).
---@param filter SeamlessChat.LogFilter
---@return SeamlessChat.LogRecord[] matches
---@return integer total
function module:Query(filter)
    local search = filter.search and filter.search:lower()
    local text = filter.text and filter.text:lower()
    local sender = filter.sender and filter.sender:lower()
    local channel = filter.channel and filter.channel:lower()
    local limit = filter.limit or math.huge
    -- The text as shown: "hi" must not match the link code in "|Hitem:...".
    local function shownText(record)
        return app.copy:PlainText(record.text)
    end

    local matches, total = {}, 0
    -- Newest first, so a limit keeps the newest.
    for i = self.last, self.first, -1 do
        local record = self.db.records[i]
        if filter.since and record.time < filter.since then
            break
        end
        if
            (not filter.before or record.time < filter.before)
            and (not filter.types or filter.types[record.type])
            and (not filter.group or groupOf(record) == filter.group)
            and (not channel or (record.channel and record.channel:lower() == channel))
            and (not sender or contains(record.sender, sender))
            and (not text or contains(shownText(record), text))
            and (not search or contains(record.sender, search) or contains(shownText(record), search))
        then
            total = total + 1
            if #matches < limit then
                matches[#matches + 1] = record
            end
        end
    end
    -- Oldest first.
    for i = 1, math.floor(#matches / 2) do
        matches[i], matches[#matches - i + 1] = matches[#matches - i + 1], matches[i]
    end
    return matches, total
end

-- How FormatRecord names chat types that read badly as they are.
local TYPE_LABELS = {
    WHISPER = L["Whisper from"],
    WHISPER_INFORM = L["Whisper to"],
    BN_WHISPER = L["Whisper from"],
    BN_WHISPER_INFORM = L["Whisper to"],
}

---@param record SeamlessChat.LogRecord
local function whereOf(record)
    if record.channel then
        return record.channelNum and ("%d. %s"):format(record.channelNum, record.channel) or record.channel
    end
    return TYPE_LABELS[record.type] or record.type
end

-- A record as one plain line: "2026-09-27 18:14:31 [2. Trade] Thrall: WTS [Hearthstone]".
---@param record SeamlessChat.LogRecord
function module:FormatRecord(record)
    local line = (L["%s [%s] "]):format(date("%Y-%m-%d %H:%M:%S", record.time), whereOf(record))
    if record.sender then
        line = line .. record.sender .. ": "
    end
    return line .. app.copy:PlainText(record.text)
end

-- A record as the log window shows it: like FormatRecord, but with its links, the sender in class
-- color, and the color of its chat type (returned as r, g, b).
---@param record SeamlessChat.LogRecord
---@return string line
---@return number r
---@return number g
---@return number b
function module:FormatColored(record)
    local line = (L["|cff808080%s|r [%s] "]):format(date("%Y-%m-%d %H:%M:%S", record.time), whereOf(record))
    if record.sender then
        local classColor = record.class and GetClassColorObj(record.class)
        local sender = classColor and classColor:WrapTextInColorCode(record.sender) or record.sender
        line = line .. sender .. ": "
    end
    local info = (record.channelNum and ChatTypeInfo["CHANNEL" .. record.channelNum])
        or ChatTypeInfo[record.type]
        or ChatTypeInfo.SYSTEM
    local text = record.text
    if app.urls:IsEnabled() then
        text = app.urls:Linkify(text)
    end
    return line .. text, info.r or 1, info.g or 1, info.b or 1
end

-- Opens the log window, searching for `text` when given.
---@param text string?
function module:Search(text)
    SeamlessChatLogWindow:Open(text)
end

function module:Count()
    return self.last - self.first + 1
end

function module:Clear()
    self.db.records = {}
    self.first, self.last = 1, 0
end

-- Lifecycle --------------------------------------------------------------------------------------

function module:OnInitialize()
    if type(SeamlessChatLogDB) ~= "table" or type(SeamlessChatLogDB.records) ~= "table" then
        SeamlessChatLogDB = { version = DB_VERSION, records = {} }
    end
    self.db = SeamlessChatLogDB
    self.first, self.last = 1, #self.db.records
    self:Prune()

    -- The recording frame is registered once and checks IsEnabled: events arriving before
    -- PLAYER_LOGIN (the guild's message of the day, ...) are recorded too.
    local frame = CreateFrame("Frame")
    local registered = {}
    local function register(event)
        if not registered[event] then
            registered[event] = true
            -- pcall: an event this client doesn't know must not stop the others.
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    for _, events in pairs(ChatTypeGroup) do
        for _, event in ipairs(events) do
            register(event)
        end
    end
    for _, event in ipairs(EXTRA_EVENTS) do
        register(event)
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        self:OnChatEvent(event, ...)
    end)

    -- At logout, before AceDB strips the setting defaults (see the addon's CLAUDE.md).
    app.db.RegisterCallback(self, "OnDatabaseShutdown", function()
        self:Prune()
        self:Compact()
        SeamlessChatLogDB = self.db
    end)

    self:UpdateButton()
end

-- The button beside the chat (logwindow.xml) shows while the feature is on and the setting wants it.
function module:UpdateButton()
    SeamlessChatLogButton:SetShown(self:IsEnabled() and self:Settings().showButton)
end

function module:OnEnable()
    self:UpdateButton()
end

function module:OnDisable()
    self:UpdateButton()
end

function module:Refresh()
    self:Prune()
    self:UpdateButton()
end

function module:GetOptions()
    return {
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
