---@type string, SeamlessChat
local _, app = ...

local addon = app.addon

-- Optional features the user switches on and off. A feature is an Ace module made with
-- `app.features:New`, one file in src/features/. Its settings live in `profile.features[key]`, where
-- `enabled` is the switch, and `options.lua` gives it a section on its `optionsTab` with that switch on
-- top plus the feature's own `GetOptions()`.
--
-- A disabled feature stays loaded but Ace calls its OnDisable, so a feature undoes in OnDisable
-- whatever OnEnable changed. Hooks that can't be removed check `self:IsEnabled()` instead.

---@class SeamlessChat.Features
---@field list SeamlessChat.Feature[] in registration order (the TOC order)
local features = { list = {} }
app.features = features

---@alias SeamlessChat.OptionsTab "messages"|"windows"|"buttons"|"log"

---@class SeamlessChat.FeatureSettings
---@field enabled boolean

-- Methods every feature gets; a feature may override any of them.
---@class SeamlessChat.Feature : AceModule
---@field featureKey string key in profile.features and the module name
---@field featureName string title in the options
---@field featureDesc string one sentence for the options
---@field optionsTab SeamlessChat.OptionsTab the options tab its section is on
local featureMixin = {}

---@return SeamlessChat.FeatureSettings
function featureMixin:GetSettings()
    return app.db.profile.features[self.featureKey]
end

-- AceConfig args for the feature's own settings, shown below its on/off switch. Their get/set default
-- to the feature's settings table (the arg key is the settings key), then call Refresh.
---@return table<string, table>
function featureMixin:GetOptions()
    return {}
end

-- Re-applies the feature's settings while it is enabled, after one of them changed.
function featureMixin:Refresh() end

-- The profile was switched, copied or reset, or the switch was flipped: enable or disable to match.
-- Works before login too, when Ace only records the state and enables the module at PLAYER_LOGIN.
function featureMixin:OnProfileRefresh()
    if self:GetSettings().enabled then
        -- Ace enables modules at PLAYER_LOGIN; before that nothing is set up to refresh.
        local running = self:IsEnabled() and IsLoggedIn()
        self:Enable()
        if running then
            self:Refresh()
        end
    else
        self:Disable()
    end
end

-- Registers a feature. `prototype` holds its methods (OnEnable, OnDisable, GetOptions, Refresh...),
-- Settings defaults live in src/core/db.lua; the remaining arguments are Ace libraries to embed.
---@generic T
---@param key string
---@param prototype T
---@param name string
---@param desc string
---@return T
function features:New(key, prototype, name, desc, ...)
    setmetatable(prototype, { __index = featureMixin })
    prototype.featureKey = key
    prototype.featureName = name
    prototype.featureDesc = desc
    assert(app.dbDefaults.profile.features[key], "Missing feature defaults: " .. key)

    local module = addon:NewModule(key, prototype, ...) --[[@as SeamlessChat.Feature]]
    self.list[#self.list + 1] = module
    return module
end
