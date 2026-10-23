# SeamlessDamageMeter

Optional damage and threat meter: up to `app.MAX_WINDOWS` (6) windows on top of the client's `C_DamageMeter`.
The `SeamlessDamageMeter` namespace in `SeamlessDB` holds shared suite profiles (window layouts, skins, selections);
`db.char.combatHistory` holds saved fights per character, independently of profiles.

**Saving fights is switched off for now** (`combatService.saveSessions = false` in `service.lua`):
the service uses an empty in-memory archive, leaves existing saved history untouched, resets old
fight selections and skips capture. Only client sessions are shown and the History tab is hidden.
The archive and capture rules below apply when it is switched back on.

## Load order

`src/core.lua` (lifecycle, database), `data.lua` (statistics, icons, Edit Mode samples),
`archive.lua` (saved fight schema and storage), `live.lua` (the only caller of combat APIs),
`service.lua` (`app.combatService`: shared queries and cache), `breakdowns.lua` (enemy
relationships), `capture.lua` (bounded capture after restrictions clear), `blizzard.lua` (native
meter visibility), `settings.lua` (defaults, overrides, migrations), `editmode.lua`,
`windows.lua` (frames and menus), `options.lua` (General, Window defaults, one tab per window,
Skin, History).
`src/types.lua` is annotations only. `docs/damage-meter-history.md` describes the archive's
architecture, limits and in-game acceptance checks.

## Combat data

- Use the exported client API under `../_data/wow_classic_beta` when adding statistics.
- Names and amounts can be secret: pass them straight to FontString/StatusBar setters; never
  compare, sort, concatenate or calculate with them. Only public amounts are abbreviated;
  percentages with a secret input are left blank. Keep the client's order and never modify
  returned tables.
- Live readability uses `canaccesstable` and lets secret leaves reach widgets; never use the
  archive's `issecrettable` rejection for live rendering.
- Source query arguments must be public: `UnitGUID("player")` for the player, public creature IDs
  where available. Restricted player identities stay unavailable, never guessed.
- Windows, menus and timers query `app.combatService`; one shared timer refreshes visible
  windows, and the service shares live reads and archive indexes.
- Saved fights: only service-owned public snapshots, copied through the allowlists in
  `archive.lua`, validated on load, never secrets, frames, functions or API tables. They stay
  queryable without tracking or the API. Archive IDs are independent of client IDs; live
  selections must not revive after a reset or reload; duplicate updates replace snapshots.
  History keeps 50 fights per character by default (1–1,000, pins count); the oldest goes first,
  removed fights never return, and clearing the archive doesn't reset the client meter.
- Native meter visibility (`blizzard.lua`) uses an OnShow hook, never a hook of its timer.
  Native Hide, UpdateShownState and the tracking CVar go through `securecallfunction` with the
  original functions only; never run the native timer pipeline or change Blizzard methods/state.

### Threat

A live-only category against the current hostile NPC target, never archived, outside the normal
0.5 s refresh. Threat, target, roster, pet and unit events refresh visible threat windows with
one shared read per event. `live:GetThreatSession` queries `UnitDetailedThreatSituation` for
every group member (zero threat included), their pets and other actors reachable through focus,
mouseover, target-of-target and nameplate tokens, without duplicate aliases. Non-players use
`FACTION_BAR_COLORS[UnitReaction(unit, "player")]`, falling back to index 5. Rows show total
threat and scaled aggro percentage (100% at aggro); public totals sort descending, secret totals
keep roster order. Run `lua src/tests/damage-meter-threat.lua`.

## Windows

- `app.MAX_WINDOWS` (`settings.lua`) is the only limit on window slots: frames, Edit Mode
  registration, options tabs and tests all follow it. Every profile has slots 1–`MAX_WINDOWS`; a
  fresh profile activates slot 1. `config.enabled` activates a slot, `config.hidden` hides it temporarily (`/sdm show` brings hidden windows back). All slot
  frames always exist (globals `SeamlessDamageMeterWindow<ID>`, an authorized exception for other
  addons; the ID is the fixed slot), keep their positions while inactive and can be anchor
  targets. Deactivating keeps all settings.
