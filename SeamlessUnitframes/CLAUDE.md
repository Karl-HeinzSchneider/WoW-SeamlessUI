# SeamlessUnitframes

Optional unit-frame addon in the Seamless suite. Requires `Seamless`; no embedded libraries
or separate minimap launcher. Users disable it through the game's AddOns screen and reload.
Existing `SeamlessUnitframesDB` settings and profiles are retained.

## TOC load order and ownership

1. `src/core/bootstrap.lua`: obtains the core through AceAddon and shares its logger.
2. `db.lua`: defaults for feature settings, including per-unit-frame health colors.
3. `ace.lua`: independent AceAddon and AceDB lifecycle, profile refresh callbacks and legacy
   `/seamlessunitframes` alias. `reset` resets only the feature profile; `loglevel` delegates to core.
4. `unitframes.lua`: registry of player, pet, target, target of target, focus, target of focus,
   and party frames, with `Exists`, `KeyOf` and `All` helpers. Each entry names its
   `Enum.EditModeUnitFrameSystemIndices` `system`, or `linkedTo` the frame whose Edit Mode
   settings show it (target of target under target, target of focus under focus). `players` marks
   frames that show player characters (name display, class icon); `pvpIcon` frames with a PvP icon.
   `Get(key)` returns an entry.
5. `style.lua`: the single source of every per-frame setting. `app.StyleGroups(key)` returns a
   frame's groups (Name and Portrait where `players`, Health bar, PvP where `pvpIcon`; for the target
   also Threat and Quest icon) of rows in the shape of
   Core's Edit Mode system options; setters write the profile (or the `threatShowNumeric` CVar),
   apply the change and refresh the options and Edit Mode. `app.StyleOptions(entry)` flattens a
   frame's rows and appends its linked frames' rows.
6. `options.lua`: the Unit Frames panel (Settings > AddOns > Seamless) via `core:RegisterOptions`:
   General (the global unit frame layout), one tab per unit frame (hidden when the client lacks the
   frame) built from `StyleGroups` as inline groups, Profiles. Getters follow the active profile;
   CVAR_UPDATE refreshes external threat changes.
7. `editmode.lua`: on enable, registers each frame with an Edit Mode system with Core's
   `RegisterEditModeSystemOptions` as a collapsible Style section (collapse key
   `unitframe-style`) built from `StyleOptions`. SeamlessUI draws it in its extended window below
   the frame's own settings, so it needs SeamlessUI with that frame's Edit Mode extension on; it is
   never a window of its own. The section leaves while the addon is disabled.
8. `src/layout/atlas.lua`, `layout.lua`, `geometry.lua`: optional legacy layout.
9. `src/healthcolor/healthcolor.lua`: feature implementation.
   `src/name/namedisplay.lua`: `app.nameDisplay`, the name of player characters (`UnitIsPlayer`;
   NPCs are never changed) on each unit frame per
   `profile.unitFrames[key].nameDisplay`: `full` (the game's text), `first` or `last`. This client
   gives characters a first name and optional surname (`UnitName` returns both, or one string
   joined by `Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR`); a unit
   without a surname keeps its first name. It post-hooks `UnitFrame_Update` (every unit frame sets its
   name there), remembers the game's text in a local table keyed by frame and puts it back for
   `full` and on disable. Secret names are left alone.
   `src/portrait/classicon.lua`: `app.classIcon`, per `classIcon` a player character's
   `GetClassAtlas` icon on the portrait. Post-hooks `UnitFramePortrait_Update`; when switched off it
   calls `SetPortraitTexture` only on portraits it changed, unless the client's own
   `UnitFrame_ShouldReplacePortrait` CVars show a class icon there.
   `src/pvpicon/pvpicon.lua`: `app.pvpIcon`, per `hidePvPIcon` sets alpha 0 on the regions the
   game's PvP indicator uses (`PlayerFrame_GetPvPIndicatorElements`, the target/focus
   `GetPvPIndicatorElements`, the party `PartyMemberOverlay.PVPIcon`) and on the circle the Legacy
   layout draws behind an icon (`legacyLayout:PvPBackground(icon)`; a newly created circle refreshes
   this module); the game never changes their alpha, so no hook is needed. Refreshes on `GROUP_ROSTER_UPDATE` for pooled party frames.
   `src/core/questicons.lua` reads unfinished Blizzard tooltip objectives and matches quest-log
   objective types; `src/questicon/targetquesticon.lua` manages the optional target icon and events.
   The `targetQuestIcon` profile settings control enablement, scale and offsets (disabled by default).
10. `SeamlessUnitframes.lua`: load diagnostic.

