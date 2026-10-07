---@type string, SeamlessTooltip
local _, app = ...

local addon = app.addon

-- Every tooltip enhancement is a feature: one self-contained file in src\features\ that declares
-- its defaults, its options and its code through NewFeature, and that the options switch on and
-- off. Features are nested Ace modules of this one, so Ace calls their OnEnable/OnDisable and
-- AceEvent/AceHook drop their events and hooks while they are off.
---@class SeamlessTooltip.Features : AceModule, AceAddon
local module = {}
app.features = addon:NewModule("Features", module) --[[@as SeamlessTooltip.Features]]

---@alias SeamlessTooltip.FeatureCategory "all"|"units"|"items"|"spells"

-- The options sections features are sorted into, by FeatureInfo.category: by the tooltips they
-- change.
---@type table<SeamlessTooltip.FeatureCategory, { name: string, order: integer }>
local CATEGORIES = {
    all = { name = "All tooltips", order = 10 },
    units = { name = "Units", order = 20 },
    items = { name = "Items", order = 30 },
    spells = { name = "Spells", order = 40 },
}

---@class SeamlessTooltip.FeatureInfo
---@field category SeamlessTooltip.FeatureCategory The options section it is listed in.
---@field name string The feature's heading in the options.
---@field desc string One line on what it adds to the tooltip, shown under the heading.
---@field order? integer Position among its category's features (default 100).
---@field enabled? boolean Whether it is on in a new profile (default true).
---@field defaults? table Profile defaults of the feature's own settings.
---@field options? table<string, table> Declarative native control definitions; each key is the setting it stores in `defaults`.

-- Set once the features are enabled (PLAYER_LOGIN); before that, profile refreshes only set the
-- state Ace enables them with.
local started = false

-- Methods every feature gets; a feature file adds its own (OnInitialize, OnEnable, ...) on the
-- object NewFeature returns.
---@class SeamlessTooltip.Feature : AceModule, AceAddon, AceEvent-3.0, AceHook-3.0
---@field info SeamlessTooltip.FeatureInfo
---@field ApplySettings? fun(self: SeamlessTooltip.Feature) Re-applies settings that are not read at tooltip time.
local prototype = {}

