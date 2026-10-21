---@type string, SeamlessChat
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- User settings, switchable per character through the Profiles tab. Every character shares the "Default"
-- profile unless given its own, which is what makes the chat the same everywhere.
---@class SeamlessChat.DB.Profile
---@field chat SeamlessChat.Snapshot? the synced chat setup; nil until a character using this profile logs in
local profile = {
    features = {},
    inputHistoryLines = 25,
    persistInputHistory = true,
    -- What the profile's characters share (src/chat/sync.lua).
    sync = {
        windows = true, -- the chat tabs and windows, with the message types and channels each shows
        colors = true, -- chat colors and class-colored names
        channels = true, -- joined custom channels
        position = true, -- the main chat window's position and size (Edit Mode)
    },
}

-- Data tied to one character.
---@class SeamlessChat.DB.Char
---@field inputHistory table<string, string[]>? sent input by regular chat frame name
local char = {}

-- Account-wide data shared by every character.
---@class SeamlessChat.DB.Global
local global = {
    dbVersion = 1,
}

---@class SeamlessChat.DBDefaults : AceDB.Schema
app.dbDefaults = {
    profile = profile,
    char = char,
    global = global,
}

-- All feature defaults are defined here so they can be tuned without editing feature code.
app.dbDefaults.profile.features = {
    background = {
        enabled = true,
        color = { r = 0, g = 0, b = 0, a = 1 }, -- black, fully opaque
    },
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
    log = {
        enabled = true,
        maxMessages = 25000,
        maxDays = 30,
        showButton = true, -- the chat log button beside the chat
    },
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
    timestamps = {
        enabled = true,
        format = "%H:%M:%S", -- one of FORMATS, or "custom" for customFormat
        customFormat = "%H:%M:%S",
        brackets = "square", -- key of BRACKETS
        colored = false, -- own color instead of the message's
        color = { r = 0.6, g = 0.6, b = 0.6 },
    },
    unread = {
        enabled = false,
        channels = true, -- numbered channels (General, Trade, ...) count too
        color = { r = 0.75, g = 0.12, b = 0.1 }, -- the badge
    },
    urls = {
        enabled = true,
        color = { r = 0.25, g = 0.66, b = 0.96 },
    },
}
