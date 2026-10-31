# Damage meter service and saved history

One combat-data service handles meter windows, hover panels and session menus.
WoW Forever's `C_DamageMeter` collects combat; Seamless captures public completed results into
character-scoped SavedVariables independently of appearance profiles.

**Session saving is switched off** (`combatService.saveSessions = false` in `service.lua`). Only
client sessions are displayed; existing saved history is preserved but not loaded, capture is
skipped and the History page is hidden. The rest of this document describes the archive for
when saving is switched back on.

## Using it

- History's Maximum saved segments setting defaults to 50 and accepts 1–1,000 per character.
  The oldest saved segment is deleted before adding one beyond the limit, including pinned
  segments. Lowering the limit removes excess segments immediately; 1,000 is the hard cap.
- Select a saved fight to delete it or delete every older segment, from History or the session
  menu. Both also offer clearing all saved segments. These actions leave native tracking running.
- Completed fights are captured even with all windows hidden/inactive. Capture waits for
  restrictions to clear and runs in bounded steps. The header uses `S<number>` for saved fights.
- Session menus show date, duration, capture status and encounter outcome when available.
- Hover damage/DPS bars for targets, or enemy damage taken for contributors. Target percentages
  mean **share of your damage / share of enemy damage received**. Contributor percentages mean
  **share of that enemy's damage received**.
- Combat hover uses a spell-only panel and never queries target or contributor analysis.
  After combat, a separate pooled panel adds target sections when data is available.
  The panel switches automatically when combat starts or ends while a row stays hovered.
  Main and hover bars align amounts, rates and percentages in separate columns; restricted
  percentages stay blank. DPS/HPS views put rates first, including target rows.
- Saved session menus offer pinning and deletion.
- Seamless > Damage Meter > History manages retention and saved fights.

## Modules

| File             | Responsibility                                                              |
| ---------------- | --------------------------------------------------------------------------- |
| `data.lua`       | Statistics, renderer facade and isolated Edit Mode samples                  |
| `live.lua`       | Combat APIs, availability, restrictions and live duration                   |
| `service.lua`    | Session resolution, shared queries/cache, subscriptions and history actions |
| `archive.lua`    | Public field allowlists, loaded-data validation, schema and retention       |
| `capture.lua`    | Discovery, metadata, bounded capture/retries and reload reconciliation      |
| `breakdowns.lua` | Enemy contribution indexes                                                  |
| `windows.lua`    | Meter rendering and service-backed selection/hover                          |

History lives in the `SeamlessDamageMeter` namespace's `char[character].combatHistory`. Incompatible schemas
are preserved for recovery and malformed records quarantined. Only explicitly allowed public
scalar fields and owned tables are saved; no frames/functions or live API references.

Archive IDs are independently allocated. Client IDs are scoped to a tracking generation.
Selections bind to archive IDs after capture; legacy unscoped client selections expire
conservatively. Reload reconciliation requires matching public contents, name and client ID
from the preceding generation. Explicit resets prevent reconciliation even for identical results.
The API supplies no globally permanent fight ID: identical results after an unobserved reset/relog
cannot be distinguished with certainty.

Capture settles for two seconds, processes eight steps per 0.2-second tick, and retries unavailable
data up to 30 times. Each category and source detail is validated independently; partial snapshots
retain usable results and upgrade in place. Totals are re-read before committing categories, and
update events restart drafts. Death recaps save copied events and maximum health. Known deleted
records are suppressed during reload reconciliation while the same client history survives.

Enemy relationships come from EnemyDamageTaken source details. Repeated contributor rows are
combined without mutating API tables. Indexes are shared for player → enemy and enemy → player
queries. Non-reconciling contributions are labelled incomplete. Available creature identities are
retained; units already combined by the client and same-name contributors cannot be reliably split.

## Limits

- Successfully captured public completed fights survive normal reload/relog. Immediate reloads,
  disconnects or restricted combat can leave incomplete data. SavedVariables are game-written,
  so this is not continuous crash-safe disk storage.
- Live reads use the API's availability result, independently of `damageMeterEnabled`.
- Public saved fights remain readable during combat, with the native UI off, or without client APIs.
- Live spell hover accepts readable secret-bearing tables and passes restricted amounts directly
  to widgets. Local-player queries use the known public player GUID; other restricted identities
  are not guessed. Target analysis checks only its required public fields, even during combat.
- Blizzard's own meter is never hooked, called, hidden or written to (see
  `SeamlessDamageMeter/CLAUDE.md`); its on/off setting is only changed in the game's settings.
- Imported client history uses the observation date. Encounter association requires in-game QA.
- Current and Overall remain client views. Arbitrary time slices, dungeon-wide aggregates,
  cast/crit counts and aura uptime are not fabricated from aggregate totals.

## Automated checks

```text
npm run check
lua src/tests/damage-meter-service.lua
lua src/tests/damage-meter-blizzard.lua
lua src/tests/damage-meter-windows.lua
lua src/tests/damage-meter-settings.lua
lua src/tests/damage-meter-threat.lua
```

Tests cover shared reads, nested secret rejection, contributor aggregation, stale rows, delayed
restrictions, snapshots, serialization/reload, offline archives, generation resets, retries,
recaps, retention, deletion/reload, encounter metadata and damaged saves.
Window tests also exercise archived hover without APIs, and settings tests validate all tabs.

## In-game acceptance checklist

1. Record a single-target fight, wait until saved, select it, reload, then relog. Verify totals,
   rates, spell details, target contributions and saved selection survive both.
2. Hide/deactivate every window, fight, then show a window. Confirm collection continued.
3. Compare AoE damage, enemy totals and contributions with Details for the same fight. Include
   pets, summons, identical enemy names and repeated contributor rows; note client grouping.
4. Hover your player row while fighting a normal mob solo. Spell names, damage and rates must show
   during combat. Targets appear when their required fields are public, with no restriction warning
   replacing spells. Repeat in a group and check that unavailable identities are not guessed.
   Public archived fights must remain readable during later combat.
5. Record a boss kill/wipe, rapid successive pulls, and a death near encounter end. Check
   encounter name, outcome, instance, dates and durations.
6. Archive a death, reload/relog and reset Blizzard history. Its saved recap must still work.
7. Disable the native meter UI, enable Details alongside Seamless, and fight a new mob.
   Verify fresh live totals, spell hover and saved history still update, then switch/copy/reset
   appearance profiles. Saved history must remain intact.
8. Pin the oldest fight and lower retention; verify it is removed first. Delete a fight, reload
   with client history intact, and confirm it is not silently restored. Clearing saved history must not reset the live meter.
9. Reset Blizzard history and fight again. Old archives remain, and the new fight gets a new ID.
   Expired/deleted selections must not silently show a different fight.
10. Hover combat bars to check spell and target breakdowns, left-click one for the in-window
    breakdown and right-click to return.
11. Reload immediately after combat and during combat. Missing data must be labelled and no
    restricted-value errors should occur; only successfully captured results are guaranteed.
12. Recheck Edit Mode, collapse, resize, linked anchors, pinned local-player rows and all six
    slots. Toggle the native meter in the game's settings, including during combat. After reload,
    confirm no native secret-duration timer errors occur across combat transitions or Edit Mode.
