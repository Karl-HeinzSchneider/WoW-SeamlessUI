# SeamlessDamageMeter

Optional feature addon for WoW Forever (`16001`), requiring Seamless.
Session saving is temporarily disabled by `combatService.saveSessions = false`. The service
uses an empty in-memory archive, leaves existing saved history untouched, resets old fight
selections on initialization and skips capture. Only client sessions are shown; History is hidden.
The archive/capture documentation below describes the retained implementation when enabled.
`SeamlessDamageMeterDB` stores independent AceDB profiles containing window layouts and
statistic/session selections. Client collection stays owned by `C_DamageMeter`; character-scoped
`db.char.combatHistory` stores validated public completed fights independently of profiles.

Load order: `core.lua` (lifecycle/database), `data.lua` (renderer facade/statistics/previews),
`archive.lua` (schema/storage), `live.lua` (client API provider), `service.lua` (shared queries/cache),
`breakdowns.lua` (enemy relationships), `capture.lua` (bounded capture/retries),
`blizzard.lua` (controls native meter visibility without forcing its CVar on),
`settings.lua` (shared defaults, override resolution and legacy layout migration),
`editmode.lua` (LibEditMode registration and profile/layout synchronization),
`windows.lua` (pooled frames and menus),
`options.lua` (General, Windows, Skin, History, Profiles).
`types.lua` contains annotations only and is not shipped.

Use the exported client API documentation under `../_data/wow_classic_beta` when
extending statistics. Combat names and amounts can be secret: pass them directly to
FontString and StatusBar setters. Do not compare, sort, concatenate or calculate with
them. Preserve the client's source order and do not modify returned data tables.
Persist only service-owned public snapshots copied through the explicit allowlists in `archive.lua`.
Validate restored archives before querying them. Never store secret values, frames/functions,
or references to API tables. Windows, menus and timers query `app.combatService`;
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
Threat is a live-only category against the current hostile NPC target, independent of the
normal 0.5-second refresh timer, selected fight and damage-meter tracking. Threat/list,
target, roster, pet and discoverable-unit
events refresh visible threat windows immediately, sharing one fresh read per event.
The periodic rate refresh skips threat windows; Edit Mode ignores live threat events.
`live:GetThreatSession` queries Blizzard's
`UnitDetailedThreatSituation` for every party/raid player (including zero-threat players).
Include their pets, plus distinct actors exposed through focus, mouseover, target-of-target
and nameplate tokens when the API supplies threat. Pets and other non-player actors use
`FACTION_BAR_COLORS[UnitReaction(unit, "player")]`; missing or restricted reactions and
missing player class colors fall back to `FACTION_BAR_COLORS[5]`. Reaction changes refresh
through `UNIT_FACTION`. Duplicate unit aliases are omitted. Guardians without accessible unit tokens cannot be queried.
Rows always use class colors and show total threat plus scaled aggro percentage (100% at
aggro), with no rate or spell hover. Public totals sort descending; secret totals preserve
roster order and pass directly to widgets. Threat snapshots are never archived.
Run `lua src/tests/damage-meter-threat.lua` for roster, restrictions and shared-cache checks.
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
mixins. Reuse client art and fonts.
The gear menu lists Settings, Editmode, a spacer, Lock/Unlock Position, Make Noninteractive, Reset Data,
Delete Window, a spacer, and Create New Window. Noninteractive mode is saved per window;
keep gear/collapse available and offer Make Interactive to restore input. Edit Mode permits
interaction regardless of this flag. Reset Data resets client sessions through `live.lua`;
saved fight history remains intact. Delete Window deactivates the slot, retaining its settings.
The default bar font resolves from `NumberFontNormal`, matching the native meter's locale-specific
typeface; skin font size and outline settings still apply. Class bar RGB comes directly from
`RAID_CLASS_COLORS` at full opacity, with no brightness adjustment; the grayscale fill shades it.
The header is 32 pixels tall; rows default to 24 pixels with 4 pixels between them.
The session selector shows a compact current/overall label or history
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
Left-clicking a combat row opens its spell breakdown (or death recap) inside the same window.
The header shows the selected source; clicking its selector or right-clicking returns to the
category and restores its scroll position. Details reuse hover bar styling and numeric columns,
refresh with the window, and have their own scroll position. Selection is transient and clears
on category/session/profile changes, service reset or Edit Mode. Threat and preview rows do not
open details. Restricted identities show the service unavailable message without guessing a source.
Saved session menus expose pin/delete, delete-older and clear actions. History defaults
to 50 saved segments per character, configurable from 1 to the hard cap of 1,000. Pins count
toward the limit. Delete the oldest segment before inserting beyond the limit; lowering the
limit prunes immediately. Removed segments must not return as live entries or be recaptured.
Clearing archives does not reset the client meter.
Specialization and spell textures crop 10% from each edge (`0.1`–`0.9` UVs) to remove baked-in
borders. Apply the crop after setting each texture so pooled rows do not accumulate zoom;
class atlas fallbacks retain their own atlas coordinates.
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
Favorites show each statistic's explicit `icon` from `data.lua` instead of slot numbers.
Damage done uses Fireball, Healing done uses Healing Touch, Absorbs uses Power Word: Shield,
Interrupts uses Kick and Dispels uses Cleanse. Other statistics, empty slots and Select type use question-mark placeholders.
`profile.favorites` stores statistic keys by slot shared by every window; all slots start empty.
Legacy window favorites migrate in window-slot order, filling only empty shared slots.
Empty slots open the type menu to assign a favorite without changing the displayed type.
Assigned slots switch the displayed type immediately; right-click them to replace or clear.
Only one favorites view is open at a time. Hide, collapse and profile rebuild dismiss it.

