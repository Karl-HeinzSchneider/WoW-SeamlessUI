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
from hiding a window. `hideTypeSelector` defaults to false and supports shared defaults and
window overrides; hiding it removes the category arrow and its clicks while retaining the label.
Header order is type arrow, category label, then combat timer. The 25-pixel selector stays
at the left edge (X 3), with its arrow centered vertically opposite the red collapse button.
The category starts at X 28, Y -9 within the header and never moves when the timer changes.
Hiding the selector preserves the category label's position and reserved arrow space.
The timer follows the category label on the same line, left aligned with natural text width.
`hideCombatTimer` defaults to false and supports shared defaults and window overrides,
including Edit Mode previews. Toggling it preserves the category position.
Save the expanded height and keep the header position stable when
collapsing, expanding and reloading. Guard geometry callbacks during layout restoration.
Amounts and names go directly to widget setters when secret; only public amounts can pass
through number abbreviation. An offscreen local player stays visible in a separate row.
Hovering a combat row (including the pinned player) shows its selected session's spell
breakdown in a headerless, pooled hover panel. Each entry is a bar using the main window's
texture, row height/spacing, font and color settings, with totals, rates and public percentage
shares. Icons follow the API's specialization/class metadata, falling back to the spell
texture from `C_Spell`. Deaths show recap event bars scaled against recap max health.
Preserve API ordering and send restricted names/amounts directly to labels and status bars;
omit percentages when their inputs are secret. Refresh the owned tooltip with its pooled
row, dismiss it on leave/hide, and never request live details for Edit Mode preview rows.
The panel opens directly above the hovered row, with both bottom corners anchored to the
row's top corners so its width matches the full bar including its icon. Its height is capped
at 75% of the screen. Mouse wheel over the owner scrolls an overflowing
breakdown; otherwise it keeps the window's normal scrolling. The panel never captures mouse
input, so moving off the owner dismisses it.
Damage done and DPS add a "Targets" category below the spell bars, showing total damage
per target name with an independent bar scale and percentage of source damage. Combine
public `combatSpellDetails.amount` values only when every spell has a public, nonempty
target name and its target amount equals the spell total, and all amounts account for the
source total. The API provides no target GUID, so identically named units are combined.
Restricted or incomplete detail data shows a short unavailable message instead of partial
totals. Keep first-appearance order, leave returned API tables untouched, and never save
these aggregates. Other statistics and death recaps retain their existing breakdown.
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

Right-click a window to toggle shared favorite slots followed by a "Select type" row inside the normal data area.
General's Maximum visible favorites setting defaults to six, accepts 0–20, and immediately
refreshes open lists. Reducing it preserves hidden favorites; pooled rows beyond the limit are hidden.
The selector opens the normal type menu and changes the window's statistic without assigning a favorite.
Favorites reuse the combat row art, configured fonts, bar color, height and spacing, and
the existing scrollbar with a separate scroll offset. Combat rows and the pinned player
row are hidden while favorites are visible; live refreshes preserve the favorites view.
`profile.favorites` stores statistic keys by slot shared by every window; all slots start empty.
Legacy window favorites migrate in window-slot order, filling only empty shared slots.
Empty slots open the type menu to assign a favorite without changing the displayed type.
Assigned slots switch the displayed type immediately; right-click them to replace or clear.
Only one favorites view is open at a time. Hide, collapse and profile rebuild dismiss it.

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
The resize grip, when enabled, stays visible and above the EME selection overlay while editing, including
when normal dragging is locked. Synchronize its frame level on every layout refresh and use
HIGH strata during Edit Mode so the top-level selection cannot cover it after being raised.
Restore the window's strata on exit. Verify slider/grip resizing and persistence after exit/reload.

`fixedHeight` defaults to false; `visibleLines` defaults to 7 and accepts 1–30 in quarter-line
steps. Expanded height includes the header, body padding, row heights and spacing. Fixed
height follows row appearance changes and constrains grip resizing to width; Edit Mode's
height slider is ignored. Manual height is preserved for when fixed height is disabled.
`showResizeHandle` defaults to true and hides/disables the grip in normal and Edit Mode.
Both settings and the line count support shared defaults and per-window overrides.

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
