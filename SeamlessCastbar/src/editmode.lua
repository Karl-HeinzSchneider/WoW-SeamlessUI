---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Each cast bar's options under a collapsible Style header in Edit Mode, writing the same profile
-- as its tab. The player bar is the client's own Edit Mode system: its Style section sits in the
-- extended window below the cast bar's settings (SeamlessUI draws it). Target and focus bars have
-- no system of their own; their previews (preview.lua) show the same rows in LibEditMode's dialog.

local lib = app.core:GetEditModeLibrary()

local function changed()
    app.addon:Refresh()
    app.core:RefreshOptions(appName)
end

-- Slider steps of 0.1 arrive as 0.30000000000000004.
local function tenths(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function formatTenths(value)
    return ("%.1f"):format(value)
end

---The Style rows of one bar, as Core's Edit Mode system options (with defaults for Reset).
---@param key "player"|"target"|"focus"
---@return SeamlessCore.EditModeSystemOption[]
function app.StyleOptions(key)
    local function bar()
        return app.db.profile[key]
    end
    -- Greyed out while the bar or, when given, the feature is switched off.
    local function disabledUnless(feature)
        return function()
            return not bar().enabled or (feature ~= nil and not bar()[feature].enabled)
        end
    end
    local function toggle(name, desc, feature, default)
        return {
            key = feature or "enabled",
            type = "toggle",
            name = name,
            desc = desc,
            default = default,
            get = function()
                return (feature and bar()[feature] or bar()).enabled
            end,
            set = function(value)
                (feature and bar()[feature] or bar()).enabled = value
                changed()
            end,
            disabled = feature and disabledUnless() or nil,
        }
    end
    local function range(name, feature, field, min, max, step, default)
        return {
            key = feature .. "." .. field,
            type = "range",
            name = name,
            min = min,
            max = max,
            step = step,
            default = default,
            get = function()
                return bar()[feature][field]
            end,
            set = function(value)
                bar()[feature][field] = step < 1 and tenths(value) or value
                changed()
            end,
            format = step < 1 and formatTenths or nil,
            disabled = disabledUnless(feature),
        }
    end
    local formats = {}
    for _, format in ipairs(app.castTimeFormatOrder) do
        formats[#formats + 1] = { text = app.castTimeFormats[format], value = format }
    end
    local rows = {
        toggle(L["Enable"], L["Apply the Seamless options to this cast bar."], nil, true),
        toggle(
            L["Cast time"],
            key == "player"
                    and L["Change how the player cast bar's cast time reads. Show it with Show Cast Time in the cast bar's Edit Mode settings."]
                or L["Show the cast time to the right of the cast bar."],
            "castTime",
            true
        ),
        {
            key = "castTime.format",
            type = "select",
            name = L["Cast time format"],
            values = formats,
            default = "ELAPSED_TOTAL",
            get = function()
                return bar().castTime.format
            end,
            set = function(value)
                bar().castTime.format = value
                changed()
            end,
            disabled = disabledUnless("castTime"),
        },
        range(L["Decimals"], "castTime", "decimals", 0, 2, 1, 1),
        toggle(
            L["Spell rank"],
            L["Add the spell's rank to its name on the cast bar, such as Frostbolt (Rank 3)."],
            "rank",
            true
        ),
        toggle(
            L["Channel ticks"],
            L["Mark where each tick of a channeled spell lands, such as Drain Life, Arcane Missiles or Blizzard."],
            "ticks",
            true
        ),
    }
    if key == "player" then
        rows[#rows + 1] = toggle(
            L["Spell icon"],
            L["Show the spell icon beside the player cast bar when it is not locked to the player frame."],
            "icon",
            true
        )
    end
    rows[#rows + 1] = toggle(L["Hold time"], L["How long a cast bar stays before it fades out."], "hold", false)
    rows[#rows + 1] = range(L["After a finished cast"], "hold", "success", 0, 3, 0.1, 0.2)
    rows[#rows + 1] = range(L["After an interrupt"], "hold", "interrupt", 0.1, 5, 0.1, 1)
    return rows
end

---The player bar's Style rows.
---@return SeamlessCore.EditModeSystemOption[]
function app.EditModeSettings()
    return app.StyleOptions("player")
end

local kinds = { toggle = "Checkbox", select = "Dropdown", range = "Slider" }

---A bar's Style section as LibEditMode settings, for its preview's dialog.
---@param key "target"|"focus"
---@return table[]
function app.LibEditModeSettings(key)
    local settings = { { kind = lib.SettingType.Header, name = L["Style"], key = "castbar-style" } }
    for _, row in ipairs(app.StyleOptions(key)) do
        settings[#settings + 1] = {
            kind = lib.SettingType[kinds[row.type]],
            name = row.name,
            desc = row.desc,
            default = row.default,
            values = row.values,
            minValue = row.min,
            maxValue = row.max,
            valueStep = row.step,
            formatter = row.format or tostring,
            get = function()
                return row.get()
            end,
            set = function(_, value)
                row.set(value)
                lib:RefreshFrameSettings(app.PreviewFrame(key))
            end,
            disabled = row.disabled,
        }
    end
    return settings
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
        source = { addon = appName, path = { "player" } },
        options = app.EditModeSettings(),
    })
end
