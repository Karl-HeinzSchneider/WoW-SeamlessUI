-- Annotations only; not loaded by the TOC.
---@class SeamlessDarkmode
---@field optionPages table<string, SeamlessCore.SettingsPage>
---@field core SeamlessCore.Addon
---@field addon SeamlessDarkmode.Addon
---@field dbDefaults AceDB.Schema
---@field db AceDBObject-3.0
---@field categories SeamlessDarkmode.Category[]
---@field IsPartEnabled fun(category: SeamlessDarkmode.Category, part: SeamlessDarkmode.Part): boolean
---@field StatusTrackingBars fun(experience: SeamlessDarkmode.Paint, reputation: SeamlessDarkmode.Paint, restore: SeamlessDarkmode.Paint)

---@class SeamlessDarkmode.Color
---@field r number
---@field g number
---@field b number

---@class SeamlessDarkmode.Category
---@field key string
---@field name string
---@field legacyGroup? string
---@field parts SeamlessDarkmode.Part[]

---@class SeamlessDarkmode.Part
---@field key string
---@field name string
---@field frame? fun(paint: SeamlessDarkmode.Paint)

---@class SeamlessDarkmode.Addon : AceAddon, AceConsole-3.0, AceEvent-3.0, AceHook-3.0
---@field Refresh fun(self: SeamlessDarkmode.Addon)
---@field InstallHooks fun(self: SeamlessDarkmode.Addon)
