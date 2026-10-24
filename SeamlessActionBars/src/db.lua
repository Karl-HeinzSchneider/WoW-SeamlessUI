---@type string, SeamlessActionBars
local _, app = ...

app.dbDefaults = {
    profile = {
        range = { enabled = true, color = { r = 0.85, g = 0.4, b = 0.4 } },
        mana = { enabled = true, color = { r = 0.3, g = 0.3, b = 1 } },
        keybinds = { enabled = true },
        -- Scale of the main action bar's gryphons (Edit Mode has no size setting for them).
        endCaps = { left = { scale = 1 }, right = { scale = 1 } },
    },
}
