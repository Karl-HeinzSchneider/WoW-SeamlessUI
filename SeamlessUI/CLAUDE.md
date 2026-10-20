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
5. `src/features/fpsdisplay.lua`: custom FPS anchor registered with shared Edit Mode. The
   Frames checkbox "FPS display" controls anchor selection and the temporary counter preview.
   Hiding the preview restores normal counter visibility. The frame's own settings contain
   "Show FPS on startup" (Core's existing preference, default off); changing it also updates
   visibility when the preview is hidden or Edit Mode exits, and "Show latency" (profile
   `fpsDisplay.showLatency`, default off). With latency on, the native counter is faded out
   (alpha 0, still driving Ctrl+R visibility) and an addon-owned two-row display replaces it:
   "FPS:" and "MS:" left, framerate and world latency (`GetNetStats`, green below 100 ms, yellow
   below 250 ms, red above; "White latency text", profile `fpsDisplay.whiteLatency`, default off,
   uses the counter's text color instead) right-aligned. Copies the counter's font (`GetFont`)
   and text color so it matches the default size. Values cap at 999.9/999, so the display is sized once
   for "999.9" and the Edit Mode anchor takes that size. Never parent it to the counter: the
   counter sizes itself to its children, which pushed the FPS text out of its box. It follows
   the counter's visibility through OnShow/OnHide hooks and updates four times a second while shown. Ctrl+R still controls the native
   counter outside Edit Mode. Positions are stored per native layout in the current UI profile, including layout
   copy/rename/delete handling. Disabling restores the counter's original anchors.
6. `src/features/blizzardposition.lua`: position adapter and widgets for the selected Blizzard
   system. Reads `GetActiveLayoutSystemInfo().anchorInfo` from the live Edit Mode draft, except
   in default position: managed frames (Pet frame, cast bar, ...) and default action bars are
   placed by client layout code and their anchorInfo is a placeholder (CENTER of UIParent), so it
   reads the live `GetPoint(1)`, follows unnamed/managed containers to the named frame placing
   them (Pet frame shows PlayerFrame) and converts offsets to Edit Mode's units;
   Anchor/AnchorParent dropdowns expose nine anchor points. AnchorFrame keeps UIParent first
   and the original Focus/Minimap/Player/Target choices, then includes named frames from the
   extension registry through `GetAnchorTargets`. Uses actual `GetName()`/global resolution,
   rather than guessed names for composite containers. Targets remain available when their
   extension switch is off. Deduplicates persistent names, sorts translated display names,
   disambiguates repeated labels with the technical frame name and uses a scrollable menu;
   invalid/self/cyclic targets are disabled. Minimap keeps its original `Minimap` target.
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
   The native-style Revert changes button watches position state against the frame's native
   `savedSystemInfo` baseline, including secondary anchor/default-position metadata. It restores
   only that state, preserving unrelated settings and pending edits on other frames. Restore
   targets are revalidated for cycles before any mutation. Recomputes frame/global dirty flags
   after applying, so position-only Revert clears pending state while other edits remain dirty.
   No persistent helper text; the footer shows errors only when an action fails.
   The Revert button uses half the control area's width and is centered, matching the native
   compact button. All display text uses Core's shared `Seamless` AceLocale catalogue, including
   anchor labels and errors; frame/anchor IDs stay unchanged. AnchorFrame sorts translated
   display names alphabetically after UIParent. Add new English keys under shared/Frames or
   SeamlessUI in `Seamless/locales/enUS.lua`, then run `npm run locales:sync`.
7. `src/features/blizzardeditmode.lua`: optional per-frame Edit Mode extensions. Its registry
   matches system enum plus subsystem enum/index, rather than assuming every selection is a
   unit frame. Supports Player/Target/Pet/Focus/Party/Raid/Boss/Arena, action bars 1–8,
   stance/pet/possess bars, buffs/debuffs, the two XP/reputation containers, minimap and other
   native UI systems (cast/encounter/extra-ability bars, tracker, micro menu, bags, vehicle controls,
   loot, tooltip, durability, timers, chat, talking head, personal resources, totems, raid warning,
   group finder, loss of control, archaeology and swing timers).
   Options are grouped under Unit frames, Action bars, Auras and Other frames. Entries/headings
   are hidden until a matching frame exists in the client's `registeredSystemFrames`; missing
   enum groups are safe. Linked frames without their own Edit Mode system have no separate entry.
   XP/reputation entries identify native containers, not a fixed kind of content.
   Profile `blizzardEditMode` has a global `enabled` switch and per-frame
   `enabled`, `addPosition`, `addMoreOptions` switches. Add position displays the position
   widgets; Add more options only stores a preference for future controls. All extension
   switches default on; both optional-control switches default off.
   AceDB wildcard defaults add independent settings for new registry keys without resetting
   existing frame preferences. Position editing honors the selected system's `isLocked` state.
   Uses removable AceHook post-hooks on the client dialog and an addon-owned UIParent panel
   below it; never joins native layout containers or accesses LibEditMode internals. The library
   has no public unregister/hide API for system extensions, so this panel is owned here to make
   the recovery switches effective immediately. Disabling globally removes hooks/events; disabling
   a frame hides its panel. Hides on dialog close, Edit Mode exit and combat; profile changes apply
   immediately. Supports Blizzard_EditMode loading after this addon.
8. `src/core/options.lua`: UI child panel under Seamless, with General, Blizzard Edit Mode
   Extensions and Profiles tabs. Extensions uses a global switch followed by one inline group
   per frame, each with Extend Edit Mode, Add position and Add more options.

Run `lua src/tests/blizzard-editmode.lua` for per-frame/global switches, placeholder preferences,
profile changes, late native UI loading, unsupported systems, combat and visibility guards.
Run `lua src/tests/blizzard-position.lua` for the actual vendored override integration,
anchor/numeric/cycle validation, preserving pending changes and the Revert baseline, scale,
focused input and stale-selection guards.
Also covers the Revert button/baseline, preserving unrelated edits/dirty flags, transitive and
secondary-anchor cycles, incoming followers, and cycle rejection during Revert.

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
