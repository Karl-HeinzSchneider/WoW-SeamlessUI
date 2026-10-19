---@type string, SeamlessUI
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- User settings, switchable per character through the Profiles tab.
---@class SeamlessUI.DB.Profile
local profile = {
    -- Reserved for settings of future UI improvements.
    ---@type table<string, table>
    features = {},
}

-- Data tied to one character.
---@class SeamlessUI.DB.Char
local char = {}

-- Account-wide data shared by every character.
---@class SeamlessUI.DB.Global
local global = {
    dbVersion = 1,
}

---@class SeamlessUI.DBDefaults : AceDB.Schema
app.dbDefaults = {
    profile = profile,
    char = char,
    global = global,
}
