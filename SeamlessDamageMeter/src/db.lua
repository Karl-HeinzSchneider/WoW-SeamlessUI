---@type string, SeamlessDamageMeter
local _, app = ...

app.windowDefaults = {
    width = 400,
    height = 200,
    fixedHeight = true,
    visibleLines = 7,
    showResizeHandle = true,
    lockSize = false,
    lockPosition = false,
    numbers = "complete",
    scale = 1,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
}

app.skinDefaults = {
    windowAlpha = 1,
    showIcons = true,
    font = "Default damage meter",
    fontSize = 15,
    fontFlags = "",
    textColor = { 1, 1, 1, 1 },
    barColor = { 0.35, 0.6, 0.8, 1 },
    classColors = true,
    hideTypeSelector = false,
    hideCombatTimer = false,
    backgroundColor = { 1, 1, 1, 0.5 },
    headerColor = { 1, 1, 1, 1 },
    rowHeight = 24,
    rowSpacing = 4,
}

app.dbDefaults = {
    char = {},
    profile = {
        windows = {},
        initialized = false,
        locked = false,
        hideBlizzard = true,
        windowDefaults = app.windowDefaults,
        favorites = {},
        maxVisibleFavorites = 6,
    },
}
