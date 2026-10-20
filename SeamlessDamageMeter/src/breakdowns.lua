---@type string, SeamlessDamageMeter
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
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
        return nil, reason or L["Enemy data is restricted or incomplete."]
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
            return nil, L["Enemy data is restricted or incomplete."]
        end
        local publicEnemy = { name = enemy.name, totalAmount = enemy.totalAmount }
        for _, field in ipairs({ "sourceGUID", "sourceCreatureID", "classFilename", "specIconID" }) do
            if archive:IsPublic(enemy[field]) then
                publicEnemy[field] = enemy[field]
            end
        end
        local details = self:GetDetails(config, enemy, "EnemyDamageTaken")
        if not details or not app.live:IsReadableTable(details.combatSpells) then
            return nil, L["Enemy contributions were not captured or are restricted."]
        end
        local contributors, byName = {}, {}
        for _, spell in ipairs(details.combatSpells) do
            if
                not app.live:IsReadableTable(spell)
                or not archive:IsPublic(spell.totalAmount)
                or type(spell.totalAmount) ~= "number"
            then
                return nil, L["Enemy contribution amounts are restricted."]
            end
            local unit = spell.combatSpellDetails
            if
                not app.live:IsReadableTable(unit)
                or not archive:IsPublic(unit.unitName)
                or type(unit.unitName) ~= "string"
                or unit.unitName == ""
            then
                return nil, L["Enemy contributor identities are incomplete."]
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
        return nil, L["Target data restricted."]
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
        message = not complete and L["Available contributions only; totals do not fully reconcile."] or nil,
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
    return nil, L["This enemy row is no longer current."]
end

function service:GetMetadata(config)
    if app.IsEditingWindows and app:IsEditingWindows() then
        return nil
    end
    local fight = self:Resolve(config)
    return fight
end