- Size and layout: `profile.windowDefaults` plus explicit `config.overrides` (nil inherits, false
  is a valid override).
- Position and scale (point, relativePoint, x, y, scale) are each window's own values in
  `config.position`, never overrides; `app.positionDefaults` only seeds new windows and Reset to
  default position. Write them with `app:SetWindowValue`. Each window's options tab
  shows them in Core's standard Position and scale section (`core:GetPositionOptions`).
  `config.anchorTo` is a window ID or nil for UIParent; circular anchors are rejected. Old window IDs, geometry fields and appearance settings are migrated idempotently;
  excess windows from old profiles stay in `profile.legacyWindows`.
- Skins: `profile.skins` holds named appearances, selected by `config.skin` (`default`).
  `app:RemoveSkin` deletes any skin but Default; windows using it fall back to Default.
  `config.modifyGlobalStyle` (default true) edits the shared skin; when false,
  `config.styleOverrides` take precedence (missing values inherit, false is valid).
- Use owned Lua frames with client art/fonts, never native meter mixins. Column widths depend
  only on public settings, never measured combat text. Reapply texture crops when pooling rows
  so zoom does not accumulate. Regenerate `Textures/ShadedBar.tga` with
  `python src/generate-meter-texture.py`.
- `fixedHeight` (default on, `visibleLines` 7, 1–30 in quarter steps) sizes the window from its
  rows; `showResizeHandle`, `lockSize` and `lockPosition` ("Lock position outside Edit Mode") are
  per window with shared defaults. Collapse keeps the header and the saved expanded height.
- Hover over a combat row: a pooled, headerless panel above the row (its width, at most 75% of
  the screen high, never takes the mouse) with the spell breakdown, or the death recap. Combat and
  post-combat hovers use separate pools; in combat only the normal source breakdown is queried.
  After combat, Targets/Contributors rows from the service's EnemyDamageTaken index are appended
  when public data exists; they never replace spells. Edit Mode rows never request live details.
- Left-click a combat row: the same breakdown inside the window; clicking the selector or
  right-clicking returns. The selection clears on category, session or profile changes, resets and
  Edit Mode.

## Edit Mode

- All slots register once with Core's namespaced LibEditMode, using documented methods and
  callbacks only. The library owns selection and dragging; we show and hide our windows.
- Each window's `editModeLayouts[layoutName]` in the profile snapshots position, size, scale and
  anchor overrides; layout and profile switches restore it, and layout create/copy/rename/delete
  updates every profile. Edit Mode moves always save, even with Lock position on.
- Moving a window (Edit Mode drag, nudge or Reset Position, or a header drag outside Edit Mode)
  releases its `anchorTo` and anchors it to UIParent where it was dropped, like Blizzard's Edit
  Mode; windows anchored to it keep following it.
- One Frames checkbox ("Seamless Damage Meter", via `core:RegisterEditModeOptions` with
  `section = "frames"`) previews active slots without changing activation. Previews use local
  sample sessions only, never live combat data, and expand collapsed windows visually.
- Reuse Core's Position section; window and Style settings follow it.
- Callbacks ignore calls outside Edit Mode or in combat. Never read or alter library-owned state
  (Selection, pools) or native layout containers.

## Tests and in-game checks

From the repository root: `lua src/tests/damage-meter-service.lua`, `damage-meter-blizzard.lua`,
`damage-meter-settings.lua`, `damage-meter-windows.lua`, `damage-meter-threat.lua` and
`editmode-loading.lua`.

In game: tracking on, a second window with another statistic, current/overall selection,
scrolling in a group, drag/resize/hide/show, deactivating every window, reload and profile
switch/reset, restricted combat values in and out of combat, inherited versus overridden settings,
windows anchored to each other, Edit Mode dragging, arrow keys, sliders, layouts and reload.
