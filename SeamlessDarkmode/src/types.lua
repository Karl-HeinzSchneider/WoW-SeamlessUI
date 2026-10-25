-- Annotations only; not loaded by the TOC.
---@class SeamlessDarkmode
---@field optionPages table<string, SeamlessCore.SettingsPage>
---@field core SeamlessCore.Addon
---@field addon SeamlessDarkmode.Addon
---@field dbDefaults AceDB.Schema
---@field db AceDBObject-3.0
---@field groups SeamlessDarkmode.Group[]
---@field StatusTrackingBars fun(experience: SeamlessDarkmode.Paint, reputation: SeamlessDarkmode.Paint, restore: SeamlessDarkmode.Paint)

---@class SeamlessDarkmode.Group
---@field key string
---@field name string
---@field frames fun(paint: SeamlessDarkmode.Paint)[]

---@class SeamlessDarkmode.Addon : AceAddon, AceConsole-3.0, AceEvent-3.0, AceHook-3.0
---@field Refresh fun(self: SeamlessDarkmode.Addon)
---@field InstallHooks fun(self: SeamlessDarkmode.Addon)