-- The feature's settings in the current profile. Read them where they are used (at tooltip time)
-- instead of caching them, so option changes and profile switches apply without a refresh. A
-- feature that has to apply them up front (a frame's look) defines ApplySettings instead.
function prototype:Settings()
    return app.db.profile.features[self.moduleName]
end

-- TooltipDataProcessor callbacks. The processor cannot remove one, so register them once (from
-- OnInitialize); `self[method]` is only called while the feature is enabled. The tooltip shows
-- itself after the post-calls, so added lines need no tooltip:Show().
---@param method string
---@return function
function prototype:WhileEnabled(method)
    return function(tooltip, ...)
        -- A forbidden tooltip (the target/focus frames' aura tooltip) must not be touched.
        if self:IsEnabled() and not tooltip:IsForbidden() then
            return self[method](self, tooltip, ...)
        end
    end
end

-- `self[method](self, tooltip, tooltipData)` after a tooltip of one Enum.TooltipDataType was
-- filled; tooltipData.id is the item/spell/... id.
---@param dataType Enum.TooltipDataType
---@param method string
function prototype:AddTooltipPostCall(dataType, method)
    TooltipDataProcessor.AddTooltipPostCall(dataType, self:WhileEnabled(method))
end

-- `self[method](self, tooltip, lineData)` before a line of one Enum.TooltipDataLineType (or
-- TooltipDataProcessor.AllTypes) is added; returning true drops the line. While the lines are
-- processed, tooltip:GetProcessingTooltipInfo().tooltipData.type is the tooltip's type.
---@param lineType Enum.TooltipDataLineType|string
---@param method string
function prototype:AddLinePreCall(lineType, method)
    TooltipDataProcessor.AddLinePreCall(lineType, self:WhileEnabled(method))
end

-- `self[method](self, tooltip, lineData)` after a line was added; lineData.lineIndex is its
-- line number (the tooltip's TextLeft<n>/TextRight<n> font strings).
---@param lineType Enum.TooltipDataLineType|string
---@param method string
function prototype:AddLinePostCall(lineType, method)
    TooltipDataProcessor.AddLinePostCall(lineType, self:WhileEnabled(method))
end

-- True if any argument is a secret value, which addon code must not compare, compute with or
-- pass to APIs that refuse secrets (health, aura data, unit identity in restricted content).
---@param ... any
---@return boolean
function module.AnySecret(...)
    if not issecretvalue then
        return false
    end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then
            return true
        end
    end
    return false
end

-- The link of the item an item tooltip's data is about (with its upgrades, enchants, ...), like
-- TooltipUtil.GetDisplayedItem but from the data a post-call gets. Nil when it is secret.
---@param tooltipData table
---@return string?
function module.ItemLink(tooltipData)
    local link
    if tooltipData.guid then
        link = C_Item.GetItemLinkByGUID(tooltipData.guid)
    else
        link = tooltipData.hyperlink
    end
    if link and not module.AnySecret(link) then
        return link
    end
end

-- Calls the feature's ApplySettings while it runs: after one of its options or the profile changed.
-- Its OnEnable applies the settings when it is switched on.
function prototype:SettingsChanged()
    if started and self:IsEnabled() and self.ApplySettings then
        self:ApplySettings()
    end
end

-- Switches the feature on or off to match the profile. Both are no-ops in the state it is in, and
-- before PLAYER_LOGIN they only set the state Ace enables it with.
function prototype:Refresh()
    if self:Settings().enabled then
        self:Enable()
        self:SettingsChanged()
    else
        self:Disable()
    end
end

-- Declares a feature. `key` is its module name and its settings' key under profile.features, so
-- renaming it drops the users' saved settings. Call at file load, before AceDB reads the defaults.
---@param key string
---@param info SeamlessTooltip.FeatureInfo
---@return SeamlessTooltip.Feature
function module:NewFeature(key, info)
    if not CATEGORIES[info.category] then
        error(("Feature %s: unknown category %s"):format(key, tostring(info.category)), 2)
    end

    local defaults = info.defaults or {}
    defaults.enabled = info.enabled ~= false
    app.dbDefaults.profile.features[key] = defaults

    local feature = self:NewModule(key, prototype, "AceEvent-3.0", "AceHook-3.0") --[[@as SeamlessTooltip.Feature]]
    feature.info = info
    return feature
end

-- Runs before Ace enables the features themselves.
function module:OnEnable()
    started = true
end

-- The addon's first call runs in its OnInitialize, before any feature's OnInitialize.
function module:OnProfileRefresh()
    for _, feature in self:IterateModules() do
        feature:Refresh()
    end
end

-- Stable category/feature ordering, with one native toggle and the shared option adapter per feature.
---@param panel SeamlessCore.SettingsPanel
function module:RegisterSettings(panel)
    local features = {}
    for _, feature in self:IterateModules() do
        features[#features + 1] = feature
    end
    table.sort(features, function(a, b)
        local first, second = CATEGORIES[a.info.category].order, CATEGORIES[b.info.category].order
        if first ~= second then
            return first < second
        end
        first, second = a.info.order or 100, b.info.order or 100
        return first == second and a.moduleName < b.moduleName or first < second
    end)
    local previousCategory
    for _, feature in ipairs(features) do
        local info, key = feature.info, feature.moduleName
        if previousCategory ~= info.category then
            panel:Header(CATEGORIES[info.category].name)
            previousCategory = info.category
        end
        local prefix = "features." .. key
        local enabledID = prefix .. ".enabled"
        panel:Checkbox({
            id = enabledID,
            name = info.name,
            tooltip = info.desc,
            default = app.dbDefaults.profile.features[key].enabled,
            get = function()
                return feature:Settings().enabled
            end,
            set = function(value)
                feature:Settings().enabled = value
                feature:Refresh()
            end,
            tags = { CATEGORIES[info.category].name },
        })
        panel:Options({
            id = prefix,
            name = info.name,
            defaults = app.dbDefaults.profile.features[key],
            options = info.options or {},
            get = function()
                return feature:Settings()
            end,
            changed = function()
                feature:SettingsChanged()
            end,
            enabled = function()
                return feature:Settings().enabled
            end,
            dependencies = { enabledID },
            tags = { CATEGORIES[info.category].name, info.name },
        })
    end
end
