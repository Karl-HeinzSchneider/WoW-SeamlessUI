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
`app.features:NewFeature(key)`, where `key` is the persistent key in `profile.features`.
Never rename an existing key without migration. Page files own category placement, headings,
descriptions, order, controls and defaults.

Settings and defaults live in `src/options/general.lua`, `units.lua`, `items.lua` and
`spells.lua`, using the shared `defaults`/`config` page shape. Features declare behavior only.
Each page lists its sections explicitly as `feature = true` groups bound to `feature:Settings()`.
Keep persistent feature keys unchanged. An explicit disabled predicate must preserve the
feature-off check for subordinate controls and leave its Enable switch usable.

Features are nested Ace modules with AceEvent/AceHook. Register hooks/events in `OnEnable` and
undo frame changes in `OnDisable`. TooltipDataProcessor wrappers register once from `OnInitialize`
and skip callbacks when disabled or the tooltip is forbidden. Keep existing secret-value checks;
never write to the game's tooltip data tables or call Show from post-calls.

Read settings through `self:Settings()` at use time. `ApplySettings()` reapplies frame changes
when enabled settings or profiles change; `OnEnable` applies settings on activation.
Update the suite README when adding features.

All settings use the page contract documented in the root `CLAUDE.md`; do not register native AddOns panels.
