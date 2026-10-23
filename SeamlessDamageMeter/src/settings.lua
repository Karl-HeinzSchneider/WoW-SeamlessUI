---@type string, SeamlessDamageMeter
local _, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

app.MAX_WINDOWS = 10
function app:GetWindowSetting(config, key)
    if key == "height" and self:GetWindowSetting(config, "fixedHeight") then
        local lines = self:GetWindowSetting(config, "visibleLines")
        local spacing = self:GetWindowSetting(config, "rowSpacing")
        return 32 + 8 + lines * (self:GetWindowSetting(config, "rowHeight") + spacing) - spacing
    end
    if self.skinDefaults[key] ~= nil then
        local override = config.styleOverrides and config.styleOverrides[key]
        if config.modifyGlobalStyle == false and override ~= nil then
            return override
        end
        local skins = self.db.profile.skins
        local skin = skins and (skins[config.skin or "default"] or skins.default)
        local value = skin and skin.settings[key]
        if value ~= nil then
            return value
        end
        return self.skinDefaults[key]
    end
    local value = config.overrides and config.overrides[key]
    if value ~= nil then
        return value
    end
    return self.db.profile.windowDefaults[key]
end

local function CopySettings(source)
    local result = {}
    for key, fallback in pairs(app.skinDefaults) do
        local value = source[key]
        if value == nil then
            value = fallback
        end
        result[key] = type(value) == "table" and { unpack(value) } or value
    end
    return result
end

function app:AddSkin(name)
    name = name:match("^%s*(.-)%s*$")
    if name == "" then
        return
    end
    local skins = self.db.profile.skins
    local id = 1
    while skins["skin" .. id] do
        id = id + 1
    end
    local key = "skin" .. id
    skins[key] = { name = name, settings = CopySettings(skins.default.settings) }
    self:UpdateWindowOptions()
    return key
end

function app:PrepareWindowSettings()
    local profile = self.db.profile
    profile.skins = profile.skins or {}
    if not profile.skins.default then
        profile.skins.default = { name = L["Default"], settings = CopySettings(profile.windowDefaults) }
    end
    for _, skin in pairs(profile.skins) do
        skin.settings = skin.settings or {}
        for key, value in pairs(self.skinDefaults) do
            if skin.settings[key] == nil then
                skin.settings[key] = type(value) == "table" and { unpack(value) } or value
            end
        end
    end
    for key in pairs(self.skinDefaults) do
        profile.windowDefaults[key] = nil
    end
    profile.favorites = profile.favorites or {}
    profile.maxVisibleFavorites = math.max(0, math.min(20, math.floor(tonumber(profile.maxVisibleFavorites) or 6)))
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
        if not config.skin then
            config.skin = "default"
            local customized = false
            local settings = CopySettings(profile.skins.default.settings)
            for key in pairs(self.skinDefaults) do
                if config.overrides[key] ~= nil then
                    settings[key] = type(config.overrides[key]) == "table" and { unpack(config.overrides[key]) }
                        or config.overrides[key]
                    customized = true
                end
            end
            if customized then
                local key = "legacyWindow" .. config.id
                profile.skins[key] = { name = L["Window %d (migrated)"]:format(config.id), settings = settings }
                config.skin = key
            end
        end
        if not profile.skins[config.skin] then
            config.skin = "default"
        end
        for key in pairs(self.skinDefaults) do
            config.overrides[key] = nil
        end
        if config.favorites then
            for slot, key in pairs(config.favorites) do
                if profile.favorites[slot] == nil then
                    profile.favorites[slot] = key
                end
            end
            config.favorites = nil
        end
        -- Keep old layouts while all new windows inherit the profile defaults.
        for _, key in ipairs({ "width", "height", "x", "y" }) do
            if config[key] ~= nil then
                config.overrides[key] = config[key]
                config[key] = nil
            end
        end
    end
    if not profile.nativeBarFont then
        for _, skin in pairs(profile.skins) do
            if skin.settings.font == "Friz Quadrata TT" or skin.settings.font == "Arial Narrow" then
                skin.settings.font = "Default damage meter"
            end
        end
        profile.nativeBarFont = true
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
        self:BuildSkinOptions()
        self.core:RefreshOptions("SeamlessDamageMeter")
    end
end
