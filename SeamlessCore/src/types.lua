-- Annotations only; not loaded by the client.
---@class SeamlessCore
---@field logger SeamlessCore.Logger
---@field addon SeamlessCore.Addon
---@field dbDefaults AceDB.Schema
---@field db SeamlessCore.DB
---@field settings SeamlessCore.Settings
---@field options SeamlessCore.Options
---@field minimapButton SeamlessCore.MinimapButton

---@class SeamlessCore.Addon
---@field logger SeamlessCore.Logger

---@class SeamlessCore.DB : AceDBObject-3.0
---@field profile SeamlessCore.Profile

---@class SeamlessCore.Profile
---@field logLevel string
---@field minimap table
