-- Annotations only; not loaded by the TOC.
---@class SeamlessDarkmode
---@field core SeamlessCore.Addon
---@field addon SeamlessDarkmode.Addon
---@field db AceDBObject-3.0
---@field groups SeamlessDarkmode.Group[]
---@field StatusTrackingBars fun(experience: SeamlessDarkmode.Paint, reputation: SeamlessDarkmode.Paint, restore: SeamlessDarkmode.Paint)
---@field MinimapButtonBorders fun(paint: SeamlessDarkmode.Paint, active: boolean)

---@class SeamlessDarkmode.Group
---@field key string
---@field name string
---@field frames fun(paint: SeamlessDarkmode.Paint)[]

---@class SeamlessDarkmode.Addon : AceAddon, AceConsole-3.0, AceEvent-3.0, AceHook-3.0
---@field Refresh fun(self: SeamlessDarkmode.Addon)
---@field InstallHooks fun(self: SeamlessDarkmode.Addon)
