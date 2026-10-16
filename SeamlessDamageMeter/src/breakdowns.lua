---@type string, SeamlessDamageMeter
local _, app = ...
local service = app.combatService
local archive = app.archive

local function Sort(entries)
    table.sort(entries, function(a, b)
        if a.totalAmount == b.totalAmount then
            return a.spellName < b.spellName
        end
        return a.totalAmount > b.totalAmount
    end)
end

-- Reverse lookup: the enemy view identifies contributors, unlike player spell summaries.
function service:GetEnemyIndex(config)
    self:Resolve(config)
    local key = self:CacheKey(config, "enemyIndex")
    if self.cache[key] then
        return unpack(self.cache[key])
    end
    local session, reason = self:GetSession(config, "EnemyDamageTaken")
    if not session then
        return nil, reason or "Enemy data is restricted or incomplete."
    end
    local index = { enemies = {}, players = {}, complete = true }
    for sourceIndex, enemy in ipairs(session.combatSources) do
        -- Only public fields needed for analysis are required. An optional secret GUID
        -- or spell ID must not prevent an otherwise public contribution breakdown.
        if
            not app.live:IsReadableTable(enemy)
            or not archive:IsPublic(enemy.name)
            or type(enemy.name) ~= "string"
            or not archive:IsPublic(enemy.totalAmount)
            or type(enemy.totalAmount) ~= "number"
        then
            return nil, "Enemy data is restricted or incomplete."
        end
        local publicEnemy = { name = enemy.name, totalAmount = enemy.totalAmount }
        for _, field in ipairs({ "sourceGUID", "sourceCreatureID", "classFilename", "specIconID" }) do
            if archive:IsPublic(enemy[field]) then
                publicEnemy[field] = enemy[field]
            end
        end
        local details = self:GetDetails(config, enemy, "EnemyDamageTaken")
        if not details or not app.live:IsReadableTable(details.combatSpells) then
            return nil, "Enemy contributions were not captured or are restricted."
        end
        local contributors, byName = {}, {}
        for _, spell in ipairs(details.combatSpells) do
            if
                not app.live:IsReadableTable(spell)
                or not archive:IsPublic(spell.totalAmount)
                or type(spell.totalAmount) ~= "number"
            then
                return nil, "Enemy contribution amounts are restricted."
            end
            local unit = spell.combatSpellDetails
            if
                not app.live:IsReadableTable(unit)
                or not archive:IsPublic(unit.unitName)
                or type(unit.unitName) ~= "string"
                or unit.unitName == ""
            then
                return nil, "Enemy contributor identities are incomplete."
            end
            local contributor = byName[unit.unitName]
            if not contributor then
                contributor = {
                    spellName = unit.unitName,
                    totalAmount = 0,
                    amountPerSecond = 0,
                    hasRate = true,
                    combatSpellDetails = {},
                    isTarget = true,
                }
                byName[unit.unitName] = contributor
                contributors[#contributors + 1] = contributor
                for _, field in ipairs({ "unitClassFilename", "specIconID" }) do
                    if archive:IsPublic(unit[field]) then
                        contributor.combatSpellDetails[field] = unit[field]
                    end
                end
            end
            contributor.totalAmount = contributor.totalAmount + spell.totalAmount
            if archive:IsPublic(spell.amountPerSecond) and type(spell.amountPerSecond) == "number" then
                contributor.amountPerSecond = contributor.amountPerSecond + spell.amountPerSecond
            else
                contributor.hasRate = false
            end
        end
        local accounted = 0
        for name, contributor in pairs(byName) do
            if not contributor.hasRate then
                contributor.amountPerSecond = nil
            end
            accounted = accounted + contributor.totalAmount
            contributor.enemyShare = publicEnemy.totalAmount > 0
                    and contributor.totalAmount / publicEnemy.totalAmount * 100
                or 0
            local targets = index.players[name] or {}
            index.players[name] = targets
            targets[#targets + 1] = {
                spellName = publicEnemy.name,
                totalAmount = contributor.totalAmount,
                amountPerSecond = contributor.amountPerSecond,
                enemyShare = contributor.enemyShare,
                sourceGUID = publicEnemy.sourceGUID,
                sourceCreatureID = publicEnemy.sourceCreatureID,
                combatSpellDetails = {
                    unitClassFilename = publicEnemy.classFilename,
                    specIconID = publicEnemy.specIconID,
                },
                isTarget = true,
            }
        end
        -- Partial relationships are labelled rather than silently presented as complete.
        if
            math.abs(accounted - publicEnemy.totalAmount)
            > math.max(0.01, math.abs(publicEnemy.totalAmount) * 0.000001)
        then
            index.complete = false
        end
        Sort(contributors)
        index.enemies[sourceIndex] = {
            entries = contributors,
            maxAmount = contributors[1] and contributors[1].totalAmount or 0,
            totalAmount = publicEnemy.totalAmount,
            name = publicEnemy.name,
        }
    end
    for _, targets in pairs(index.players) do
        Sort(targets)
    end
    self.cache[key] = { index }
    return index
end

function service:GetPlayerTargets(config, source)
    if not archive:IsPublic(source.name) or not archive:IsPublic(source.totalAmount) then
        return nil, "Target data restricted."
    end
    local index, reason = self:GetEnemyIndex(config)
    if not index then
        return nil, reason
    end
    local targets = index.players[source.name] or {}
    local total = 0
    for _, target in ipairs(targets) do
        total = total + target.totalAmount
    end
    local complete = index.complete
        and math.abs(total - source.totalAmount) <= math.max(0.01, math.abs(source.totalAmount) * 0.000001)
    return {
        entries = targets,
        maxAmount = targets[1] and targets[1].totalAmount or 0,
        totalAmount = source.totalAmount,
        complete = complete,
        message = not complete and "Available contributions only; totals do not fully reconcile." or nil,
    }
end

function service:GetEnemyContributors(config, source)
    local index, reason = self:GetEnemyIndex(config)
    if not index then
        return nil, reason
    end
    local session = self:GetSession(config, "EnemyDamageTaken")
    for position, enemy in ipairs(session.combatSources) do
        if enemy == source then
            local result = index.enemies[position]
            result.complete = index.complete
            return result
        end
    end
    return nil, "This enemy row is no longer current."
end

function service:GetMetadata(config)
    if app.IsEditingWindows and app:IsEditingWindows() then
        return nil
    end
    local fight = self:Resolve(config)
    return fight
end

local function CompareEntries(first, second, targets, statistic)
    local entries, byKey = {}, {}
    for side, list in ipairs({ first or {}, second or {} }) do
        for _, entry in ipairs(list) do
            local unit = statistic == "EnemyDamageTaken"
                    and entry.combatSpellDetails
                    and entry.combatSpellDetails.unitName
                or ""
            local id = targets and (entry.sourceGUID or entry.sourceCreatureID or entry.spellName)
                or ((entry.spellID or 0) .. ":" .. (entry.creatureName or "") .. ":" .. unit)
            local row = byKey[id]
            if not row then
                row = {
                    name = entry.spellName or (unit ~= "" and unit) or ("Spell " .. (entry.spellID or 0)),
                    spellID = entry.spellID,
                    first = 0,
                    second = 0,
                    firstRate = 0,
                    secondRate = 0,
                }
                byKey[id] = row
                entries[#entries + 1] = row
            end
            if side == 1 then
                row.first, row.firstRate = row.first + entry.totalAmount, row.firstRate + (entry.amountPerSecond or 0)
            else
                row.second, row.secondRate =
                    row.second + entry.totalAmount, row.secondRate + (entry.amountPerSecond or 0)
            end
        end
    end
    for _, row in ipairs(entries) do
        row.delta = row.second - row.first
    end
    table.sort(entries, function(x, y)
        return x.second > y.second
    end)
    return entries
end

function service:Compare(firstID, secondID, key, mode)
    local first, second = archive:Get(firstID), archive:Get(secondID)
    local a, b = first and first.categories[key], second and second.categories[key]
    if not a or not b then
        return nil, "Both fights need this statistic."
    end
    local rows, byName = {}, {}
    for side, category in ipairs({ a, b }) do
        for _, source in ipairs(category.session.combatSources) do
            local identity = source.sourceGUID
                or (source.sourceCreatureID and ("creature:" .. source.sourceCreatureID))
                or source.name
            local row = byName[identity]
            if not row then
                row = { name = source.name, first = 0, second = 0, firstRate = 0, secondRate = 0, sources = {} }
                byName[identity] = row
                rows[#rows + 1] = row
            end
            row.sources[side] = source
            if side == 1 then
                row.first, row.firstRate = source.totalAmount, source.amountPerSecond
            else
                row.second, row.secondRate = source.totalAmount, source.amountPerSecond
            end
        end
    end
    for _, row in ipairs(rows) do
        row.delta, row.rateDelta = row.second - row.first, row.secondRate - row.firstRate
        if mode == "spells" or mode == "targets" then
            local lists = {}
            for side, id in ipairs({ firstID, secondID }) do
                local source = row.sources[side]
                local config = { archiveID = id, statistic = key }
                if source and mode == "spells" then
                    local detail = self:GetDetails(config, source, key)
                    lists[side] = detail and detail.combatSpells
                    if not lists[side] then
                        row.incomplete = true
                    end
                elseif source and (key == "DamageDone" or key == "Dps") then
                    local detail = self:GetPlayerTargets(config, source)
                    lists[side] = detail and detail.entries
                    if not detail or not detail.complete then
                        row.incomplete = true
                    end
                elseif source then
                    row.incomplete = true
                end
            end
            row.breakdown = CompareEntries(lists[1], lists[2], mode == "targets", key)
        end
    end
    table.sort(rows, function(x, y)
        if app:GetStatistic(key).rate then
            return x.secondRate > y.secondRate
        end
        return x.second > y.second
    end)
    return rows
end

function service:Report(config)
    local fight = self:Resolve(config)
    if not fight then
        return nil, "Select a saved fight to report."
    end
    local key = app:GetStatistic(config.statistic).key
    local category = fight.categories[key]
    if not category then
        return nil, "This statistic was not captured."
    end
    local lines = { "Seamless: " .. fight.name .. " - " .. app:GetStatistic(key).label }
    for index, source in ipairs(category.session.combatSources) do
        local counts = key == "Interrupts" or key == "Dispels" or key == "Deaths"
        lines[#lines + 1] = ("%d. %s: %s"):format(index, source.name, AbbreviateLargeNumbers(source.totalAmount))
            .. (counts and "" or (" (%s/s)"):format(AbbreviateLargeNumbers(source.amountPerSecond)))
        if index == 10 then
            break
        end
    end
    return table.concat(lines, "\n")
end
