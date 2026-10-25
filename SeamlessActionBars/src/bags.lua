---@type string, SeamlessActionBars
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")
local module = app.addon:NewModule("Bags")

function module:OnInitialize()
    if not Enum.EditModeSystem or not Enum.EditModeSystem.Bags then
        return
    end
    local args = app.optionPages.bags.config.args.layout.args
    local rows = {}
    for _, key in ipairs({ "orientation", "direction" }) do
        local option = args[key]
        if option then
            local row = {
                key = key,
                type = option.type,
                name = option.name,
                default = option.default,
                disabled = option.disabled,
                get = option.get,
                set = function(value)
                    option.set(nil, value)
                end,
                min = option.min,
                max = option.max,
                step = option.step,
                format = option.format,
            }
            if option.type == "select" then
                row.values = function()
                    local values = type(option.values) == "function" and option.values() or option.values
                    local entries = {}
                    for value, text in pairs(values) do
                        entries[#entries + 1] = { value = value, text = text }
                    end
                    table.sort(entries, function(a, b)
                        return a.value < b.value
                    end)
                    return entries
                end
            end
            rows[#rows + 1] = row
        end
    end
    app.core:RegisterEditModeSystemOptions("SeamlessActionBars:bags", {
        system = Enum.EditModeSystem.Bags,
        name = L["Style"],
        key = "SeamlessActionBars:bags:style",
        enabled = function()
            return module:IsEnabled() and app.addon:IsEnabled()
        end,
        options = rows,
    })
end

function module:OnEnable()
    app.core:RefreshEditModeSystemOptions()
end

function module:OnDisable()
    app.core:RefreshEditModeSystemOptions()
end
