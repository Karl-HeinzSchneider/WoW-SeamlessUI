---@type string, SeamlessDamageMeter
local appName, app = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

app.skinDefaults = {
    windowAlpha = 1,
    showIcons = true,
    font = "Default damage meter",
    fontSize = 15,
    fontFlags = "",
    textColor = { 1, 1, 1, 1 },
    barColor = { 0.35, 0.6, 0.8, 1 },
    classColors = true,
    hideTypeSelector = false,
    hideCombatTimer = false,
    backgroundColor = { 1, 1, 1, 0.5 },
    headerColor = { 1, 1, 1, 1 },
    rowHeight = 24,
    rowSpacing = 4,
}
function app:BuildSkinOptions()
    if not self.skinOptions then
        return
    end
    local args = {}
    local keys = {}
    for key in pairs(self.db.profile.skins) do
        if key ~= "default" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    table.insert(keys, 1, "default")
    for index, key in ipairs(keys) do
        local skin = self.db.profile.skins[key]
        local controls = {
            info = {
                type = "description",
                order = 0,
                name = L["Appearance settings apply to every window using this skin. New skins start with a copy of Default."],
            },
        }
        for order, definition in ipairs(app.meterSettingDefinitions) do
            if self.skinDefaults[definition.key] ~= nil then
                controls[definition.key] = app.MeterSettingControl(definition, nil, nil, skin)
                controls[definition.key].order = order * 10
            end
        end
        if key ~= "default" then
            controls.remove = {
                type = "execute",
                name = L["Delete skin"],
                order = 1,
                confirm = L["Delete the skin %s? Windows using it switch to Default."]:format(skin.name),
                func = function()
                    self:RemoveSkin(key)
                end,
            }
        end
        args[key] = { type = "group", name = skin.name, order = index, args = controls }
    end
    args.add = {
        type = "group",
        name = L["Add skin"],
        order = 10000,
        args = {
            name = {
                type = "input",
                name = L["Skin name"],
                order = 1,
                width = "full",
                get = function()
                    return self.newSkinName or ""
                end,
                set = function(_, value)
                    self.newSkinName = value
                end,
            },
            create = {
                type = "execute",
                name = L["Add skin"],
                order = 2,
                disabled = function()
                    return not self.newSkinName or not self.newSkinName:match("%S")
                end,
                func = function()
                    self:AddSkin(self.newSkinName or "")
                    self.newSkinName = nil
                end,
            },
        },
    }
    self.skinOptions.args = args
end

---@type SeamlessCore.SettingsPage
app.optionPages.skin = {
    tooltip = function(path)
        local key = path[#path]
        if key == "name" then
            return ""
        end
        return app.skinDefaults[key]
    end,
    defaults = {},
    config = {
        type = "group",
        name = L["Skin"],
        order = 50,
        args = {},
    },
}
