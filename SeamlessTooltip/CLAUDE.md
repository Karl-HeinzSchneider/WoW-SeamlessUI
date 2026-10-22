# SeamlessTooltip

Optional tooltip addon: switchable enhancements of the game's tooltips. Settings and profiles
live in the `SeamlessTooltip` namespace in `SeamlessDB`; feature keys there are persistent (see Features and conventions).

## Ownership

- `src/core/`: lifecycle, defaults, feature registry, options, media and shared tooltip helpers.
  `unittooltip.lua` handles unit lookup, surname-aware names and secret checks; `border.lua`
  owns border painting and restoration.
- `src/features/`: one module per enhancement, grouped as All, Units, Items and Spells.
- The TOC defines load order. Only Core has a Profiles tab; `/seamlesstooltip reset` resets the
  shared suite profile.

## Client constraints

- Target/focus aura tooltips (`AuraButtonTooltip`) are forbidden. Only use the client's
  `AuraContainerInbound` delegates for backdrop styling; their content cannot be changed.
- Raid marker indices can be secret. Forward them to `SetSpriteSheetCell`; do not inspect them.
- Health-bar values go directly to secret-accepting APIs. Keep addon state in local tables,
  never on the secure status bar.
- Preserve line pre/post-call ordering to avoid duplicate native item, spell and aura lines.
  When aura data is restricted, retain the native line instead of constructing a replacement.
- Cursor anchoring leaves unit frames and forbidden owners alone; action-button anchoring
  takes precedence when both features are enabled.

## Features and conventions

A feature is one file in `src/features/` plus its TOC entry. It declares itself through
`app.features:NewFeature(key, info)`, where `key` is the persistent key in `profile.features`.
Never rename an existing key without migration. `info` declares category (`all`, `units`, `items`,
`spells`), name, description (`desc`), order, options; define enabled and setting defaults in `src/core/db.lua`.

Options are AceConfig args; each key maps to the same key in the feature's settings, read and
written by `core.FeatureGroup` (colors as `{ r, g, b, a }` tables) unless the option has its own
get/set. Each feature is an inline section on its category's tab: an Enable toggle with `desc`
under it, then its options, disabled while the feature is off.

Features are sorted by `order` within their tab. An option's own `disabled` replaces the
feature-off check, so include `not settings.enabled` in it.
Feature options need no manual edits in `options.lua`; define defaults in `src/core/db.lua`.

Features are nested Ace modules with AceEvent/AceHook. Register hooks/events in `OnEnable` and
undo frame changes in `OnDisable`. TooltipDataProcessor wrappers register once from `OnInitialize`
and skip callbacks when disabled or the tooltip is forbidden. Keep existing secret-value checks;
never write to the game's tooltip data tables or call Show from post-calls.

Read settings through `self:Settings()` at use time. `ApplySettings()` reapplies frame changes
when enabled settings or profiles change; `OnEnable` applies settings on activation.
Update the suite README when adding features.
