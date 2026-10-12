# SeamlessDamageMeter

Optional feature addon for WoW Forever (`16001`), requiring SeamlessCore.
`SeamlessDamageMeterDB` stores independent AceDB profiles containing window layouts and
statistic/session selections. Combat data stays owned by `C_DamageMeter`.

Load order: `core.lua` (lifecycle/database), `data.lua` (client API adapter),
`blizzard.lua` (turns tracking on, keeps the game's meter window hidden),
`windows.lua` (pooled frames and menus), `options.lua` (native Core settings).
`types.lua` contains annotations only and is not shipped.

Use the exported client API documentation under `../_data/BlizzardInterfaceCode` when
extending statistics. Combat names and amounts can be secret: pass them directly to
FontString and StatusBar setters. Do not compare, sort, concatenate or calculate with
them. Preserve the client's source order and do not modify returned data tables.
Only layout and selections belong in SavedVariables; never persist combat results.

One shared timer refreshes visible windows, with per-refresh caching for matching views.
Frames and rows are reused. Removing all windows must leave the profile empty; only a
fresh/reset profile creates a default window. Hidden windows are restored via `/sdm show`.

In-game verification: enable tracking, attack a target, add a second window and select
DPS or healing independently. Verify current/overall/history selection, scrolling with
a group, drag/resize, hide/show, removing the final window, reload persistence and profile
switch/reset. Clear Blizzard history while viewing an old fight and verify the empty
state. Check both in and out of combat, including restricted combat values.
