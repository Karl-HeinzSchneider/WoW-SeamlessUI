-- Annotations only; not loaded by the client.
---@class SeamlessCore
---@field IsEditModeSectionCollapsed fun(key: string): boolean
---@field SetEditModeSectionCollapsed fun(key: string, collapsed: boolean)
---@field CreateEditModeHeader fun(parent: table, onClick: fun()): table
---@field LibEditMode table Namespaced Edit Mode library instance, extended by `editmodelib.lua` (SettingType.Header, scrolling dialog).
---@field logger SeamlessCore.Logger
---@field addon SeamlessCore.Addon
---@field dbDefaults AceDB.Schema
---@field db SeamlessCore.DB
---@field options SeamlessCore.Options
---@field minimapButton SeamlessCore.MinimapButton
---@field tweaks SeamlessCore.Tweaks

---@class SeamlessCore.Addon
---@field GetEditModeLibrary fun(self: SeamlessCore.Addon): table
---@field RegisterEditModeOptions fun(self: SeamlessCore.Addon, id: string, spec: SeamlessCore.EditModeOptions)
---@field RefreshEditModeOptions fun(self: SeamlessCore.Addon)
---@field logger SeamlessCore.Logger
---@field db SeamlessCore.DB
---@field FeatureGroup fun(spec: SeamlessCore.FeatureSpec): table

---@class SeamlessCore.DB : AceDBObject-3.0
---@field profile SeamlessCore.Profile

---@class SeamlessCore.Profile
---@field logLevel string
---@field minimap table
---@field tweaks { reloadShortcut: boolean, showFramerateOnStartup: boolean, enhancedXPTooltip: boolean, restedXPCap: number, restedXPRate: number }

---@class SeamlessCore.EditModeOptions
---@field section "options"|"frames"|nil Defaults to options, above the shared Frames heading.
---@field name string? Optional group heading.
---@field order number? Group order; ties use the registration id.
---@field enabled boolean|fun(): boolean|nil Whether this feature contributes rows.
---@field options SeamlessCore.EditModeOption[]

---@class SeamlessCore.EditModeOption
---@field key string Unique within the group.
---@field type "toggle"|"button"|"custom"|"header" A header is a section title like the Frames heading.
---@field name string? Label required for built-in controls and headers.
---@field order number? Defaults to the array index.
---@field hidden boolean|fun(): boolean|nil
---@field disabled boolean|fun(): boolean|nil
---@field get? fun(): boolean Toggle value.
---@field set? fun(value: boolean) Toggle callback.
---@field click? fun() Button callback.
---@field create? fun(parent: table): table Custom row factory; return a child of parent.
---@field layout? fun(frame: table, width: number, disabled: boolean): number? Optional custom row sizing/state callback.
