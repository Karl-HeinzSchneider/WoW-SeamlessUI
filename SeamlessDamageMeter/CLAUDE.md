# SeamlessDamageMeter

Optional feature addon for WoW Forever (`16001`), requiring Seamless.
`SeamlessDamageMeterDB` stores independent AceDB profiles containing window layouts and
statistic/session selections. Client collection stays owned by `C_DamageMeter`; character-scoped
`db.char.combatHistory` stores validated public completed fights independently of profiles.

Load order: `core.lua` (lifecycle/database), `data.lua` (renderer facade/statistics/previews),
`archive.lua` (schema/storage), `live.lua` (client API provider), `service.lua` (shared queries/cache),
`breakdowns.lua` (enemy relationships/comparisons/reports), `capture.lua` (bounded capture/retries),
`blizzard.lua` (controls native meter visibility without forcing its CVar on),
`settings.lua` (shared defaults, override resolution and legacy layout migration),
`editmode.lua` (EditModeExpanded registration and profile/layout synchronization),
`windows.lua` (pooled frames and menus), `analysis.lua` (detail/copy panel),
`options.lua` (General, Windows, Skin, History, Profiles).
`types.lua` contains annotations only and is not shipped.

Use the exported client API documentation under `../_data/BlizzardInterfaceCode` when
extending statistics. Combat names and amounts can be secret: pass them directly to
FontString and StatusBar setters. Do not compare, sort, concatenate or calculate with
them. Preserve the client's source order and do not modify returned data tables.
Persist only service-owned public snapshots copied through the explicit allowlists in `archive.lua`.
Validate restored archives before querying them. Never store secret values, frames/functions,
or references to API tables. Windows, menus, analysis and timers query `app.combatService`;
only `live.lua` calls combat APIs. Edit Mode samples never read or capture live combat.
Live readability uses `canaccesstable` and allows secret leaves to reach widgets. Never reuse
archive table rejection for live rendering: `issecrettable` may flag readable secret-bearing tables.
Source query arguments must be public; use `UnitGUID("player")` for local-player rows and public
creature IDs where available. Other restricted player identities remain unavailable, never guessed.
Saved fights remain queryable without tracking or the API. Archive IDs are independent of
client IDs; generation-scoped live selections must not revive after reset/reload. Duplicate updates
replace snapshots rather than append or add totals twice. Capture runs with every window hidden.
See `docs/damage-meter-history.md` for architecture, limits and in-game acceptance checks.

One shared timer refreshes visible windows; the service shares live reads and archive indexes.
A separate bounded capture timer handles completed fights after restrictions clear.
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
`profile.skins` holds named appearance settings; every window selects `config.skin`, defaulting to
`default` (Default). The Skin tab uses a tree list like Windows and can add copies of Default.
Fonts, colors, header controls, row height/spacing and icon visibility resolve exclusively from
the selected skin. Legacy appearance defaults migrate to Default; explicit window appearance
overrides migrate to separate named skins to preserve their look. Migration is idempotent.
`profile.windowDefaults` supplies geometry; `config.overrides` stores only
explicit overrides (nil inherits; false is a valid toggle override). Old width/height/x/y
fields migrate into overrides. Dragging overrides X/Y, resizing also overrides width/height.
`config.anchorTo` is a window ID or nil for UIParent; reject circular anchors. Deactivating an
anchor target preserves the attachment and its geometry. Defaults are profile scoped.

