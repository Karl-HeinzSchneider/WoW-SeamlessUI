-- Annotations only; not loaded by the TOC.
---@class SeamlessDarkmode
---@field core SeamlessCore.Addon
---@field addon SeamlessDarkmode.Addon
---@field db AceDBObject-3.0
---@field groups SeamlessDarkmode.Group[]

---@class SeamlessDarkmode.Group
---@field key string
---@field name string
---@field frames fun(paint: SeamlessDarkmode.Paint)[]

---@class SeamlessDarkmode.Addon : AceAddon, AceConsole-3.0
---@field Refresh fun(self: SeamlessDarkmode.Addon)
