# SeamlessUI

Optional addon for general UI improvements, with shared suite profiles. Tooltip,
unit frame and chat features belong to their own addons; don't move Core tweaks or their settings
here without a migration.

## Ownership

- `src/core/`: lifecycle, defaults and options.
- `src/features/xpbartooltip.lua`: secure post-hooks on XP/rested tooltips, with quest totals
  from Core. Owns cap/rate settings and migration of the former Core tooltip settings.
- `blizzardposition.lua`: binds Core's Position section to the selected system, over Core's
  position service.
- `systemoptions.lua`: places sections registered through `RegisterEditModeSystemOptions`, drawn by
  Core's `LayoutEditModeSections`.
- `blizzardeditmode.lua`: extension panel below native per-frame settings.
- `fpsdisplay.lua`: FPS/latency overlay and Edit Mode integration.

Run `lua src/tests/xp-bar-tooltip.lua` for tooltip ownership and migration.

## Blizzard Edit Mode extensions (`blizzardeditmode.lua`)

- The registry matches system enum plus subsystem enum/index (unit frames, action bars 1–8,
  stance/pet/possess bars, auras, XP/reputation containers, minimap and the other native systems),
  grouped as Unit frames, Action bars, Auras and Other frames. Entries stay hidden until the
  client's `registeredSystemFrames` has the frame; missing enums are safe.
- Profile `blizzardEditMode`: global `enabled`, `addPosition` and `addMoreOptions` (all default
  on; the latter only stores a preference for future controls), and per frame
  `enabled`, `addPosition`, `addMoreOptions` (all default on). A frame's effective value is the
  global switch and its own value. Options show only the global switches and one
  "<frame> - Extend Edit Mode" toggle per frame under its category header; the per-frame
  position/more-options values are internal. AceDB wildcard defaults cover new registry keys.
- Global `snapSettingsDialog` (default on): on each selection, a post-hook on
  `AttachToSystemFrame` moves the native settings dialog right of `EditModeManagerFrame` through
  `core:PlaceBesideEditModeManager`, and `core:SetEditModeDialogsBesideManager` does the same for
  Core's dialog of suite frames; dragging stays native. Only re-anchor the native dialog (it is
  unprotected and nothing reads its position): never write its fields or replace its methods.
- An addon-owned UIParent panel below the dialog, the public frame
  `SeamlessUIEditModeSystemSettingsDialog`, attached with removable AceHook post-hooks
  (LibEditMode has no API to unregister system extensions). `panel:LayoutContent()` draws
  Position and the registered sections with Core's `LayoutEditModeSections` and sizes the panel;
  every 0.15 s while shown, `RefreshEditModeSections` picks up native changes in place. Never join native layout containers
  or access LibEditMode internals.
- Hides on dialog close, Edit Mode exit and combat; supports Blizzard_EditMode loading late.

Run `lua src/tests/blizzard-editmode.lua`.

## Position controls (`blizzardposition.lua`)

- The position binding delegates reading, validation and applying to Core's shared
  `GetFramePositionService`; its selection/addPosition guards stay in SeamlessUI.
- Reads `GetActiveLayoutSystemInfo().anchorInfo` from the live Edit Mode draft. In default
  position, managed frames and default action bars have a placeholder anchor, so it reads the live
  `GetPoint(1)`, follows unnamed containers to the named frame placing them and converts offsets
  to Edit Mode's units.
- AnchorFrame lists UIParent, the original Focus/Minimap/Player/Target choices and the named frames
  of the extension registry (`GetAnchorTargets`), by real `GetName()`; invalid, self and cyclic
  targets are disabled.
- `position:GetSection(system)` binds Core's `CreateEditModePositionSection` to the selected
  system (one section per selection); Core draws the rows. X/Y and Scale have an editable value
  (click to type, Enter commits, Escape discards).
- Scale is the first row, like the settings panel's "Position and scale" group: the same slider
  in the panel's units (1 = 100 %), bound to the system's native percentage setting (`FrameSize`
  for unit frames, `IconSize` for action bars and auras, `BarSize` for the cast bar, `Scale` for
  swing timers, otherwise `Size`) with its range and step, written through Core's `ApplySetting`
  so it stays in the native draft. Frames without that setting (or while Edit Mode hides it)
  show their scale greyed out.
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