Window rendering uses plain Lua-created frames without inherited frame templates or meter
mixins. Reuse client art and fonts. The header is 32 pixels tall; rows default to 24 pixels with
4 pixels between them. The session selector shows a compact current/overall label or history
ID; its full selection remains in the menu. Collapse keeps the header visible, separately
from hiding a window. `hideTypeSelector` defaults to false and is configured per skin; hiding it removes the category arrow and its clicks while retaining the label.
Header order is type arrow, category label, then combat timer. The 25-pixel selector stays
at the left edge (X 3), with its arrow centered vertically opposite the red collapse button.
The category starts at X 28, Y -9 within the header and never moves when the timer changes.
Hiding the selector preserves the category label's position and reserved arrow space.
The timer follows the category label on the same line, left aligned with natural text width.
`hideCombatTimer` defaults to false and is configured per skin,
including Edit Mode previews. Toggling it preserves the category position.
Save the expanded height and keep the header position stable when
collapsing, expanding and reloading. Guard geometry callbacks during layout restoration.
Amounts and names go directly to widget setters when secret; only public amounts can pass
through number abbreviation. An offscreen local player stays visible in a separate row.
Hovering a combat row (including the pinned player) shows its selected session's spell
breakdown in a headerless, pooled hover panel. Each entry is a bar using the main window's
texture, row height/spacing, font and color settings, with totals, rates and public percentage
shares in separate right-aligned columns. The same numeric columns are used in main meter rows.
Widths depend only on public window/font settings, never combat text measurements. Keep columns
aligned across pooled rows; clear unavailable percentages and hide rate columns for action counts.
Icons follow the API's specialization/class metadata, falling back to the spell
texture from `C_Spell`. Deaths show recap event bars scaled against recap max health.
Preserve API ordering and send restricted names/amounts directly to labels and status bars;
omit percentages when their inputs are secret. Refresh the owned tooltip with its pooled
row, dismiss it on leave/hide, and never request live details for Edit Mode preview rows.
The panel opens directly above the hovered row, with both bottom corners anchored to the
row's top corners so its width matches the full bar including its icon. Its height is capped
at 75% of the screen. Mouse wheel over the owner scrolls an overflowing
breakdown; otherwise it keeps the window's normal scrolling. The panel never captures mouse
input, so moving off the owner dismisses it.
Damage/DPS Targets and enemy damage taken Contributors use the service's EnemyDamageTaken
contribution index. Combine public contributor rows by name, preserve client creature IDs and
label incomplete reconciliation. Targets show share of player damage / share of enemy damage
received; contributor percentages use enemy damage received. Units already combined by the API
cannot be separated. Never infer complete target totals from player spell summaries.
Use separate pooled combat and post-combat hover frames. Combat hover queries only the normal
source spell breakdown and never requests target/contributor analysis. Switch pools on refresh
when combat state changes, hiding the former owner and resetting the new pool's scroll offset.
Normal API spell breakdowns stay visible in combat. After combat, append target headings/rows only when target
data exists; unavailable targets never replace spells or add a restriction warning to the hover.
Target availability is determined from the required public enemy/contributor fields, not a blanket
combat flag. Optional secret GUIDs/spell IDs are ignored and unavailable rates remain blank.
Enemy hover likewise retains its normal API details until public contributor analysis is available.
Left-click a public row for spell flags, target analysis, saved metadata and copyable reports.
Saved session menus expose pin/delete/compare, delete-older and clear actions. History defaults
to 50 saved segments per character, configurable from 1 to the hard cap of 1,000. Pins count
toward the limit. Delete the oldest segment before inserting beyond the limit; lowering the
limit prunes immediately. Removed segments must not return as live entries or be recaptured.
Clearing archives does not reset the client meter.
Rows use full square icons sized to the row height and an original grayscale shaded fill
with a bright top edge and dark bottom edge, tinted by the bar color. The unfilled background
is flat and dark. Regenerate `Textures/ShadedBar.tga` with `python src/generate-meter-texture.py`;
the generator uses only our own formula and reads no reference assets. Amount-based statistics
show total and rate in separate columns; DPS/HPS swap their order, and action counts omit rates.

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

`fixedHeight` defaults to true; `visibleLines` defaults to 7 and accepts 1–30 in quarter-line
steps. Expanded height includes the header, body padding, row heights and spacing. Fixed
height follows row appearance changes and constrains grip resizing to width; Edit Mode's
height slider is ignored. Manual height is preserved for when fixed height is disabled.
`showResizeHandle` defaults to true and hides/disables the grip in normal and Edit Mode.
Both settings and the line count support shared defaults and per-window overrides.
`lockSize` defaults to false and blocks the grip and Edit Mode width/height sliders without
locking position. Edit Mode exposes fixed height, a 1�30 row-count slider (whole rows; addon options retain quarter rows),
size lock, a skin dropdown and an Edit selected skin button opening that skin's options.
Meter configuration remains authoritative; synchronize checkbox/slider values and selected
skin labels on rebuild/profile changes. Ignore initialization/outside-Edit-Mode callbacks.
Explicit saved fixed-height choices are retained when changing the default to seven fixed rows.

Run `lua src/tests/damage-meter-service.lua` for capture, persistence, restrictions and indexes.
Run `lua src/tests/damage-meter-blizzard.lua` for native CVar/visibility isolation and Edit Mode hiding.
Run `lua src/tests/damage-meter-settings.lua` for inheritance and AceConfig schema checks.
Run `lua src/tests/damage-meter-windows.lua` from the repository root for the standalone
window regression harness (template independence, restricted data, collapse persistence,
scrolling, shared reads, expired history, empty data and deactivating every window).

Native meter visibility uses an OnShow script hook, never a hook of its timer updater. Native Hide,
UpdateShownState and tracking-CVar calls go through `securecallfunction` with original Blizzard/C
functions only; addon closures never gain secret access. Do not run the native timer pipeline
directly from addon callbacks or modify Blizzard methods/state. A reload clears old hooks/taint.

In-game verification: enable tracking, attack a target, add a second window and select
DPS or healing independently. Verify current/overall/history selection, scrolling with
a group, drag/resize, hide/show, deactivating every window, reload persistence and profile
switch/reset. Clear Blizzard history while viewing a saved fight and verify its data remains available.
Expired unsaved selections and deleted archives must show an unavailable state. Check both in and out of combat, including restricted combat values.
Verify default changes propagate only to inherited settings, including fonts and colors;
toggle overrides off, drag/resize scaled windows, enter decimal coordinates, anchor windows
to each other, deactivate the anchor target, and check the 10-window limit.
