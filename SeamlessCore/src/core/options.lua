---@type string, SeamlessCore
local appName, app = ...

---@class SeamlessCore.Options : AceModule
---@field root? SeamlessCore.SettingsPanel
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessCore.Options]]

---@param name string
---@param title string
---@param build fun(panel: SeamlessCore.SettingsPanel)
function module:RegisterAddon(name, title, build)
    assert(self.root, "SeamlessCore settings must initialize before feature settings")
    local panel = app.settings:CreatePanel(name, title, self.root)
    build(panel)
    return panel
end

function module:OnInitialize()
    local panel = app.settings:CreatePanel(appName, "Seamless")
    self.root = panel
    panel:Checkbox({
        id = "minimap",
        name = "Show minimap button",
        tooltip = "Open Seamless settings from the minimap.",
        default = not app.dbDefaults.profile.minimap.hide,
        get = function()
            return not app.db.profile.minimap.hide
        end,
        set = function(value)
            app.db.profile.minimap.hide = not value
            app.minimapButton:OnProfileRefresh()
        end,
    })
    local levels = {}
    for name in pairs(app.logger.level) do
        levels[#levels + 1] = { name, name:sub(1, 1) .. name:sub(2):lower() }
    end
    table.sort(levels, function(a, b)
        return app.logger.level[a[1]] < app.logger.level[b[1]]
    end)
    panel:Dropdown({
        id = "logLevel",
        name = "Log level",
        tooltip = "How much Seamless writes to chat. Also available through /seamless loglevel <level>.",
        default = app.dbDefaults.profile.logLevel,
        get = function()
            return app.db.profile.logLevel
        end,
        set = function(value)
            if app.logger:setLevel(value) then
                app.db.profile.logLevel = value
            end
        end,
        options = levels,
    })
    panel:Profiles(app.db)
end

function module:Open(name)
    local panel = app.settings.panels[name or appName]
    if panel then
        panel:Open()
    end
end

function module:Refresh(name)
    local panel = app.settings.panels[name or appName]
    if panel then
        panel:Refresh()
    end
end

function module:OnProfileRefresh()
    self:Refresh()
end