All ten slots register once with Core's namespaced LibEditMode via `core:GetEditModeLibrary()`.
Use only documented library methods/callbacks; never read or alter Selection, internal pools,
frameSelections or other library-owned state. The library owns selection visibility and dragging;
we show/hide our parent windows. Position locking rejects movement in the position callback
(the dragged preview can move temporarily until dropped). Dynamic getters and
setters read each pooled frame's current AceDB profile configuration. Geometry and skin settings
remain authoritative; legacy `config.editMode` data is retained but no longer read. Each window's
`editModeLayouts[layoutName]` snapshots position, dimensions, scale and linked anchor overrides
inside its AceDB profile. Missing layouts seed from current geometry. Layout switch and profile
switch/copy/reset restore the corresponding record; create/copy/rename/delete callbacks maintain
records across all AceDB profiles. Movement uses the callback's point/X/Y directly for UIParent;
linked anchors convert the resulting screen position. Control defaults use factory defaults,
not registration-time values; reset bypasses size locks and selects Default skin first.
One "Seamless Damage Meter" checkbox controls previews of active slots, including temporarily
hidden windows, without changing activation or normal visibility. Preview visibility is transient.
The meter only registers its toggle through `core:RegisterEditModeOptions`; Core owns the
shared bordered SeamlessUI panel, widgets, sizing and visibility. Refresh Core's options on
profile/enabled-state changes. Never create feature-owned companion controls or modify native
layout containers; MarkDirty propagates tainted update scripts into Blizzard ancestors.
Buttons create the next unused window, remove the selected window, and open its skin settings.
Callbacks ignore edits outside Edit Mode or in combat. Never patch the vendored library.
Edit Mode uses only local classic-character sample sessions, even when tracking is off,
the API is absent or the selected history expired. Never read live combat data or duration
while editing. Collapsed windows expand visually without changing their saved collapse
flag; entering and exiting immediately refreshes content and geometry. Labels are
"Seamless Damage 1" through "Seamless Damage 10". Exit restores normal
visibility and movability. Verify Edit Mode dragging, arrow keys, scaling, native layout
changes, collapsed windows, linked anchors, AceDB switch/copy/reset and reload in game.
Check sample names/classes/amounts for every statistic, grouped preview toggling, creating
new windows and restored normal visibility after exit. Preview sessions are never saved.
Width/Height sliders update meter size overrides; height is disabled with fixed row height,
and both are disabled with size lock. The resize grip remains above the selection overlay.
Verify sliders, grip, scaling, linked anchors, profile changes and reload persistence in game.

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
`lockPosition` defaults to false, supports shared defaults and per-window overrides, and
blocks header dragging and rejects committed Edit Mode drag/arrow/reset movement independently of size.
It is available in addon options, Edit Mode and the window gear menu. Explicit coordinate
settings and anchor updates remain available while locked.

Run `lua src/tests/editmode-loading.lua` for namespaced embedding, isolated instances and Core access.
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

Edit Mode also exposes bar height, padding (row spacing), transparency, background,
text size, spec icons and class colors. Appearance edits update the selected shared skin;
all windows using it refresh immediately. Transparency is window opacity (50�100%),
background is the existing background color alpha (0�100%), and text size is a percentage
of the default 15-pixel font (50�150%). Pixel bar/spacing ranges retain the addon skin ranges.
The same opacity is editable in the Skin tab. Existing skins default to full window opacity.
