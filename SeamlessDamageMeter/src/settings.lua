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
