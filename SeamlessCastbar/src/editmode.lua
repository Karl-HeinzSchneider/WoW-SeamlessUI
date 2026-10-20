---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- The player cast bar's options under a collapsible Style header in the extended window below
-- the cast bar's own Edit Mode settings (SeamlessUI draws it). They write the same profile as
-- the Player tab.

local function player()
    return app.db.profile.player
end

local function changed()
    app.addon:Refresh()
    app.core:RefreshOptions(appName)
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

local function formatTenths(value)
    return ("%.1f"):format(value)
end

---@param name string
---@param desc string?
---@param feature string? the profile table; nil for the bar's own switch
local function toggle(name, desc, feature)
    return {
        key = feature or "enabled",
        type = "toggle",
        name = name,
        desc = desc,
        get = function()
            return (feature and player()[feature] or player()).enabled
        end,
        set = function(value)
            (feature and player()[feature] or player()).enabled = value
            changed()
        end,
        disabled = feature and disabledUnless() or nil,
    }
end

---@param name string
---@param feature string
---@param key string
---@param min number
---@param max number
---@param step number
local function range(name, feature, key, min, max, step)
    return {
        key = feature .. "." .. key,
        type = "range",
        name = name,
        min = min,
        max = max,
        step = step,
        get = function()
            return player()[feature][key]
        end,
        set = function(value)
            player()[feature][key] = step < 1 and tenths(value) or value
            changed()
        end,
        format = step < 1 and formatTenths or nil,
        disabled = disabledUnless(feature),
    }
end

---@return SeamlessCore.EditModeSystemOption[] rows for the cast bar system
function app.EditModeSettings()
    local formats = {}
    for _, format in ipairs(app.castTimeFormatOrder) do
        formats[#formats + 1] = { text = app.castTimeFormats[format], value = format }
    end
    return {
        toggle(L["Enable"], L["Apply the Seamless options to this cast bar."]),
        toggle(
            L["Cast time"],
            L["Change how the player cast bar's cast time reads. Show it with Show Cast Time in the cast bar's Edit Mode settings."],
            "castTime"
        ),
        {
            key = "castTime.format",
            type = "select",
            name = L["Cast time format"],
            values = formats,
            get = function()
                return player().castTime.format
            end,
            set = function(value)
                player().castTime.format = value
                changed()
            end,
            disabled = disabledUnless("castTime"),
        },
        range(L["Decimals"], "castTime", "decimals", 0, 2, 1),
        toggle(
            L["Spell rank"],
            L["Add the spell's rank to its name on the cast bar, such as Frostbolt (Rank 3)."],
            "rank"
        ),
        toggle(
            L["Channel ticks"],
            L["Mark where each tick of a channeled spell lands, such as Drain Life, Arcane Missiles or Blizzard."],
            "ticks"
        ),
        toggle(
            L["Spell icon"],
            L["Show the spell icon beside the player cast bar when it is not locked to the player frame."],
            "icon"
        ),
        toggle(L["Hold time"], L["How long a cast bar stays before it fades out."], "hold"),
        range(L["After a finished cast"], "hold", "success", 0, 3, 0.1),
        range(L["After an interrupt"], "hold", "interrupt", 0.1, 5, 0.1),
    }
end

local registered = false

-- Called once from OnEnable; the client's cast bar system must exist.
function app.RegisterEditMode()
    if registered or not (Enum.EditModeSystem and Enum.EditModeSystem.CastBar) then
        return
    end
    registered = true
    app.core:RegisterEditModeSystemOptions(appName, {
        system = Enum.EditModeSystem.CastBar,
        name = L["Style"],
        key = "castbar-style",
        enabled = function()
            return app.addon:IsEnabled()
        end,
        options = app.EditModeSettings(),
    })
end
