---@type string, SeamlessUnitframes
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- The settings of one unit frame. `["**"]` gives every key of profile.unitFrames (the keys of
-- app.unitFrames.list) these defaults; a key of its own overrides some and gets the rest.
---@class SeamlessUnitframes.DB.UnitFrame
local unitFrame = {
    -- src/healthcolor. Class plus reaction for NPCs by default; see the frames below.
    ---@type SeamlessUnitframes.HealthBarColor
    healthBarColor = "classReaction",
    -- src/name. The game's full name (first name and surname).
    ---@type SeamlessUnitframes.NameDisplayMode
    nameDisplay = "full",
    -- src/portrait. A player character's class icon instead of the portrait.
    classIcon = false,
    -- src/pvpicon. Hides the frame's PvP icon.
    hidePvPIcon = false,
}

-- Player, pet and party only show players (a pet takes its owner's class), so reaction adds
-- nothing there.
---@type table<string, SeamlessUnitframes.DB.UnitFrame>
local unitFrames = {
    ["**"] = unitFrame,
    player = { healthBarColor = "class" },
    pet = { healthBarColor = "class" },
    party = { healthBarColor = "class" },
}

-- User settings, switchable per character via AceDBOptions.
---@class SeamlessUnitframes.DB.Profile
local profile = {
    layout = "current",
    unitFrames = unitFrames,
    targetQuestIcon = { enabled = false, scale = 1.7, x = -30, y = 25 },
}

-- Data tied to one character.
---@class SeamlessUnitframes.DB.Char
local char = {}

-- Account-wide data shared by every character.
---@class SeamlessUnitframes.DB.Global
local global = {
    dbVersion = 1,
}

---@class SeamlessUnitframes.DBDefaults : AceDB.Schema
app.dbDefaults = {
    profile = profile,
    char = char,
    global = global,
}
