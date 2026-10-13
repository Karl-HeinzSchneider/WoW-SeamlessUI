# Damage meter service and saved history

One combat-data service handles meter windows, hover panels, session menus, analysis and reports.
WoW Forever's `C_DamageMeter` collects combat; Seamless captures public completed results into
character-scoped SavedVariables independently of appearance profiles.

## Using it

- Completed fights are captured even with all windows hidden/inactive. Capture waits for
  restrictions to clear and runs in bounded steps. The header uses `S<number>` for saved fights.
- Session menus show date, duration, capture status and encounter outcome when available.
- Left-click a player/enemy bar for Fight, Spells, Targets/players and Copy report tabs.
  Scroll with the mouse wheel; select text and Ctrl+C to copy.
- Hover damage/DPS bars for targets, or enemy damage taken for contributors. Target percentages
  mean **share of your damage / share of enemy damage received**. Contributor percentages mean
  **share of that enemy's damage received**.
- Combat hover keeps the normal spell breakdown. Target sections appear only when data is available.
  Main and hover bars align amounts, rates and percentages in separate columns; restricted
  percentages stay blank. DPS/HPS views put rates first, including target rows.
- Saved session menus offer pinning, comparisons and deletion. Comparisons show first fight →
  second fight; differences are second minus first. Spells and Targets / players compare the
  corresponding breakdowns, with unavailable details explicitly labelled.
- Seamless > Damage Meter > History manages retention and saved fights. The default is
  50 recent unpinned fights; pinned fights are outside this limit. Clearing saved history
  does not reset Blizzard tracking.

## Modules

| File             | Responsibility                                                              |
| ---------------- | --------------------------------------------------------------------------- |
| `data.lua`       | Statistics, renderer facade and isolated Edit Mode samples                  |
| `live.lua`       | Combat APIs, availability, restrictions and live duration                   |
| `service.lua`    | Session resolution, shared queries/cache, subscriptions and history actions |
| `archive.lua`    | Public field allowlists, loaded-data validation, schema and retention       |
| `capture.lua`    | Discovery, metadata, bounded capture/retries and reload reconciliation      |
| `breakdowns.lua` | Enemy contribution indexes, comparisons and reports                         |
| `analysis.lua`   | Pooled detail/copy panel                                                    |
| `windows.lua`    | Meter rendering and service-backed selection/hover                          |

History lives under `SeamlessDamageMeterDB.char[character].combatHistory`. Incompatible schemas
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
- Public saved fights remain readable during combat, with tracking off, or without client APIs.
- Live spell hover accepts readable secret-bearing tables and passes restricted amounts directly
  to widgets. Local-player queries use the known public player GUID; other restricted identities
  are not guessed. Target analysis checks only its required public fields, even during combat.
- Native meter/CVar callbacks use isolated calls to original native functions; hiding uses OnShow,
  without hooking the timer pipeline. Reload after installing an update to clear prior hooks/taint.
- Imported client history uses the observation date. Encounter association requires in-game QA.
- Current and Overall remain client views. Arbitrary time slices, dungeon-wide aggregates,
  cast/crit counts and aura uptime are not fabricated from aggregate totals.
- Reports are copied by the player; opening them never sends chat messages automatically.

## Automated checks

```text
npm run check
lua src/tests/damage-meter-service.lua
lua src/tests/damage-meter-blizzard.lua
lua src/tests/damage-meter-windows.lua
lua src/tests/damage-meter-settings.lua
```

Tests cover shared reads, nested secret rejection, contributor aggregation, stale rows, delayed
restrictions, snapshots, serialization/reload, offline archives, generation resets, retries,
recaps, retention, deletion/reload, comparisons, reports, encounter metadata and damaged saves.
Window tests also exercise archived hover/analysis without APIs, and settings tests validate all tabs.

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
7. Disable tracking and switch/copy/reset appearance profiles. Saved history must remain intact.
8. Pin a fight and lower retention. Delete a fight, reload with client history intact, and
   confirm it is not silently restored. Clearing saved history must not reset the live meter.
9. Reset Blizzard history and fight again. Old archives remain, and the new fight gets a new ID.
   Expired/deleted selections must not silently show a different fight.
10. Open analysis, scroll long lists, copy reports and compare different-duration fights. Check
    percentage denominators and second-minus-first differences. No automatic chat messages.
11. Reload immediately after combat and during combat. Missing data must be labelled and no
    restricted-value errors should occur; only successfully captured results are guaranteed.
12. Recheck Edit Mode, collapse, resize, linked anchors, pinned local-player rows and ten slots.
    Enable/disable the native-meter hide option and tracking, including during combat. After reload,
    confirm no native secret-duration timer errors occur across combat transitions or Edit Mode.
