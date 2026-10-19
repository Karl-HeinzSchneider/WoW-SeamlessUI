# SeamlessUI

Optional addon for general UI improvements. Requires Seamless and remains internal until
features are ready for public release.

## Load order and ownership

1. `src/core/bootstrap.lua`: obtains Core and its shared logger.
2. `src/core/db.lua`: defaults for independent `SeamlessUIDB` profiles.
3. `src/core/ace.lua`: AceAddon/AceDB lifecycle, profile refresh callbacks and `/seamlessui`.
4. `src/features/xpbartooltip.lua`: replaces the player XP bar tooltip (bar and rested tick): a
   secure post-hook on each `ExhaustionTick:ExhaustionToolTipText` re-anchors (clearing the
   default lines) and rebuilds it, never replacing the secure method: rest state, XP, XP left, rested XP and
   time to max rested (cap and rate from Core's `tweaks.restedXPCap`/`restedXPRate`), then
   completed quests and their XP from `core:GetQuestLogSummary()`. Profile `xpBarTooltip`
   (`enabled`, `completedQuests`, both on). `OnInitialize` migrates Core's former
   `tweaks.questXPTooltip = false` into the same-named UI profile and clears it from Core.
5. `src/features/blizzardeditmode.lua`: optional per-frame Edit Mode extension for Player,
   Target, Pet and Focus. Profile `blizzardEditMode` has a global `enabled` switch and per-frame
   `enabled`, `addPosition`, `addMoreOptions` switches. The last two only store preferences for
   future controls. All extension switches default on; both future-control switches default off.
   Uses removable AceHook post-hooks on the client dialog and an addon-owned UIParent panel
   below it; never joins native layout containers or accesses LibEditMode internals. The library
   has no public unregister/hide API for system extensions, so this panel is owned here to make
   the recovery switches effective immediately. Disabling globally removes hooks/events; disabling
   a frame hides its panel. Hides on dialog close, Edit Mode exit and combat; profile changes apply
   immediately. Supports Blizzard_EditMode loading after this addon.
6. `src/core/options.lua`: UI child panel under Seamless, with General, Blizzard Edit Mode
   Extensions and Profiles tabs. Extensions uses a global switch followed by one inline group
   per frame, each with Extend Edit Mode, Add position and Add more options.

Run `lua src/tests/blizzard-editmode.lua` for per-frame/global switches, placeholder preferences,
profile changes, late native UI loading, unsupported systems, combat and visibility guards.

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
