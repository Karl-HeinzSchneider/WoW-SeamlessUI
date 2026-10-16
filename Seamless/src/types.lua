-- Annotations only; not loaded by the client.
---@class SeamlessCore
---@field logger SeamlessCore.Logger
---@field addon SeamlessCore.Addon
---@field dbDefaults AceDB.Schema
---@field db SeamlessCore.DB
---@field options SeamlessCore.Options
---@field minimapButton SeamlessCore.MinimapButton
---@field tweaks SeamlessCore.Tweaks

---@class SeamlessCore.Addon
---@field logger SeamlessCore.Logger
---@field FeatureGroup fun(spec: SeamlessCore.FeatureSpec): table

---@class SeamlessCore.DB : AceDBObject-3.0
---@field profile SeamlessCore.Profile

---@class SeamlessCore.Profile
---@field logLevel string
---@field minimap table
---@field tweaks { reloadShortcut: boolean, showFramerateOnStartup: boolean, questXPTooltip: boolean }
