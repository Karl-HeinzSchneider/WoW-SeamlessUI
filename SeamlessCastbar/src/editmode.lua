---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The player cast bar's options in its own Edit Mode settings, under a collapsible Style header.
-- They show in LibEditMode's window below the client's dialog for the cast bar system and write
-- the same profile as the Player tab. LibEditMode cannot remove system settings again, so the
-- rows hide while the addon is disabled.

local lib = app.core:GetEditModeLibrary()

local function player()
    return app.db.profile.player
end

local function changed()
    app.addon:Refresh()
    app.core:RefreshOptions(appName)
end

local function hidden()
    return not app.addon:IsEnabled()
end

-- Greyed out while the player bar or, when given, the feature is switched off.
local function disabledUnless(feature)
    return function()
        return not player().enabled or (feature ~= nil and not player()[feature].enabled)
    end
end

-- Slider steps of 0.1 arrive as 0.30000000000000004.
local function tenths(value)
    return math.floor(value * 10 + 0.5) / 10
end

---@param name string
---@param desc string?
---@param default boolean
---@param feature string? the profile table; nil for the bar's own switch
local function checkbox(name, desc, default, feature)
    return {
        kind = lib.SettingType.Checkbox,
        name = name,
        desc = desc,
        default = default,
        get = function()
            return (feature and player()[feature] or player()).enabled
        end,
        set = function(_, value)
            (feature and player()[feature] or player()).enabled = value
            changed()
        end,
        disabled = feature and disabledUnless() or nil,
        hidden = hidden,
    }
end

---@param name string
---@param feature string
---@param key string
---@param default number
---@param minValue number
---@param maxValue number
---@param step number
local function slider(name, feature, key, default, minValue, maxValue, step)
    return {
        kind = lib.SettingType.Slider,
        name = name,
        default = default,
        minValue = minValue,
        maxValue = maxValue,
        valueStep = step,
        get = function()
            return player()[feature][key]
        end,
        set = function(_, value)
            player()[feature][key] = step < 1 and tenths(value) or value
            changed()
        end,
        formatter = function(value)
            return step < 1 and ("%.1f"):format(value) or tostring(value)
        end,
        disabled = disabledUnless(feature),
        hidden = hidden,
    }
end

---@return table[] rows LibEditMode settings for the cast bar system
function app.EditModeSettings()
    local formats = {}
    for _, format in ipairs(app.castTimeFormatOrder) do
        formats[#formats + 1] = { text = app.castTimeFormats[format], value = format }
    end
    return {
        { kind = lib.SettingType.Header, name = L["Style"], key = "castbar-style", hidden = hidden },
        checkbox(L["Enable"], L["Apply the Seamless options to this cast bar."], true),
        checkbox(
            L["Cast time"],
            L["Change how the player cast bar's cast time reads. Show it with Show Cast Time in the cast bar's Edit Mode settings."],
            true,
            "castTime"
        ),
        {
            kind = lib.SettingType.Dropdown,
            name = L["Cast time format"],
            default = "ELAPSED_TOTAL",
            values = formats,
            get = function()
                return player().castTime.format
            end,
            set = function(_, value)
                player().castTime.format = value
                changed()
            end,
            disabled = disabledUnless("castTime"),
            hidden = hidden,
        },
        slider(L["Decimals"], "castTime", "decimals", 1, 0, 2, 1),
        checkbox(
            L["Spell rank"],
            L["Add the spell's rank to its name on the cast bar, such as Frostbolt (Rank 3)."],
            true,
            "rank"
        ),
        checkbox(
            L["Channel ticks"],
            L["Mark where each tick of a channeled spell lands, such as Drain Life, Arcane Missiles or Blizzard."],
            true,
            "ticks"
        ),
        checkbox(
            L["Spell icon"],
            L["Show the spell icon beside the player cast bar when it is not locked to the player frame."],
            true,
            "icon"
        ),
        checkbox(L["Hold time"], L["How long a cast bar stays before it fades out."], false, "hold"),
        slider(L["After a finished cast"], "hold", "success", 0.2, 0, 3, 0.1),
        slider(L["After an interrupt"], "hold", "interrupt", 1, 0.1, 5, 0.1),
    }
end

local registered = false

-- Called once from OnEnable; the client's cast bar system must exist.
function app.RegisterEditMode()
    if registered or not (Enum.EditModeSystem and Enum.EditModeSystem.CastBar) then
        return
    end
    registered = true
    lib:AddSystemSettings(Enum.EditModeSystem.CastBar, app.EditModeSettings())
end
