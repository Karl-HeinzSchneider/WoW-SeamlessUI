# SeamlessUnitframes

Optional unit-frame addon in the Seamless suite. Requires `SeamlessCore`; no embedded libraries
or separate minimap launcher. Users disable it through the game's AddOns screen and reload.
Existing `SeamlessUnitframesDB` settings and profiles are retained.

## TOC load order and ownership

1. `src/core/bootstrap.lua`: obtains the core through AceAddon and shares its logger.
2. `db.lua`: defaults for feature settings, including per-unit-frame health colors.
3. `ace.lua`: independent AceAddon and AceDB lifecycle, profile refresh callbacks and legacy
   `/seamlessunitframes` alias. `reset` resets only the feature profile; `loglevel` delegates to core.
4. `unitframes.lua`: registry of player, pet, target, target of target, focus, target of focus,
   and party frames, with `Exists`, `KeyOf` and `All` helpers.
5. `options.lua`: native controls in Settings > AddOns > Seamless > Unit Frames, using Core's
   panel helpers. Getters follow the active profile; CVAR_UPDATE refreshes external threat changes.
6. `src/healthcolor/healthcolor.lua`: feature implementation.
7. `SeamlessUnitframes.lua`: load diagnostic.

Every new runtime Lua/XML file must be listed in dependency order in the TOC.
New feature settings need defaults in `db.lua` and controls in `options.lua`.
Shared services belong in SeamlessCore. The old logLevel/minimap SavedVariables are no longer
used; shared preferences are stored independently in SeamlessCoreDB.

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

### Annotations (not in the TOC)

- `src/types.lua` â€” the private-table class `SeamlessUnitframes` (`app.*` fields) and
  `SeamlessUnitframes.DB`. When a file adds a member to `app`, add a matching `---@field` here.

## Conventions

- Prototype-style Ace modules: define methods on a local `module` table and pass it to
  `addon:NewModule("Name", module, â€¦)`; state lives on the object Ace returns (see
  `minimapbutton.lua`). A module that depends on profile settings defines `OnProfileRefresh`.
- New user settings get a default in `db.lua` and an entry in `options.lua`.
