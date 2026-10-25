---@type string, SeamlessChat
local _, app = ...

local addon = app.addon

-- Optional features the user switches on and off. A feature is an Ace module made with
-- `app.features:New`, one file in src/features/. Its settings live in `profile.features[key]`, where
-- `enabled` is the switch. Its page in src/options/ owns the settings declaration and defaults.
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
local featureMixin = {}

---@return SeamlessChat.FeatureSettings
function featureMixin:GetSettings()
    return app.db.profile.features[self.featureKey]
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

-- Registers a feature. `prototype` holds its methods (OnEnable, OnDisable, Refresh...),
-- Settings defaults live in src/options/; the remaining arguments are Ace libraries to embed.
---@generic T
---@param key string
---@param prototype T
---@return T
function features:New(key, prototype, ...)
    setmetatable(prototype, { __index = featureMixin })
    prototype.featureKey = key

    local module = addon:NewModule(key, prototype, ...) --[[@as SeamlessChat.Feature]]
    self.list[#self.list + 1] = module
    return module
end
