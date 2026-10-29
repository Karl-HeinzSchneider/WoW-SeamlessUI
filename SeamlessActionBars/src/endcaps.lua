---@type string, SeamlessActionBars
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The main action bar's two gryphons are Blizzard Edit Mode systems: their position and Hidden
-- setting live in the Edit Mode layout, but they have no size setting. Their scale is stored in
-- the profile and applied with the frame's own SetScale, which Edit Mode overrides to keep the
-- anchor offsets in place, so dragging and the native layout keep working.
---@type SeamlessActionBars.EndCap[]
app.endCaps = {
    { key = "left", index = "EndCapLeft", parentKey = "LeftEndCap", name = L["Left endcap"] },
    { key = "right", index = "EndCapRight", parentKey = "RightEndCap", name = L["Right endcap"] },
}

---The endcap's system frame, or nil before the action bar exists.
---@param entry SeamlessActionBars.EndCap
---@return table?
function app.EndCapFrame(entry)
    local caps = MainActionBar and MainActionBar.EndCaps
    return caps and caps[entry.parentKey]
end

local function settings(entry)
    return app.db.profile.endCaps[entry.key]
end

-- Capture only textures we override, so Default leaves the client's artwork untouched.
local originalAtlases = {}
local function applyTexture(entry, restore)
    local frame = app.EndCapFrame(entry)
    local texture = frame and frame.Texture
    if not texture then
        return
    end
    local choice = not restore and settings(entry).texture or "default"
    local creature = choice == "ally" and "gryphon" or choice == "horde" and "wyvern"
    if creature then
        if not originalAtlases[texture] then
            originalAtlases[texture] = texture:GetAtlas()
        end
        texture:SetAtlas("ui-hud-actionbar-" .. creature .. "-" .. entry.key)
    elseif originalAtlases[texture] then
        texture:SetAtlas(originalAtlases[texture])
        originalAtlases[texture] = nil
    end
end

---@param entry SeamlessActionBars.EndCap
---@return table
function app.EndCapTextureOption(entry)
    return {
        type = "select",
        name = L["Texture"],
        order = 6,
        default = "default",
        values = { default = L["Default"], ally = L["Alliance (Gryphon)"], horde = L["Horde (Wyvern)"] },
        sorting = { "default", "ally", "horde" },
        get = function()
            return settings(entry).texture
        end,
        set = function(_, value)
            settings(entry).texture = value
            if app.addon:IsEnabled() then
                applyTexture(entry)
            end
        end,
    }
end

-- Outside combat only: the frame is unprotected, but its scale feeds Edit Mode's layout code.
-- PLAYER_REGEN_ENABLED applies what was skipped.
local function applyScale(entry, scale)
    local frame = app.EndCapFrame(entry)
    if frame and not InCombatLockdown() and math.abs(frame:GetScale() - scale) > 1e-4 then
        frame:SetScale(scale)
    end
end

---Apply the profile's scales, or restore the game's scale when `restore` is set.
---@param restore? boolean
function app.ApplyEndCapScales(restore)
    for _, entry in ipairs(app.endCaps) do
        applyScale(entry, restore and 1 or settings(entry).scale)
        applyTexture(entry, restore)
    end
end

---Scale binding shared by the settings panel and SeamlessUI's Edit Mode Position section.
---@param entry SeamlessActionBars.EndCap
---@return SeamlessCore.PositionScale
function app.EndCapScale(entry)
    return {
        min = 0.5,
        max = 2,
        step = 0.01,
        get = function()
            return settings(entry).scale
        end,
        set = function(value)
            settings(entry).scale = value
            if app.addon:IsEnabled() then
                applyScale(entry, value)
            end
            app.core:RefreshOptions(appName)
        end,
        default = function()
            return app.dbDefaults.profile.endCaps[entry.key].scale
        end,
    }
end

---Hide toggle bound to the endcap's native Hidden setting, saved in the Edit Mode layout.
---@param entry SeamlessActionBars.EndCap
---@return table
function app.EndCapHiddenOption(entry)
    local service = app.core:GetFramePositionService()
    local function setting()
        return Enum.EditModeMainActionBarEndCapSetting and Enum.EditModeMainActionBarEndCapSetting.Hidden
    end
    local function value()
        local id = setting()
        return id and service:ReadSetting(app.EndCapFrame(entry), id)
    end
    return {
        type = "toggle",
        order = 5,
        width = "full",
        layoutStored = true,
        name = L["Hide endcap"],
        desc = L["Hide this gryphon outside Edit Mode. Edit Mode still shows it so you can select it."],
        descStyle = "inline",
        default = function()
            local id = setting()
            local default = id and service:GetDefaultSetting(app.EndCapFrame(entry), id)
            if default ~= nil then
                return default == 1 or default == true
            end
        end,
        disabled = function()
            return InCombatLockdown() or value() == nil or not service:CanEdit(app.EndCapFrame(entry))
        end,
        get = function()
            local current = value()
            return current == 1 or current == true
        end,
        set = function(_, hidden)
            local ok, err = service:ApplySetting(app.EndCapFrame(entry), setting(), hidden and 1 or 0)
            if not ok and err then
                app.core.logger:warn("%s", err)
            end
        end,
    }
end

-- SeamlessUI's Edit Mode extension shows the same scale in its Position section.
function app.RegisterEndCapScales()
    local system = Enum.EditModeSystem and Enum.EditModeSystem.MainActionBarEndCap
    local indices = Enum.EditModeMainActionBarEndCapSystemIndices
    if not system or not indices then
        return
    end
    for _, entry in ipairs(app.endCaps) do
        app.core:RegisterEditModeSystemScale(appName .. ":endCap:" .. entry.key, {
            system = system,
            systemIndex = indices[entry.index],
            enabled = function()
                return app.addon:IsEnabled()
            end,
            scale = app.EndCapScale(entry),
        })
        -- Reuse the page declaration, including its choices and profile accessors.
        local pageKey = entry.key == "left" and "endCapLeft" or "endCapRight"
        local option = app.optionPages[pageKey].config.args.texture
        local values = {}
        for _, value in ipairs(option.sorting) do
            values[#values + 1] = { text = option.values[value], value = value }
        end
        app.core:RegisterEditModeSystemOptions(appName .. ":endCap:" .. entry.key .. ":style", {
            system = system,
            systemIndex = indices[entry.index],
            name = L["Style"],
            key = appName .. ":endCap:" .. entry.key .. ":style",
            enabled = function()
                return app.addon:IsEnabled()
            end,
            options = {
                {
                    key = "texture",
                    type = option.type,
                    name = option.name,
                    default = option.default,
                    values = values,
                    get = option.get,
                    set = function(value)
                        option.set(nil, value)
                        app.core:RefreshOptions(appName)
                    end,
                },
            },
        })
    end
end
