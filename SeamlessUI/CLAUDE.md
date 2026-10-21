# SeamlessUI

Optional addon for general UI improvements, with shared suite profiles. Tooltip,
unit frame and chat features belong to their own addons; don't move Core tweaks or their settings
here without a migration.

## Load order and ownership

1. `src/core/bootstrap.lua`: gets Core and its shared logger.
2. `src/core/db.lua`: defaults.
3. `src/core/ace.lua`: AceAddon/AceDB lifecycle, profile callbacks and `/seamlessui` (`reset`,
   `loglevel` delegated to Core).
4. `src/features/xpbartooltip.lua`: replaces the player XP bar tooltip (bar and rested tick) through
   a secure post-hook on each `ExhaustionTick:ExhaustionToolTipText`, never replacing the method:
   rest state, XP, XP left, rested XP, time to max rested (the feature's `restedXPCap`/
   `restedXPRate`), then completed quests and their XP (`core:GetQuestLogSummary()`). Profile
   `xpBarTooltip` (`enabled`, `completedQuests`, `restedXPCap`, `restedXPRate`). Cap and rate
   controls live in this feature's options. `OnInitialize` migrates Core's former cap/rate
   overrides and `tweaks.questXPTooltip = false`, preserving existing UI settings and
   removing the obsolete Core tooltip keys. Core no longer hooks the XP tooltip.
5. `src/features/blizzardposition.lua`: position widgets for the selected Blizzard system (below).
6. `src/features/systemoptions.lua`: draws the sections other addons register with Core's
   `RegisterEditModeSystemOptions` (the Style sections of Castbar and Unitframes) under Core's
   collapsible headers, with LibEditMode's row templates.
7. `src/features/blizzardeditmode.lua`: the per-frame extension panel below the game's Edit Mode
   settings dialog (below).
8. `src/features/fpsdisplay.lua`: the FPS display (below).
9. `src/core/options.lua`: General, Blizzard Edit Mode Extensions (a global switch, then one inline
   group per frame with Extend Edit Mode, Add position and Add more options).

`src/types.lua`: annotations only, not in the TOC; add a field for every new `app` member.

Run `lua src/tests/xp-bar-tooltip.lua` for tooltip ownership and legacy settings migration.

## Blizzard Edit Mode extensions (`blizzardeditmode.lua`)

- The registry matches system enum plus subsystem enum/index (unit frames, action bars 1–8,
  stance/pet/possess bars, auras, XP/reputation containers, minimap and the other native systems),
  grouped as Unit frames, Action bars, Auras and Other frames. Entries stay hidden until the
  client's `registeredSystemFrames` has the frame; missing enums are safe.
- Profile `blizzardEditMode`: a global `enabled` and per frame `enabled` (default on),
  `addPosition` and `addMoreOptions` (default off; the latter only stores a preference for
  future controls). AceDB wildcard defaults cover new registry keys.
- An addon-owned UIParent panel below the dialog, attached with removable AceHook post-hooks
  (LibEditMode has no API to unregister system extensions). `panel:LayoutContent()` stacks
  Position and the registered sections and sizes the panel. Never join native layout containers
  or access LibEditMode internals.
- Hides on dialog close, Edit Mode exit and combat; supports Blizzard_EditMode loading late.

Run `lua src/tests/blizzard-editmode.lua`.

## Position controls (`blizzardposition.lua`)

- Reads `GetActiveLayoutSystemInfo().anchorInfo` from the live Edit Mode draft. In default
  position, managed frames and default action bars have a placeholder anchor, so it reads the live
  `GetPoint(1)`, follows unnamed containers to the named frame placing them and converts offsets
  to Edit Mode's units.
- AnchorFrame lists UIParent, the original Focus/Minimap/Player/Target choices and the named frames
  of the extension registry (`GetAnchorTargets`), by real `GetName()`; invalid, self and cyclic
  targets are disabled.
- X/Y use LibEditMode's slider template with an editable value (click to type, Enter commits,
  Escape discards).
- Validates names, numbers and anchor cycles, then uses LibEditModeOverride's `LoadLayouts`/
  `ReanchorFrame`, mirrors the anchor into the live draft and calls the frame's
  `ApplySystemAnchor`. Never call `SaveOnly` or `ApplyChanges` while editing (they save a separate
  layout copy, and the latter closes Edit Mode); native Save/Revert own persistence. Preset layouts
  are read-only.
- The Revert button compares position state with the frame's `savedSystemInfo` baseline, restores
  only that, revalidates cycles first and recomputes dirty flags so other pending edits stay.
- "Quick anchor to frame" starts Core's anchor picker with the AnchorFrame targets and applies the
  result through the same validated path.

Run `lua src/tests/blizzard-position.lua`.

## FPS display (`fpsdisplay.lua`)

- A Frames checkbox "FPS display" selects the anchor and previews the counter in Edit Mode. Its
  settings: "Show FPS on startup" (Core's preference), "Show latency", "White latency text",
  "Round FPS" (profile `fpsDisplay`), then Core's Position section. Positions are saved per native
  layout in the profile, including layout copy/rename/delete.
- With latency on, the native counter is faded to alpha 0 (it still drives Ctrl+R visibility) and an
  addon-owned two-row display replaces it, following its visibility. Round FPS also rounds the
  native counter through a `hooksecurefunc` on its `SetFormattedText`.
- Like the native counter it is parented to WorldFrame (unaffected by UI scale), so the UIParent
  anchor is sized by the effective-scale ratio. Never parent it to the counter, which sizes itself
  to its children.
- Disabling restores the counter's original anchors.

Run `lua src/tests/fps-display.lua`.

## Adding improvements

Feature modules go in `src/features/`, listed in the TOC in dependency order. Register hooks and
events in `OnEnable`, restore changes in `OnDisable`, read `app.db.profile` at use time and
implement `OnProfileRefresh` for profile-dependent behavior.

## Shared suite profiles

Settings now live in the `SeamlessUI` namespace of Core's `SeamlessDB`.
`src/core/db.lua` is the editable source of defaults (including feature defaults).
Core's `RegisterAddonDatabase` imports the legacy `SeamlessUIDB` once and
subscribes the addon to shared profile changes, copies and resets. Core's Profiles controls and
slash-command profile resets operate on the whole suite. Character/global data stay in the
namespace; the old standalone database is retained only for migration.
