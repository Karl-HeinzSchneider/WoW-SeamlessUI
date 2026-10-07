---@type string, SeamlessCore
local _, app = ...

---@class SeamlessCore.Settings
---@field panels table<string, SeamlessCore.SettingsPanel>
local settings = { panels = {} }
app.settings = settings

---@class SeamlessCore.SettingSpec
---@field id string # Unique within this addon's panel.
---@field name string
---@field tooltip? string
---@field default? boolean|string|number # Nil excludes actions such as profile selection from Defaults.
---@field get fun(): boolean|string|number
---@field set fun(value: any)
---@field options? table[]|fun(): table[] # Ordered { value, label, tooltip? } choices.
---@field variableType? string # Dropdowns default to string.
---@field shown? fun(): boolean
---@field tags? string[]

---@class SeamlessCore.SettingsPanel
---@field name string
---@field title string
---@field category table
---@field layout table
---@field settings table<string, table>
local Panel = {}
Panel.__index = Panel
settings.Panel = Panel

---@param name string
---@param title string
---@param parent? SeamlessCore.SettingsPanel
---@return SeamlessCore.SettingsPanel
function settings:CreatePanel(name, title, parent)
    assert(not self.panels[name], "Duplicate Seamless settings panel: " .. name)
    local category, layout
    if parent then
        category, layout = Settings.RegisterVerticalLayoutSubcategory(parent.category, title)
    else
        category, layout = Settings.RegisterVerticalLayoutCategory(title)
        Settings.RegisterAddOnCategory(category)
    end
    local panel =
        setmetatable({ name = name, title = title, category = category, layout = layout, settings = {} }, Panel)
    self.panels[name] = panel
    return panel
end

-- Proxy accessors read the current profile each time; never capture db.profile in a control.
---@param spec SeamlessCore.SettingSpec
---@param variableType string
function Panel:RegisterSetting(spec, variableType)
    assert(not self.settings[spec.id], "Duplicate Seamless setting: " .. spec.id)
    local setting = Settings.RegisterProxySetting(
        self.category,
        self.name .. "." .. spec.id,
        variableType,
        spec.name,
        spec.default,
        spec.get,
        spec.set
    )
    self.settings[spec.id] = setting
    return setting
end

function Panel:Configure(initializer, spec)
    initializer:AddSearchTags("Seamless", self.title)
    if spec.tags then
        initializer:AddSearchTags(unpack(spec.tags))
    end
    if spec.shown then
        initializer:AddShownPredicate(spec.shown)
    end
    return initializer
end

---@param spec SeamlessCore.SettingSpec
function Panel:Checkbox(spec)
    local setting = self:RegisterSetting(spec, Settings.VarType.Boolean)
    return self:Configure(Settings.CreateCheckbox(self.category, setting, spec.tooltip), spec)
end

---@param spec SeamlessCore.SettingSpec
function Panel:Dropdown(spec)
    local setting = self:RegisterSetting(spec, spec.variableType or Settings.VarType.String)
    local function choices()
        local container = Settings.CreateControlTextContainer()
        local options = type(spec.options) == "function" and spec.options() or spec.options
        for _, option in ipairs(options) do
            container:Add(option[1], option[2], option[3])
        end
        return container:GetData()
    end
    return self:Configure(Settings.CreateDropdown(self.category, setting, choices, spec.tooltip), spec)
end

---@param name string
---@param buttonText string
---@param callback function
---@param tooltip? string
function Panel:Button(name, buttonText, callback, tooltip)
    local initializer = CreateSettingsButtonInitializer(name, buttonText, callback, tooltip, true)
    self.layout:AddInitializer(initializer)
    return self:Configure(initializer, {})
end

function Panel:Header(name)
    self.layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
end

function Panel:Refresh()
    for _, setting in pairs(self.settings) do
        setting:NotifyUpdate()
    end
end

function Panel:Open()
    Settings.OpenToCategory(self.category:GetID())
end
