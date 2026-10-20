---@type string, SeamlessCastbar
local _, app = ...

-- Lines on channeled spells where each tick lands. Spells are listed by the spell ID of their
-- first rank and matched by name, so every rank uses the same tick interval in seconds; the
-- number of ticks follows from the channel's length (Arcane Missiles rank 1 has 3, later ranks 5).
local intervalsBySpellID = {
    [10] = 1, -- Blizzard
    [689] = 1, -- Drain Life
    [740] = 2, -- Tranquility
    [746] = 1, -- First Aid (bandages)
    [755] = 1, -- Health Funnel
    [1120] = 3, -- Drain Soul
    [1510] = 1, -- Volley
    [1949] = 1, -- Hellfire
    [5138] = 1, -- Drain Mana
    [5143] = 1, -- Arcane Missiles
    [5740] = 2, -- Rain of Fire
    [12051] = 2, -- Evocation
    [15407] = 1, -- Mind Flay
    [16914] = 1, -- Hurricane
}

---@type table<string, number>?
local intervalsByName

---@param name string a channeled spell's name
---@return number? interval seconds between ticks
function app.TickInterval(name)
    if not intervalsByName then
        intervalsByName = {}
        for spellID, interval in pairs(intervalsBySpellID) do
            local spellName = C_Spell.GetSpellName(spellID)
            if spellName then
                intervalsByName[spellName] = interval
            end
        end
    end
    return intervalsByName[name]
end

-- Times after the channel's start at which a tick lands, without the last one at its end.
---@param interval number
---@param total number the channel's length; shorter than planned after pushback
---@return number[]
function app.TickTimes(interval, total)
    local times = {}
    local time = interval
    -- Leave out a tick that lands on the end of the bar.
    while time < total - 0.05 do
        times[#times + 1] = time
        time = time + interval
    end
    return times
end

-- The game's separator art between the stages of an empowered cast.
local TICK_ATLAS = "ui-castingbar-empower-pip"

---@type table<StatusBar, Texture[]>
local pools = {}

---@param bar StatusBar
function app.HideTicks(bar)
    for _, tick in ipairs(pools[bar] or {}) do
        tick:Hide()
    end
end

---@param bar StatusBar
function app.UpdateTicks(bar)
    app.HideTicks(bar)
    if not (app.Active(bar) and app.db.profile.ticks.enabled and bar.channeling) then
        return
    end
    local name = UnitChannelInfo(bar.unit)
    if not app.Known(name) or not name then
        return
    end
    local interval = app.TickInterval(name)
    local _, total = bar:GetMinMaxValues()
    if not interval or not app.Known(total) or total <= 0 then
        return
    end
    local width = bar:GetWidth()
    local pool = pools[bar] or {}
    pools[bar] = pool
    for i, time in ipairs(app.TickTimes(interval, total)) do
        local tick = pool[i]
        if not tick then
            tick = bar:CreateTexture(nil, "OVERLAY")
            tick:SetAtlas(TICK_ATLAS)
            tick:SetWidth(2)
            pool[i] = tick
        end
        -- A channel's bar runs down from full, so a tick after `time` seconds sits where the
        -- fill ends at that moment.
        local x = (total - time) / total * width
        tick:ClearAllPoints()
        tick:SetPoint("TOP", bar, "TOPLEFT", x, -1)
        tick:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x, 1)
        tick:Show()
    end
end
