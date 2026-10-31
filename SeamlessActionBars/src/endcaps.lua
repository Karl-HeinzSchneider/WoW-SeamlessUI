---@type string, SeamlessActionBars
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The main action bar's two gryphons are Blizzard Edit Mode systems: their position and Hidden
-- setting live in the Edit Mode layout. They have no size setting, so their Scale stays disabled.
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

---Apply the profile's textures, or restore the game's when `restore` is set.
---@param restore? boolean
function app.ApplyEndCaps(restore)
    for _, entry in ipairs(app.endCaps) do
        applyTexture(entry, restore)
    end
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
        -- Blizzard's own settings dialog already shows this layout setting.
        editModeHidden = true,
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

-- Each endcap's page below its Blizzard settings (SeamlessUI's Edit Mode extension).
function app.RegisterEndCapEditMode()
    local system = Enum.EditModeSystem and Enum.EditModeSystem.MainActionBarEndCap
    local indices = Enum.EditModeMainActionBarEndCapSystemIndices
    if not system or not indices then
        return
    end
    for _, entry in ipairs(app.endCaps) do
        local pageKey = entry.key == "left" and "endCapLeft" or "endCapRight"
        app.core:RegisterEditModeSystemOptions(appName .. ":endCap:" .. entry.key .. ":style", {
            system = system,
            systemIndex = indices[entry.index],
            name = app.optionPages[pageKey].config.name,
            page = { addon = appName, key = pageKey },
            enabled = function()
                return app.addon:IsEnabled()
            end,
        })
    end
end
