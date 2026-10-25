---@type string, SeamlessCastbar
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

-- Each cast bar's options under a collapsible Style header in Edit Mode, writing the same profile
-- as its tab. The player bar is the client's own Edit Mode system: its Style section sits in the
-- extended window below the cast bar's settings (SeamlessUI draws it). Target and focus bars have
-- no system of their own; their previews (preview.lua) show the same rows in LibEditMode's dialog.

local lib = app.core:GetEditModeLibrary()

---The page declaration is also the source for Edit Mode's Style rows.
function app.StyleOptions(key)
    local config = app.optionPages[key].config
    local root = { type = "group", args = { [key] = config } }
    local rows = {}
    local function visit(option)
        local kind = option:Read("type")
        if kind == "group" then
            for _, child in ipairs(option:Children()) do
                visit(child)
            end
        elseif kind == "toggle" or kind == "select" or kind == "range" then
            local path = option.path
            local id = path[2]
            if #path > 2 and path[3] ~= "enabled" then
                id = id .. "." .. path[3]
            end
            local row = {
                key = id,
                type = kind,
                name = path[3] == "enabled" and config.args[path[2]].name or option:Read("name"),
                desc = option:Read("desc"),
                get = function()
                    return option:Read("get")
                end,
                set = function(value)
                    if kind == "range" then
                        value = tonumber(("%.10g"):format(value))
                    end
                    option:Read("set", value)
                    app.core:RefreshOptions(appName)
                end,
                disabled = option:Read("disabled") ~= nil and function()
                    return option:Read("disabled")
                end or nil,
                default = function()
                    return app.optionPages[key].tooltip(path)
                end,
            }
            if kind == "select" then
                row.values = {}
                for _, choice in ipairs(option:Choices()) do
                    row.values[#row.values + 1] = { text = choice.text, value = choice.value }
                end
            elseif kind == "range" then
                row.min, row.max, row.step = option:Read("min"), option:Read("max"), option:Read("step")
                row.format = row.step < 1
                        and function(value)
                            return ("%.1f"):format(value)
                        end
                    or tostring
            end
            rows[#rows + 1] = row
        end
    end
    for _, option in ipairs(app.core:GetSettingsOption(root, { key }, appName):Children()) do
        if option.path[2] ~= "position" then
            visit(option)
        end
    end
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
        local default = row.default
        if type(default) == "function" then
            default = default()
        end
        settings[#settings + 1] = {
            kind = lib.SettingType[kinds[row.type]],
            name = row.name,
            desc = row.desc,
            default = default,
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
        options = app.EditModeSettings(),
    })
end
