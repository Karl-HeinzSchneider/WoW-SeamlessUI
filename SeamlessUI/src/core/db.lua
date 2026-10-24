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
    fpsDisplay = {
        layouts = {},
        showLatency = false,
        whiteLatency = false,
        roundFramerate = false,
    },
    xpBarTooltip = {
        enabled = true,
        completedQuests = true,
        restedXPCap = 150,
        restedXPRate = 5,
    },
    blizzardEditMode = {
        enabled = true,
        -- Global switches for every frame's extension; combined with the internal per-frame
        -- values below (addMoreOptions only stores a preference for future controls).
        addPosition = true,
        addMoreOptions = true,
        -- Snaps the native settings dialog right of the Edit Mode window on each selection.
        snapSettingsDialog = true,
        frames = {
            ["*"] = { enabled = true, addPosition = true, addMoreOptions = true },
        },
    },
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