Every new runtime Lua/XML file must be listed in dependency order in the TOC.
New per-frame settings need defaults in `db.lua` and rows in `style.lua`, which puts them in both the
frame's tab and its Edit Mode Style section. Run `lua src/tests/unitframes-options.lua`.
Shared services belong in Seamless. The old logLevel/minimap SavedVariables are no longer
used; shared preferences are stored independently in SeamlessDB.

### `src/healthcolor/`

- `healthcolor.lua` â€” `app.healthColor`: health bar colors on the game's own unit frames, per frame
  from `profile.unitFrames[key].healthBarColor`: `default` (the game's green), `class` (players),
  `reaction` (`UnitSelectionColor`, the game's own unit reaction colors â€” not the muted
  `FACTION_BAR_COLORS` â€” grey for a tap-denied mob) or `classReaction`
  (class for players, reaction for the rest). It post-hooks `UnitFrameHealthBar_Update`, swaps
  the bar's green fill atlas for the game's white `â€¦-Bar-Health-Status` variant and tints it; a
  hook on each bar texture's `SetAtlas` puts the white atlas back when the game swaps it (target
  classification, vehicles), and `UNIT_FACTION` recolors on reaction changes. A pet takes the
  player's class; disconnected players and units whose class or reaction is secret keep the
  default color. It restores only the bars it colored. `Refresh()` reapplies after a setting
  changed.

### `src/layout/`

- `atlas.lua`: generated old exported artwork coordinates; regenerate with
  `python src/generate-legacy-unitframe-atlas.py`. Approved original BLP sheets live
  in `assets/legacy/`. See `docs/unit-frame-layout.md` for provenance and limitations.
- `layout.lua`: profile-aware `app.legacyLayout`; Current is inert until Legacy is
  selected. Only named components are modified. No recursive frame/region scans
  or runtime rendering snapshots: atlas names, geometry and restoration come from
  fixed build definitions. Never call render getters to infer a layout.
- `geometry.lua`: explicit 70374 and 70425 player, target/focus/boss, pet/ToT,
  party and combo definitions. Never write addon state onto protected frame tables.
- Validate nested frame paths and setter methods (`CheckPaths`/`CheckRegion`).
  Missing/forbidden components produce deduplicated shared logger warnings.
  Callbacks use the Ace instance, not its separate prototype.
- Health colors use `HealthAtlas(bar, key)` to resolve a known family. Never read
  `Texture:GetAtlas()`. Changes go through `SetHealthAtlas`, which uses the owning
  bar setter and standalone legacy fills. Native atlas-hook arguments are ignored.
- `GetStatusBarTexture` obtains only the named bar's texture object. Do not inspect
  its rendered values, UVs or dimensions. Layout selection and protected geometry wait out combat;
  unprotected target/focus health visuals mirror native setters, forwarding secret values directly;
  health color/fill updates use constant arguments without inspecting bar values.
- Restore static atlases with `resetTexCoords = true`. Reapply fixed current
  definitions, not observed client state. Keep native root positions and scale.
  Do not change draw/frame levels to work around health-loss flashes. In Legacy,
  the animated loss bar uses the live bar's white fill and class/reaction tint;
  native alpha/timing stays intact. Restore its native red tint in Current.
- Apply native-update repairs synchronously. Do not queue texture repair for the
  next rendered frame. Named static atlas hooks rebind old artwork immediately,
  without protected geometry changes in combat. Target/focus native health bars inherit secure
  templates: use ordinary visual bars, never anchor protected frames to them. Cache only our own last writes, invalidate
  on native setters, and avoid replacing unchanged health fills on value updates.
- Party temporary health loss uses the Player atlas (CharacterFrameOnParty for
  that style), as in PartyFrameTemplates.xml. Unknown power types use the native
  mana fallback; they are not unexpected errors.
- Treat gameplay results and frame fields as potentially secret; check access
  before comparison, branching, concatenation or indexing. Inaccessible
  power and classification data are skipped with a deduplicated diagnostic.
- Run `lua src/test-legacy-layout.lua`: its rendering getters throw if called.
  Also run `python -m unittest src/test_legacy_unitframe_atlas.py`.

### Annotations (not in the TOC)

- `src/types.lua` â€” the private-table class `SeamlessUnitframes` (`app.*` fields) and
  `SeamlessUnitframes.DB`. When a file adds a member to `app`, add a matching `---@field` here.

## Conventions

- Prototype-style Ace modules: define methods on a local `module` table and pass it to
  `addon:NewModule("Name", module, â€¦)`; state lives on the object Ace returns (see
  `minimapbutton.lua`). A module that depends on profile settings defines `OnProfileRefresh`.
- New user settings get a default in `db.lua` and a row in `style.lua` (or, when global, an entry in
  `options.lua`'s General tab).
