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
5. `src/features/blizzardposition.lua`: position adapter and widgets for the selected Blizzard
   unit frame. Reads `GetActiveLayoutSystemInfo().anchorInfo` from the live Edit Mode draft;
   Anchor/AnchorParent dropdowns expose nine anchor points. AnchorFrame offers only UIParent
   first, then Focus frame (`FocusFrame`), Minimap (`Minimap`), Player frame (`PlayerFrame`),
   Target frame (`TargetFrame`) in display-name order; invalid/cyclic targets are disabled.
   Existing anchors outside that list are displayed but never added as selector entries.
   Dropdown label fonts, widths and templates match LibEditMode. X/Y use the library's same
   `EditModeSettingSliderTemplate` with steppers and editable right-hand value. Clear only our
   own row's native setting callbacks before wiring position callbacks; never use library pools.
   Sliders span one screen each way (expanded for existing/typed offsets), with unit steps;
   numeric input accepts signed decimals in Edit Mode's scale-independent units. Validates
   names, finite numbers and anchor/parent cycles, then calls LibEditModeOverride's public
   `LoadLayouts`/`ReanchorFrame`. Mirrors that anchor into the live draft and calls the client
   frame's `ApplySystemAnchor`, preserving its saved baseline and other pending settings.
   Never calls `SaveOnly` or `ApplyChanges` while editing: those save the library's separate
   layout copy, and the latter closes Edit Mode. Native Save/Revert owns persistence. Preset
   and override layouts are read-only. Fields refresh while visible after dragging/nudging,
   but never replace focused input. As in LibEditMode, click the value to type, Enter commits,
   and Escape/focus loss discards typed input.
6. `src/features/blizzardeditmode.lua`: optional per-frame Edit Mode extension for Player,
   Target, Pet and Focus. Profile `blizzardEditMode` has a global `enabled` switch and per-frame
   `enabled`, `addPosition`, `addMoreOptions` switches. Add position displays the position
   widgets; Add more options only stores a preference for future controls. All extension
   switches default on; both optional-control switches default off.
   Uses removable AceHook post-hooks on the client dialog and an addon-owned UIParent panel
   below it; never joins native layout containers or accesses LibEditMode internals. The library
   has no public unregister/hide API for system extensions, so this panel is owned here to make
   the recovery switches effective immediately. Disabling globally removes hooks/events; disabling
   a frame hides its panel. Hides on dialog close, Edit Mode exit and combat; profile changes apply
   immediately. Supports Blizzard_EditMode loading after this addon.
7. `src/core/options.lua`: UI child panel under Seamless, with General, Blizzard Edit Mode
   Extensions and Profiles tabs. Extensions uses a global switch followed by one inline group
   per frame, each with Extend Edit Mode, Add position and Add more options.

Run `lua src/tests/blizzard-editmode.lua` for per-frame/global switches, placeholder preferences,
profile changes, late native UI loading, unsupported systems, combat and visibility guards.
Run `lua src/tests/blizzard-position.lua` for the actual vendored override integration,
anchor/numeric/cycle validation, preserving pending changes and the Revert baseline, scale,
focused input and stale-selection guards.

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
