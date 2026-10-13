---@type string, SeamlessChat
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- User settings, switchable per character through the Profiles tab. Every character shares the "Default"
-- profile unless given its own, which is what makes the chat the same everywhere.
---@class SeamlessChat.DB.Profile
---@field chat SeamlessChat.Snapshot? the synced chat setup; nil until a character using this profile logs in
local profile = {
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
