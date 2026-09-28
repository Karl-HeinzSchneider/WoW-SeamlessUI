---@type string, SeamlessUnitframes
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- Class colored health bars (src/classcolor): the whole feature, then one switch per unit frame,
-- keyed like app.classColor.frames.
---@class SeamlessUnitframes.DB.ClassColor
local classColor = {
    enabled = true,
    ---@type table<string, boolean>
    frames = {
        player = true,
        pet = true,
        target = true,
        targettarget = true,
        focus = true,
        focustarget = true,
        party = true,
    },
}

-- User settings, switchable per character via AceDBOptions.
---@class SeamlessUnitframes.DB.Profile
local profile = {
    logLevel = "INFO",
    minimap = {
        hide = false,
        -- Degrees around the minimap (0 = east, counter-clockwise), written by LibDBIcon on drag.
        -- LibDBIcon puts every button at 225 when it has none, so buttons nobody has dragged yet
        -- all stack on one spot; start somewhere else instead.
        minimapPos = 200,
    },
    classColor = classColor,
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
