# SeamlessDamageMeter

Optional feature addon for WoW Forever (`16001`), requiring SeamlessCore.
`SeamlessDamageMeterDB` stores independent AceDB profiles containing window layouts and
statistic/session selections. Combat data stays owned by `C_DamageMeter`.

Load order: `core.lua` (lifecycle/database), `data.lua` (client API adapter),
`blizzard.lua` (turns tracking on, keeps the game's meter window hidden),
`settings.lua` (shared defaults, override resolution and legacy layout migration),
`windows.lua` (pooled frames and menus), `options.lua` (General, Windows, Profiles).
`types.lua` contains annotations only and is not shipped.

Use the exported client API documentation under `../_data/BlizzardInterfaceCode` when
extending statistics. Combat names and amounts can be secret: pass them directly to
FontString and StatusBar setters. Do not compare, sort, concatenate or calculate with
them. Preserve the client's source order and do not modify returned data tables.
Only layout and selections belong in SavedVariables; never persist combat results.

One shared timer refreshes visible windows, with per-refresh caching for matching views.
Frames and rows are reused. Every profile always contains slots 1�10; only a fresh/reset
profile activates slot 1 by default. A profile with all slots inactive stays inactive.
Hidden active windows are restored via `/sdm show`; this does not activate inactive slots.

The Windows tab always lists all ten windows, with inactive/hidden names greyed out and
settings still editable. `config.enabled` controls usage; `config.hidden` hides an active
window temporarily. Deactivation preserves all configuration, geometry and anchor links.
All ten independent frames exist and retain their positions while hidden, so dependent
windows may anchor to inactive windows. Adding activates the first inactive slot and
preserves its settings. Old increasing IDs migrate to free slots while preserving settings
and remapping anchors; valid existing slot IDs stay unchanged. Excess windows from very
old profiles are retained in `profile.legacyWindows`.
`profile.windowDefaults` supplies appearance and geometry; `config.overrides` stores only
explicit overrides (nil inherits; false is a valid toggle override). Old width/height/x/y
fields migrate into overrides. Dragging overrides X/Y, resizing also overrides width/height.
`config.anchorTo` is a window ID or nil for UIParent; reject circular anchors. Deactivating an
anchor target preserves the attachment and its geometry. Defaults are profile scoped.

Window rendering uses plain Lua-created frames without inherited frame templates or meter
mixins. Reuse client art and fonts. The header is 32 pixels tall; rows are 18 pixels with
4 pixels between them. The session selector shows a compact current/overall label or history
ID; its full selection remains in the menu. Collapse keeps the header visible, separately
from hiding a window. Save the expanded height and keep the header position stable when
collapsing, expanding and reloading. Guard geometry callbacks during layout restoration.
Amounts and names go directly to widget setters when secret; only public amounts can pass
through number abbreviation. An offscreen local player stays visible in a separate row.
Rows clip the fixed-size icon and bar art to their entry bounds. Amount-based statistics
show total and rate in compact form; DPS/HPS swap their order, and action counts omit rates.

Windows intentionally expose globals for other addons: `SeamlessDamageMeterWindow<ID>`
(for example `SeamlessDamageMeterWindow1`). The suffix is the fixed slot number, not its
position in the list. All ten frames are retained and reused across profile changes.
The frame's `windowID` is stable; `config` always reflects its currently bound profile,
including while inactive. This is an authorized
exception to the repository's default rule against additional globals.

Right-click a window to toggle its six-slot favorites view inside the normal data area.
Favorites reuse the combat row art, configured fonts, bar color, height and spacing, and
the existing scrollbar with a separate scroll offset. Combat rows and the pinned player
row are hidden while favorites are visible; live refreshes preserve the favorites view.
`config.favorites` stores
statistic keys by slot, independently per window and profile; all slots start empty.
Empty slots open the type menu to assign a favorite without changing the displayed type.
Assigned slots switch the displayed type immediately; right-click them to replace or clear.
Only one favorites view is open at a time. Hide, collapse and profile rebuild dismiss it.

Run `lua src/tests/damage-meter-settings.lua` for inheritance and AceConfig schema checks.
Run `lua src/tests/damage-meter-windows.lua` from the repository root for the standalone
window regression harness (template independence, restricted data, collapse persistence,
scrolling, shared reads, expired history, empty data and deactivating every window).

In-game verification: enable tracking, attack a target, add a second window and select
DPS or healing independently. Verify current/overall/history selection, scrolling with
a group, drag/resize, hide/show, deactivating every window, reload persistence and profile
switch/reset. Clear Blizzard history while viewing an old fight and verify the empty
state. Check both in and out of combat, including restricted combat values.
Verify default changes propagate only to inherited settings, including fonts and colors;
toggle overrides off, drag/resize scaled windows, enter decimal coordinates, anchor windows
to each other, deactivate the anchor target, and check the 10-window limit.
