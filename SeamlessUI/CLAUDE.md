# SeamlessUI

Optional addon for general UI improvements. Requires Seamless and remains internal until
features are ready for public release.

## Load order and ownership

1. `src/core/bootstrap.lua`: obtains Core and its shared logger.
2. `src/core/db.lua`: defaults for independent `SeamlessUIDB` profiles.
3. `src/core/ace.lua`: AceAddon/AceDB lifecycle, profile refresh callbacks and `/seamlessui`.
4. `src/features/xpbartooltip.lua`: replaces the player XP bar tooltip (bar and rested tick) by
   raw-hooking each `ExhaustionTick:ExhaustionToolTipText`: rest state, XP, XP left, rested XP and
   time to max rested (cap and rate from Core's `tweaks.restedXPCap`/`restedXPRate`), then
   completed quests and their XP from `core:GetQuestLogSummary()`. Profile `xpBarTooltip`
   (`enabled`, `completedQuests`, both on). `OnInitialize` migrates Core's former
   `tweaks.questXPTooltip = false` into the same-named UI profile and clears it from Core.
5. `src/core/options.lua`: UI child panel under Seamless, with General and Profiles tabs.

`src/types.lua` contains annotations only and is not loaded by the TOC. Add a field there
whenever a runtime file adds a member to the private `app` table.

## Adding improvements

Put feature modules in `src/features/` and list runtime files in dependency order in the TOC.
Use the shared Core options API and logger. Register hooks/events in module `OnEnable`,
restore changes in `OnDisable`, and read `app.db.profile` at use time. Modules with
profile-dependent behavior implement `OnProfileRefresh` to reapply it after profile changes.
Keep general UI improvements here; tooltip, unit-frame and chat features belong to their
existing addons. Do not move existing Core tweaks or their settings without a migration.

`/seamlessui` opens the panel, `/seamlessui reset` resets this addon's current profile,
and `/seamlessui loglevel <level>` delegates to Core's shared logging setting.
