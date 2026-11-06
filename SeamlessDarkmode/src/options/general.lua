---@type string, SeamlessDarkmode
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local defaultColor = { r = 0.22, g = 0.22, b = 0.22 }

local function masterOff()
    return not app.db.profile.enabled
end

---@type SeamlessCore.SettingsPage
app.optionPages.general = {
    tooltip = function(path)
        return app.core:GetOptionDefault(app.dbDefaults.profile, path, 2)
    end,
    defaults = {
        profile = {
            enabled = true,
            color = defaultColor,
            groups = {
                unitframes = true,
                minimap = true,
                actionbars = true,
                endcaps = true,
                experience = true,
                reputation = true,
            },
            colors = { ["*"] = { enabled = false } },
        },
    },
    config = {
        type = "group",
        name = L["General"],
        order = 0,
        args = {
            enabled = {
                type = "toggle",
                order = 1,
                name = L["Enable darkmode"],
                width = "full",
                get = function()
                    return app.db.profile.enabled
                end,
                set = function(_, value)
                    app.db.profile.enabled = value
                    app.addon:Refresh()
                    app.core:RefreshEditModeOptions()
                end,
            },
            color = {
                type = "color",
                order = 2,
                name = L["Darkmode color"],
                hasAlpha = false,
                desc = L["Tint for enabled parts in sections that use the shared color."],
                disabled = masterOff,
                get = function()
                    local color = app.db.profile.color
                    return color.r, color.g, color.b
                end,
                set = function(_, r, g, b)
                    app.db.profile.color = { r = r, g = g, b = b }
                    app.addon:Refresh()
                end,
            },
        },
    },
}

for index, category in ipairs(app.categories) do
    local key = category.key
    local args = {
        customColor = {
            type = "toggle",
            order = 1,
            name = L["Use custom color"],
            desc = L["Set a separate tint for all enabled parts in this section."],
            default = false,
            get = function()
                return app.db.profile.colors[key].enabled
            end,
            set = function(_, value)
                local profile = app.db.profile
                local override = profile.colors[key]
                if value and not override.color then
                    local color = profile.color
                    override.color = { r = color.r, g = color.g, b = color.b }
                end
                override.enabled = value
                app.addon:Refresh()
            end,
        },
        color = {
            type = "color",
            order = 2,
            name = L["Color"],
            hasAlpha = false,
            default = defaultColor,
            hidden = function()
                return not app.db.profile.colors[key].enabled
            end,
            get = function()
                local profile = app.db.profile
                local color = profile.colors[key].color or profile.color
                return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
                app.db.profile.colors[key].color = { r = r, g = g, b = b }
                app.addon:Refresh()
            end,
        },
    }
    for partIndex, part in ipairs(category.parts) do
        args[part.key] = {
            type = "toggle",
            order = 2 + partIndex,
            name = part.name,
            default = true,
            get = function()
                return app.IsPartEnabled(category, part)
            end,
            set = function(_, value)
                app.db.profile.groups[part.key] = value
                app.addon:Refresh()
            end,
        }
    end
    app.optionPages.general.config.args[key] = {
        type = "group",
        inline = true,
        order = 10 + index,
        name = category.name,
        disabled = masterOff,
        args = args,
    }
end
