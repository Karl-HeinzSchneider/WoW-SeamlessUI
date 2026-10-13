# SeamlessDamageMeter

Optional feature addon for WoW Forever (`16001`), requiring SeamlessCore.
`SeamlessDamageMeterDB` stores independent AceDB profiles containing window layouts and
statistic/session selections. Combat data stays owned by `C_DamageMeter`.

Load order: `core.lua` (lifecycle/database), `data.lua` (client API adapter),
`blizzard.lua` (turns tracking on, keeps the game's meter window hidden),
`settings.lua` (shared defaults, override resolution and legacy layout migration),
`editmode.lua` (EditModeExpanded registration and profile/layout synchronization),
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
mixins. Reuse client art and fonts. The header is 32 pixels tall; rows default to 24 pixels with
4 pixels between them. The session selector shows a compact current/overall label or history
ID; its full selection remains in the menu. Collapse keeps the header visible, separately
from hiding a window. Save the expanded height and keep the header position stable when
collapsing, expanding and reloading. Guard geometry callbacks during layout restoration.
Amounts and names go directly to widget setters when secret; only public amounts can pass
through number abbreviation. An offscreen local player stays visible in a separate row.
Rows use full square icons sized to the row height and an original grayscale shaded fill
with a bright top edge and dark bottom edge, tinted by the bar color. The unfilled background
is flat and dark. Regenerate `Textures/ShadedBar.tga` with `python src/generate-meter-texture.py`;
the generator uses only our own formula and reads no reference assets. Amount-based statistics
show total and rate in compact form; DPS/HPS swap their order, and action counts omit rates.

Windows intentionally expose globals for other addons: `SeamlessDamageMeterWindow<ID>`
(for example `SeamlessDamageMeterWindow1`). The suffix is the fixed slot number, not its
position in the list. All ten frames are retained and reused across profile changes.
The frame's `windowID` is stable; `config` always reflects its currently bound profile,
including while inactive. This is an authorized
exception to the repository's default rule against additional globals.

All ten slots register with EditModeExpanded-1.0, embedded unchanged from `_libs` in
Core. Each window's `editMode` table stores native layout settings inside its AceDB
profile. The adapter rebinds the library's exposed `baseFramesDB`/`framesDB` tables
(minor 121) because RegisterFrame cannot replace a pooled frame's database. Meter
settings seed the current native layout on rebuild; library moves and scale changes
update meter overrides while preserving independent anchor points and collapse offsets.
Inactive slots default to unchecked in Edit Mode. Left-clicking the Expanded checkbox
activates/unhides or deactivates the real addon slot; right-click remains the library's
position reset. Synchronize checkbox state from real slot activation across native layouts.
Edit Mode uses only local classic-character sample sessions, even when tracking is off,
the API is absent or the selected history expired. Never read live combat data or duration
while editing. Collapsed windows expand visually without changing their saved collapse
flag; entering and exiting immediately refreshes content and geometry. Labels are
"Seamless Damage 1" through "Seamless Damage 10". Exit restores normal
visibility and movability. Verify Edit Mode dragging, arrow keys, scaling, native layout
changes, collapsed windows, linked anchors, AceDB switch/copy/reset and reload in game.
Check sample names/classes/amounts for every statistic, and checkbox activation/deactivation
persisting after exit and reload. Preview sessions are never saved.
Width/Height custom sliders (EME setting 18) update existing size overrides immediately.
Sync slider values from meter settings on rebuild and ignore callbacks outside Edit Mode.
The resize grip stays visible and above the EME selection overlay while editing, including
when normal dragging is locked. Verify slider/grip resizing and persistence after exit/reload.

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
