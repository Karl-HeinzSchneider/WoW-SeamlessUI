---@type string, SeamlessCastbar
local _, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local batch
local player
local craftSpark

local function hideCraftSpark()
    if craftSpark then
        craftSpark:Hide()
    end
end

local function updateCraftSpark(bar, waiting)
    if not batch or not batch.started or batch.duration <= 0 then
        hideCraftSpark()
        return
    end
    local progress = waiting and 1 or math.min(1, math.max(0, (GetTime() - batch.castStart) / batch.duration))
    -- Same pip dimensions as CastingBarFrameBaseTemplate (8 x 20 at height 11),
    -- with a deliberately fainter additive glow for the individual craft.
    craftSpark:SetSize(8, bar:GetHeight() + 9)
    craftSpark:ClearAllPoints()
    craftSpark:SetPoint("CENTER", bar, "LEFT", progress * bar:GetWidth(), 0)
    craftSpark:Show()
end

local function known(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

function app.RestoreCraftingName(bar)
    if batch and bar == player and batch.label and bar.Text:GetText() == batch.label then
        bar.Text:SetText(batch.name)
    end
end

function app.UpdateCraftingName(bar)
    if not batch or not batch.started or bar ~= player or not bar.Text then
        return
    end
    app.RestoreCraftingName(bar)
    local name = bar.Text:GetText()
    if not known(name) then
        return
    end
    batch.name = name
    batch.label = L["%s (%d/%d) (crafting progress)"]:format(name, batch.index, batch.count)
    bar.Text:SetText(batch.label)
end

-- Rebase against the actual current cast, retaining elapsed gaps in the total.
-- For example: 2 s completed + 0.3 s gap + two 2 s crafts = 6.3 s, not 6 s.
local function update(bar, waiting)
    if not batch or not batch.started then
        return
    end
    local now = GetTime()
    local remaining
    if waiting then
        remaining = (batch.count - batch.completed) * batch.duration
    else
        remaining = math.max(0, batch.castEnd - now) + (batch.count - batch.index) * batch.duration
    end
    bar.value = math.max(0, now - batch.started)
    bar.maxValue = bar.value + remaining
    bar:SetMinMaxValues(0, bar.maxValue)
    bar:SetValue(bar.value)
    bar:UpdateCastTimeText()
    updateCraftSpark(bar, waiting)
end

local function start(bar)
    local name, _, _, startTime, endTime, trade, castID, _, spellID = UnitCastingInfo("player")
    if
        not batch
        or not known(name)
        or not known(trade)
        or not trade
        or not known(startTime)
        or not known(endTime)
        or not known(castID)
        or not known(spellID)
    then
        batch = nil
        hideCraftSpark()
        return
    end
    if batch.spellID and (not known(spellID) or batch.spellID ~= spellID) then
        batch = nil
        hideCraftSpark()
        return
    end
    batch.spellID = spellID
    batch.started = batch.started or startTime / 1000
    batch.duration = (endTime - startTime) / 1000
    batch.castStart = startTime / 1000
    batch.castEnd = endTime / 1000
    batch.castID = castID
    batch.index = batch.completed + 1
    batch.waiting = false
    update(bar, false)
    app.UpdateCraftingName(bar)
end

local function requested(_, count, spellID)
    app.RestoreCraftingName(player)
    batch = nil
    hideCraftSpark()
    if not app.addon:IsEnabled() or not known(count) or type(count) ~= "number" or count <= 1 then
        return
    end
    batch = { count = math.floor(count), completed = 0, spellID = spellID }
    -- A client may dispatch the first START synchronously inside the crafting API,
    -- before our secure post-hook receives the requested quantity.
    if player.casting and UnitCastingInfo("player") then
        start(player)
    end
end

function app.InstallCraftingBar(bar)
    player = bar
    craftSpark = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    craftSpark:SetAtlas("ui-castingbar-pip")
    craftSpark:SetBlendMode("ADD")
    craftSpark:SetAlpha(0.3)
    craftSpark:Hide()
    local castStart = bar.HandleCastStart
    bar.HandleCastStart = function(self, event)
        castStart(self, event)
        if event == "UNIT_SPELLCAST_START" then
            start(self)
        else
            batch = nil
            hideCraftSpark()
        end
    end
    local delayed = bar.HandleCastDelayed
    bar.HandleCastDelayed = function(self, ...)
        delayed(self, ...)
        if batch then
            start(self)
        end
    end
    local stop = bar.HandleCastStop
    bar.HandleCastStop = function(self, event, castID, ...)
        if batch and batch.started and event == "UNIT_SPELLCAST_STOP" and known(castID) and castID == batch.castID then
            if batch.index < batch.count then
                batch.waiting = true
                update(self, true)
                return -- Keep the filling texture, spark and cast state between items.
            end
            stop(self, event, castID, ...)
            batch = nil
            hideCraftSpark()
            return
        end
        stop(self, event, castID, ...)
    end
    local finish = bar.FinishSpell
    bar.FinishSpell = function(self, ...)
        if batch and batch.started and batch.index < batch.count then
            batch.waiting = true
            update(self, true)
            return
        end
        finish(self, ...)
        batch = nil
        hideCraftSpark()
    end
    local interrupt = bar.HandleInterruptOrSpellFailed
    bar.HandleInterruptOrSpellFailed = function(self, empowered, event, castID, ...)
        if batch and (not batch.started or (known(castID) and castID == batch.castID)) then
            app.RestoreCraftingName(self)
            batch = nil
            hideCraftSpark()
        end
        interrupt(self, empowered, event, castID, ...)
    end
    local onEvent = bar:GetScript("OnEvent")
    bar:SetScript("OnEvent", function(self, event, unit, castID, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            batch = nil
            hideCraftSpark()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and batch and batch.started then
            if known(castID) and castID == batch.castID and batch.succeeded ~= castID then
                batch.succeeded = castID
                batch.completed = batch.completed + 1
            end
        end
        onEvent(self, event, unit, castID, ...)
    end)
    local onUpdate = bar:GetScript("OnUpdate")
    bar:SetScript("OnUpdate", function(self, elapsed)
        if batch and batch.started then
            update(self, batch.waiting)
            -- Native OnUpdate still owns spark placement and the final finish animation.
            onUpdate(self, 0)
        else
            onUpdate(self, elapsed)
        end
    end)
end

function app.EnableCraftingBar(bar)
    bar:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    if DoTradeSkill then
        app.addon:SecureHook("DoTradeSkill", requested)
    end
    -- CraftRecipe(recipeSpellID, numCasts): generated client TradeSkillUIDocumentation.lua.
    if C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
        app.addon:SecureHook(C_TradeSkillUI, "CraftRecipe", function(spellID, count)
            requested(nil, count, spellID)
        end)
    end
    if StopTradeSkillRepeat then
        app.addon:SecureHook("StopTradeSkillRepeat", function()
            if not batch then
                return
            end
            app.RestoreCraftingName(bar)
            batch = nil
            hideCraftSpark()
            if UnitCastingInfo("player") then
                bar:HandleCastDelayed()
            else
                bar:FinishSpell()
            end
        end)
    end
end

function app.DisableCraftingBar(bar)
    app.RestoreCraftingName(bar)
    batch = nil
    hideCraftSpark()
    bar:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
