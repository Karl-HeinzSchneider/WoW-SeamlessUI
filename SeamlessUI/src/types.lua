-- Annotations only; not loaded by the TOC.

---@class SeamlessUI
---@field optionPages table<string, SeamlessCore.SettingsPage>
---@field core SeamlessCore.Addon
---@field logger SeamlessCore.Logger
---@field addon SeamlessUI.Addon
---@field dbDefaults SeamlessUI.DBDefaults
---@field db SeamlessUI.DB
---@field options SeamlessUI.Options
---@field xpBarTooltip SeamlessUI.XPBarTooltip
---@field blizzardEditMode SeamlessUI.BlizzardEditMode
---@field blizzardPosition SeamlessUI.BlizzardPosition
---@field systemOptions SeamlessUI.SystemOptions
---@field fpsDisplay SeamlessUI.FPSDisplay
---@field editModeKeyboard SeamlessUI.EditModeKeyboard

---@class SeamlessUI.DB : AceDBObject-3.0
---@field profile SeamlessUI.DB.Profile
---@field char SeamlessUI.DB.Char
---@field global SeamlessUI.DB.Global

---@class SeamlessUI.DBDefaults : AceDB.Schema
---@class SeamlessUI.DB.Profile
---@class SeamlessUI.DB.Char
---@class SeamlessUI.DB.Global
