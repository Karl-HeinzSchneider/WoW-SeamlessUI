---@type string, SeamlessDamageMeter
local _, app = ...

app.MAX_WINDOWS = 10
app.windowDefaults = {
    width = 400,
    height = 200,
    scale = 1,
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    font = "Friz Quadrata TT",
    fontSize = 12,
    fontFlags = "",
    textColor = { 1, 1, 1, 1 },
    barColor = { 0.35, 0.6, 0.8, 1 },
    classColors = true,
    backgroundColor = { 1, 1, 1, 0.5 },
    headerColor = { 1, 1, 1, 1 },
    rowHeight = 18,
    rowSpacing = 4,
}

function app:GetWindowSetting(config, key)
    local value = config.overrides and config.overrides[key]
    if value ~= nil then
        return value
    end
    return self.db.profile.windowDefaults[key]
end

function app:PrepareWindowSettings()
    local profile = self.db.profile
    if not profile.fixedWindowSlots then
        local used, remapped, assigned, pending = {}, {}, {}, {}
        -- Preserve existing slot IDs first, then move old increasing IDs into free slots.
        for _, config in ipairs(profile.windows) do
            local id = config.id
            if
                type(id) == "number"
                and id >= 1
                and id <= self.MAX_WINDOWS
                and id == math.floor(id)
                and not used[id]
            then
                used[id], assigned[config], remapped[id] = true, true, id
            else
                pending[#pending + 1] = config
            end
        end
        for _, config in ipairs(pending) do
            for id = 1, self.MAX_WINDOWS do
                if not used[id] then
                    if config.id ~= nil and remapped[config.id] == nil then
                        remapped[config.id] = id
                    end
                    config.id = id
                    used[id], assigned[config] = true, true
                    break
                end
            end
        end
        for index = #profile.windows, 1, -1 do
            local config = profile.windows[index]
            if not assigned[config] then
                -- Very old profiles could have more than ten windows; retain excess data.
                profile.legacyWindows = profile.legacyWindows or {}
                table.insert(profile.legacyWindows, 1, table.remove(profile.windows, index))
            elseif config.anchorTo then
                config.anchorTo = remapped[config.anchorTo]
            end
        end
        profile.fixedWindowSlots = true
        profile.nextID = nil
    end
    local slots = {}
    for _, config in ipairs(profile.windows) do
        if config.enabled == nil then
            config.enabled = true
        end
        slots[config.id] = config
    end
    for id = 1, self.MAX_WINDOWS do
        if not slots[id] then
            slots[id] = { id = id, enabled = false, statistic = "DamageDone", session = "Current", overrides = {} }
        end
        profile.windows[id] = slots[id]
    end
    if not profile.initialized then
        profile.windows[1].enabled = true
        profile.initialized = true
    end
    for _, config in ipairs(self.db.profile.windows) do
        config.overrides = config.overrides or {}
        -- Keep old layouts while all new windows inherit the profile defaults.
        for _, key in ipairs({ "width", "height", "x", "y" }) do
            if config[key] ~= nil then
                config.overrides[key] = config[key]
                config[key] = nil
            end
        end
    end
end

function app:GetUnusedWindowSlot()
    for _, config in ipairs(self.db.profile.windows) do
        if not config.enabled then
            return config.id
        end
    end
end

function app:CanAnchorTo(config, targetID)
    local visited = { [config.id] = true }
    while targetID do
        if visited[targetID] then
            return false
        end
        visited[targetID] = true
        local target
        for _, candidate in ipairs(self.db.profile.windows) do
            if candidate.id == targetID then
                target = candidate
                break
            end
        end
        if not target then
            return false
        end
        targetID = target.anchorTo
    end
    return true
end

function app:UpdateWindowOptions()
    if self.windowOptions then
        self:BuildWindowOptions()
        self.core:RefreshOptions("SeamlessDamageMeter")
    end
end
