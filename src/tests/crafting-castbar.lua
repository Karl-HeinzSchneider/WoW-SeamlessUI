-- lua src/tests/crafting-castbar.lua
local app = {}
local hooks = {}
local active = true
app.addon = {
    IsEnabled = function()
        return active
    end,
    SecureHook = function(_, object, method, callback)
        if type(object) == "string" then
            hooks[object] = method
        else
            hooks[method] = callback
        end
    end,
}
DoTradeSkill = function() end
StopTradeSkillRepeat = function() end
C_TradeSkillUI = { CraftRecipe = function() end }
local now, current = 0, nil
GetTime = function()
    return now
end
UnitCastingInfo = function()
    if current then
        return "Craft",
            "Craft",
            1,
            current.start * 1000,
            current.finish * 1000,
            current.trade,
            current.id,
            false,
            current.spell
    end
end
local finishes, stops, failures = 0, 0, 0
local bar = { scripts = {}, events = {} }
function bar:SetMinMaxValues(_, max)
    self.range = max
end
function bar:SetValue(value)
    self.display = value
end
function bar:UpdateCastTimeText()
    self.remaining = self.maxValue - self.value
end
function bar:RegisterUnitEvent(event, unit)
    self.events[event] = unit
end
function bar:UnregisterEvent(event)
    self.events[event] = nil
end
function bar:GetScript(event)
    return self.scripts[event]
end
function bar:SetScript(event, handler)
    self.scripts[event] = handler
end
function bar:HandleCastStart()
    self.casting, self.castID = true, current.id
    self.value, self.maxValue = now - current.start, current.finish - current.start
end
bar.HandleCastDelayed = bar.HandleCastStart
function bar:HandleCastStop(_, id)
    if self.castID == id then
        self.casting = nil
        stops = stops + 1
    end
end
function bar:FinishSpell()
    self.casting = nil
    finishes = finishes + 1
end
function bar:HandleInterruptOrSpellFailed(_, _, id)
    if id == self.castID then
        self.casting = nil
        failures = failures + 1
    end
end
bar.scripts.OnEvent = function(self, event, unit, id)
    if unit ~= "player" then
        return
    end
    if event == "UNIT_SPELLCAST_START" then
        self:HandleCastStart(event)
    elseif event == "UNIT_SPELLCAST_STOP" then
        self:HandleCastStop(event, id)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        self:HandleInterruptOrSpellFailed(false, event, id)
    end
end
bar.scripts.OnUpdate = function(self, elapsed)
    if self.casting then
        self.value = self.value + elapsed
        if self.value >= self.maxValue then
            self:FinishSpell()
        end
    end
end
assert(loadfile("SeamlessCastbar/src/crafting.lua"))("SeamlessCastbar", app)
app.InstallCraftingBar(bar)
app.EnableCraftingBar(bar)
assert(bar.events.UNIT_SPELLCAST_SUCCEEDED == "player")
local function event(name, id)
    bar.scripts.OnEvent(bar, name, "player", id)
end
local function cast(id, start, duration, trade, spell)
    now = start
    current = { id = id, start = start, finish = start + duration, trade = trade ~= false, spell = spell or 42 }
    event("UNIT_SPELLCAST_START", id)
end
local function near(value, expected)
    assert(math.abs(value - expected) < 0.00001, tostring(value) .. " ~= " .. expected)
end
hooks.DoTradeSkill(1, 3)
cast("a", 0, 2)
near(bar.maxValue, 6)
now = 2
-- STOP may precede SUCCEEDED; never play the intermediate finish animation.
event("UNIT_SPELLCAST_STOP", "a")
assert(bar.casting and stops == 0)
event("UNIT_SPELLCAST_SUCCEEDED", "a")
event("UNIT_SPELLCAST_SUCCEEDED", "a") -- duplicate must not count twice
now = 2.3
bar.scripts.OnUpdate(bar, 0.3)
near(bar.remaining, 4)
cast("b", 2.3, 2)
near(bar.maxValue, 6.3)
near(bar.value, 2.3)
-- A late notification for another cast must not advance the batch.
event("UNIT_SPELLCAST_SUCCEEDED", "unrelated")
now = 4.3
event("UNIT_SPELLCAST_SUCCEEDED", "b")
event("UNIT_SPELLCAST_STOP", "b")
cast("c", 4.8, 1.5) -- duration may change, not just the gap
near(bar.maxValue, 6.3)
near(bar.remaining, 1.5)
now = 6.3
event("UNIT_SPELLCAST_SUCCEEDED", "c")
event("UNIT_SPELLCAST_STOP", "c")
assert(not bar.casting and stops == 1)
cast("normal", 7, 2, false)
near(bar.maxValue, 2)
-- Synchronous START before the secure post-hook still attaches to the current craft.
cast("sync", 10, 2)
hooks.DoTradeSkill(1, 4)
near(bar.maxValue, 8)
event("UNIT_SPELLCAST_INTERRUPTED", "sync")
assert(failures == 1)
cast("after", 11, 2, false)
near(bar.maxValue, 2)
-- Explicit queue cancellation restores the remaining ordinary current cast.
hooks.CraftRecipe(42, 3)
cast("cancel", 15, 2)
hooks.StopTradeSkillRepeat()
near(bar.maxValue, 2)
-- Single crafts never become batch casts.
hooks.DoTradeSkill(1, 1)
cast("single", 20, 2)
near(bar.maxValue, 2)
-- Disabling clears pending batches and the extra subscription.
hooks.DoTradeSkill(1, 5)
app.DisableCraftingBar(bar)
assert(not bar.events.UNIT_SPELLCAST_SUCCEEDED)
cast("disabled", 25, 2)
near(bar.maxValue, 2)
print("PASS: crafting batches, per-cast lag rebasing, changed duration, event ordering, interruption and cancellation")
