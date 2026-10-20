# SeamlessUnitframes

Optional unit frame addon: changes the game's own unit frames. Settings and profiles live in
`SeamlessUnitframesDB`.

## TOC load order and ownership

1. `src/core/bootstrap.lua`: gets Core through AceAddon and shares its logger.
2. `db.lua`: defaults, including one table per unit frame in `profile.unitFrames[key]`.
3. `ace.lua`: AceAddon/AceDB lifecycle, profile callbacks and `/seamlessunitframes` (`reset`
   resets this profile; `loglevel` delegates to Core).
4. `unitframes.lua`: registry of player, pet, target, target of target, focus, target of focus and
   party frames (`Exists`, `KeyOf`, `All`, `Get(key)`). Each entry names its
   `Enum.EditModeUnitFrameSystemIndices` `system`, or `linkedTo` the frame whose Edit Mode
   settings show it. `players` marks frames that show player characters, `pvpIcon` frames with a
   PvP icon.
5. `questicons.lua`: reads unfinished tooltip objectives and matches quest log objective types.
6. `style.lua`: the single source of every per-frame setting. `app.StyleGroups(key)` returns a
   frame's groups (Name and Portrait where `players`, Health bar, PvP where `pvpIcon`, Threat and
   Quest icon on the target) as rows in the shape of Core's Edit Mode system options; setters
   write the profile (or the `threatShowNumeric` CVar), apply and refresh. `app.StyleOptions(entry)`
   flattens a frame's rows plus its linked frames'.
7. `options.lua`: General (the global layout), one tab per unit frame built from `StyleGroups`
   (hidden when the client lacks the frame), Profiles. `CVAR_UPDATE` refreshes threat changes.
8. `editmode.lua`: on enable, registers a collapsible Style section (key `unitframe-style`) per
   frame with `RegisterEditModeSystemOptions`. SeamlessUI draws it below the frame's own settings.
9. `src/layout/`: optional legacy layout (below).
10. Features, each a module reading `profile.unitFrames[key]`:
    - `src/healthcolor/healthcolor.lua`, `app.healthColor`: `healthBarColor` = `default`, `class`
      (players), `reaction` (`UnitSelectionColor`, grey when tap-denied) or `classReaction`.
      Post-hooks `UnitFrameHealthBar_Update`, swaps the green fill for the game's white
      `…-Bar-Health-Status` atlas and tints it; a `SetAtlas` hook puts the white atlas back when
      the game swaps it, `UNIT_FACTION` recolors. Pets take the player's class; disconnected or
      secret units keep the default. Restores only bars it colored.
    - `src/name/namedisplay.lua`, `app.nameDisplay`: `nameDisplay` = `full`, `first` or `last`
      for player characters (this client has surnames, joined by
      `CHARACTERNAME_SURNAME_SEPARATOR`). Post-hooks `UnitFrame_Update` and keeps the game's text
      to restore. Secret names are left alone.
    - `src/portrait/classicon.lua`, `app.classIcon`: `classIcon` shows `GetClassAtlas` on player
      portraits. Post-hooks `UnitFramePortrait_Update`; when off, restores only portraits it
      changed, unless the client's own CVars show a class icon there.
    - `src/pvpicon/pvpicon.lua`, `app.pvpIcon`: `hidePvPIcon` sets alpha 0 on the game's PvP
      indicator regions and the legacy layout's circle behind them. The game never changes their
      alpha, so no hook is needed; `GROUP_ROSTER_UPDATE` covers pooled party frames.
    - `src/questicon/targetquesticon.lua`: the optional target quest icon (`targetQuestIcon`:
      enabled, scale, offsets; off by default).
11. `SeamlessUnitframes.lua`: load diagnostic.

New per-frame settings need a default in `db.lua` and a row in `style.lua`, which puts them in both
the frame's tab and its Edit Mode Style section; global settings go in `options.lua`'s General tab.
Run `lua src/tests/unitframes-options.lua`.

## `src/layout/`: legacy layout

- `atlas.lua`: generated coordinates of the old artwork; regenerate with
  `python src/generate-legacy-unitframe-atlas.py`. The BLP sheets are in `assets/legacy/`; see
  `docs/unit-frame-layout.md` for provenance and limits.
- `layout.lua`: `app.legacyLayout`; inert until Legacy is selected.
- `geometry.lua`: fixed 70374/70425 definitions for player, target/focus/boss, pet/ToT, party and
  combo points.

Rules:

- Only named components are changed. No recursive frame/region scans, no render getters
  (`GetAtlas`, UVs, sizes) to infer a layout: atlas names, geometry and restoration come from the
  fixed definitions. `GetStatusBarTexture` only obtains the named bar's texture object.
- Validate frame paths and setters (`CheckPaths`/`CheckRegion`); missing or forbidden components
  log one deduplicated warning.
- Health colors resolve atlases with `HealthAtlas(bar, key)` and change them through
  `SetHealthAtlas`.
- Never write addon state onto protected frame tables or anchor protected frames to the
  target/focus health bars (secure templates); use ordinary visual bars and forward secret values
  directly. Layout changes and protected geometry wait out combat.
- Restore static atlases with `resetTexCoords = true`, reapplying fixed definitions, not observed
  state. Keep native root positions and scale; don't change draw/frame levels to hide health loss
  flashes.
- In Legacy the animated health loss bar uses the live bar's white fill and tint (Current restores
  its red); party health loss uses the Player atlas; unknown power types use the native mana fill.
- Apply repairs synchronously, never on the next frame. Cache only our own last writes and
  invalidate them on native setters.
- Treat gameplay values and frame fields as possibly secret: check access before comparing,
  branching, concatenating or indexing.

Run `lua src/test-legacy-layout.lua` (its render getters throw if called) and
`python -m unittest src/test_legacy_unitframe_atlas.py`.

## Conventions

- Modules are prototype-style Ace modules (`addon:NewModule("Name", module, …)`); a module that
  depends on profile settings defines `OnProfileRefresh`.
- `src/types.lua`: annotations for `app.*` and `SeamlessUnitframes.DB`; not in the TOC.
