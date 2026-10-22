---@type string, SeamlessCastbar
local _, app = ...

---@param icon boolean whether the bar has the spell icon option
local function barDefaults(icon)
    return {
        enabled = true,
        castTime = { enabled = true, format = "ELAPSED_TOTAL", decimals = 1 },
        rank = { enabled = true },
        ticks = { enabled = true },
        icon = icon and { enabled = true } or nil,
        hold = { enabled = false, success = 0.2, interrupt = 1 },
    }
end

app.dbDefaults = {
    profile = {
        player = barDefaults(true),
        target = barDefaults(false),
        focus = barDefaults(false),
        -- position.lua. Moved target/focus bars: positions[key][Edit Mode layout name] = position.
        positions = { target = {}, focus = {} },
    },
}
