---@type string, SeamlessTooltip
local _, app = ...

-- AceDB-3.0 defaults. Missing keys in the SavedVariables fall back to these values,
-- and values equal to the default are not written to disk.

-- User settings, switchable per character through the Profiles tab.
---@class SeamlessTooltip.DB.Profile
local profile = {
    -- One settings table per feature; edit the defaults below.
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

-- All feature defaults are defined here so they can be tuned without editing feature code.
app.dbDefaults.profile.features = {
    ActionButtonAnchor = {
        enabled = true,
        position = "ANCHOR_RIGHT",
    },
    AuraSource = {
        enabled = true,
    },
    Backdrop = {
        enabled = true,
        background = "Blizzard Collections Background",
        backgroundColor = { r = 0.09, g = 0.09, b = 0.19, a = 1 },
        border = "Blizzard Tooltip",
        borderColor = { r = 1, g = 1, b = 1, a = 1 },
        edgeSize = 16,
        inset = 4,
    },
    CreatureFamily = {
        enabled = false,
    },
    CursorAnchor = {
        enabled = false,
        position = "ANCHOR_CURSOR_RIGHT",
        offsetX = 16,
        offsetY = 0,
    },
    HealthBar = {
        enabled = true,
        inside = true,
        inset = 6,
        height = 10,
        texture = "Blizzard",
        backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
        text = "VALUE_MAX",
    },
    HideTitle = {
        enabled = false,
    },
    HideUnits = {
        enabled = false,
        when = "COMBAT",
        modifier = "SHIFT",
        unitFrames = false,
    },
    ItemDetails = {
        enabled = true,
        stackSize = false,
    },
    ItemIDs = {
        enabled = true,
        item = true,
        icon = false,
    },
    ItemLevel = {
        enabled = true,
        qualityColor = true,
    },
    NpcText = {
        enabled = true,
        shortLevel = true,
        faction = "SHOW",
    },
    PlayerText = {
        enabled = true,
        classColorName = true,
        classColorClass = true,
        raceReactionColor = false,
        shortLevel = true,
        hideClass = false,
        guildLine = true,
        guildRank = true,
        guildRankIndex = false,
        faction = "SHOW",
    },
    QualityBorder = {
        enabled = true,
        minQuality = 2,
    },
    RaidIcon = {
        enabled = true,
    },
    Scale = {
        enabled = false,
        scale = 1,
    },
    SpellIDs = {
        enabled = true,
        spell = true,
        icon = false,
    },
    StatusTags = {
        enabled = true,
        afk = true,
        offline = true,
        dead = true,
        pvp = false,
        hidePvpLine = false,
    },
    TappedName = {
        enabled = true,
    },
    TargetedBy = {
        enabled = true,
        names = true,
        you = true,
    },
    TargetLine = {
        enabled = true,
        you = true,
    },
    UnitBorder = {
        enabled = true,
        players = true,
        npcs = true,
        tapped = true,
    },
    VendorPrice = {
        enabled = true,
        perItem = true,
    },
}
