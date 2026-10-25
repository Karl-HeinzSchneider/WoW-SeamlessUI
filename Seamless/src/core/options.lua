---@type string, SeamlessCore
local appName, app = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")

local AceDBOptions = LibStub("AceDBOptions-3.0")

-- One addon header with explicit pages. Seamless owns the settings schema and rendering.
local PROFILE_EVENTS = { "OnProfileChanged", "OnProfileCopied", "OnProfileReset", "OnProfileDeleted", "OnNewProfile" }

---@class SeamlessCore.OptionsSpec
---@field title string The addon's navigation heading.
---@field pages table<string, SeamlessCore.SettingsPage> One named page per file in src/options/.
---@field new? boolean Tag the addon's category header.
---@field blizzard? boolean Tag the addon's category header.
---@field editMode? boolean Tag the addon's category header.

---@class SeamlessCore.OptionsPanel
---@field title string
---@field options table The settings tree, with all Seamless metadata retained.

---@class SeamlessCore.Options : AceModule
---@field panels table<string, SeamlessCore.OptionsPanel>
---@field addons string[] Feature addons with a panel, in registration order.
---@field addonButtons table<string, table> Args of the Addons group on Core's General tab.
local module = {}
app.options = app.addon:NewModule("Options", module) --[[@as SeamlessCore.Options]]

-- Keep stable paths for inherited accessors and AceDBOptions handler methods.
local function RegisterConfigPages(name, title, args, flags, root)
    local parent = name
    if name == appName then
        app.config.categories[name].new = flags.new
        app.config.categories[name].blizzard = flags.blizzard
        app.config.categories[name].editMode = flags.editMode
    end
    if name ~= appName then
        app.addon:RegisterConfigCategory(
            name,
            { name = title, header = true, new = flags.new, blizzard = flags.blizzard, editMode = flags.editMode }
        )
    end
    for key, tab in pairs(args) do
        local id = name .. ":" .. key
        local spec = {
            name = tab.name,
            parent = parent,
            order = tab.order,
            hidden = tab.hidden,
            new = tab.new,
            blizzard = tab.blizzard,
            editMode = tab.editMode,
            editModeVisibility = tab.editModeVisibility,
            create = function(page)
                app.config:CreateOptionsPage(page, root, key, name)
                page.optionsAppName = name
                page:SetScript("OnUpdate", function()
                    if page.optionsDirty then
                        page.optionsDirty = false
                        app.config:RefreshOptionsPage(page)
                    end
                end)
            end,
            refresh = function(page)
                app.config:RefreshOptionsPage(page)
            end,
        }
        if app.config.categories[id] then
            -- Core's initial General placeholder is selected before initialization.
            local existing = app.config.categories[id]
            if spec.new == nil then
                spec.new = existing.new
            end
            if spec.blizzard == nil then
                spec.blizzard = existing.blizzard
            end
            if spec.editMode == nil then
                spec.editMode = existing.editMode
            end
            app.config.categories[id] = spec
            spec.id = id
        else
            app.addon:RegisterConfigCategory(id, spec)
        end
    end
end

---@param name string The addon folder name.
---@param spec SeamlessCore.OptionsSpec
function module:Register(name, spec)
    assert(not self.panels[name], "Duplicate Seamless options: " .. name)
    app.config.optionInfo[name] = function(path)
        local page = spec.pages[path[1]]
        if page and page.tooltip then
            return page.tooltip(path)
        end
        return page and app.addon:GetOptionDefault(page.defaults.profile, path)
    end
    local args = {}
    for key, page in pairs(spec.pages) do
        assert(page.config.type == "group", "Settings page must be a group: " .. key)
        app.addon:PrepareSettingsOptions(page.config)
        args[key] = page.config
    end
    -- All panels redraw when the shared profile changes, including those without a Profiles tab.
    for _, event in ipairs(PROFILE_EVENTS) do
        app.db.RegisterCallback(args, event, function()
            self:Refresh(name)
        end)
    end
    local root = { type = "group", name = spec.title, childGroups = "tab", args = args }
    self.panels[name] = { title = spec.title, options = root }
    RegisterConfigPages(name, spec.title, args, spec, root)
end

-- Opens the shared config window on the addon's General page or requested tab.
---@param name? string
---@param tab? string
function module:Open(name, tab)
    name = name or appName
    local panel = self.panels[name]
    if not panel then
        return
    end
    app.addon:OpenConfig(name .. ":" .. (tab or "general"))
end

-- Redraws `name`'s panel (Core's when nil) after a change made outside of it.
---@param name? string
function module:Refresh(name)
    app.config:NotifyChange(name or appName)
end

function module:OnInitialize()
    self.panels, self.addons = {}, {}
    self.addonButtons = app.optionPages.general.config.args.addons.args
    local profiles = AceDBOptions:GetOptionsTable(app.db)
    profiles.order = 1000
    app.optionPages.profiles.config = profiles
    self:Register(appName, { title = L["Seamless"], pages = app.optionPages })
end

-- A feature addon's panel, below Core's; its button joins Core's Addons list.
---@param name string
---@param spec SeamlessCore.OptionsSpec
function module:RegisterAddon(name, spec)
    assert(self.panels[appName], "Seamless core options must initialize before feature options")
    self:Register(name, spec)
    self.addons[#self.addons + 1] = name
    self.addonButtons[name] = {
        type = "execute",
        order = #self.addons,
        name = spec.title,
        func = function()
            self:Open(name)
        end,
    }
    self:Refresh()
end

---Read only a matching frame's explicit page declaration. No inferred default footer.
---@param frame table
---@return SeamlessCore.EditModeButtonSection?
function app.addon:GetEditModeFrameButtonSection(frame)
    if not frame then
        return nil
    end
    for _, panel in pairs(app.options.panels or {}) do
        for _, config in pairs(panel.options.args) do
            if config.editModeFrame and config.editModeFrame() == frame then
                return config.buttonSection
            end
        end
    end
end
