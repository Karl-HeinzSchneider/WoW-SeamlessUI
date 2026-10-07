---@type string, SeamlessTooltip
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- User settings, switchable per character through native profile controls.
---@class SeamlessTooltip.DB.Profile
local profile = {
    -- One table per feature, keyed like the feature; each file in src\features\ adds its own
    -- defaults (always `enabled`) through app.features:NewFeature.
    ---@type table<string, table>
    features = {},
}

-- Data tied to one character.
---@class SeamlessTooltip.DB.Char
local char = {}

-- Account-wide data shared by every character.
---@class SeamlessTooltip.DB.Global
local global = {
    dbVersion = 1,
}

---@class SeamlessTooltip.DBDefaults : AceDB.Schema
app.dbDefaults = {
    profile = profile,
    char = char,
    global = global,
}
