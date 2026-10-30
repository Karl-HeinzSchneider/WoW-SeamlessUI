# SeamlessUI

Optional addon for general UI improvements, with shared suite profiles. Tooltip,
unit frame and chat features belong to their own addons; don't move Core tweaks or their settings
here without a migration.

## Ownership

- `src/core/`: lifecycle, defaults and options.
- `blizzardposition.lua`: binds Core's Position section to the selected system, over Core's
  position service.
- `systemoptions.lua`: places sections registered through `RegisterEditModeSystemOptions`, drawn by
  Core's `LayoutEditModeSections`.
- `blizzardeditmode.lua`: our sections below native per-frame settings, in Core's settings window.
- `fpsdisplay.lua`: FPS/latency overlay and Edit Mode integration.

## Blizzard Edit Mode extensions (`blizzardeditmode.lua`)

- The registry matches system enum plus subsystem enum/index (unit frames, action bars 1–8,
  stance/pet/possess bars, the left and right endcaps, auras, XP/reputation containers, minimap and the other native systems),
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
- Our sections (Position and the registered system options) show in Core's settings window
  (`SeamlessEditModeSettingsDialog`), attached below the dialog with
  `core:AttachEditModeSettingsWindow` and hidden with `core:DetachEditModeSettingsWindow`. Core
  draws them with its row renderer and polls native changes; this module only builds the
  sections. The selected frame's `src/options/` config explicitly declares `buttonSection` and
  `editModeFrame`. Core resolves that declaration through `GetEditModeFrameButtonSection`;
  this module binds Revert and Reset Position to the guarded native position service and passes
  the explicit footer to the same window. No declaration means no footer. Revert is never
  inserted automatically into the Position controls. Removable AceHook post-hooks drive it: `AttachToSystemFrame`, the dialog's
  OnShow/OnHide, and `EditModeManagerFrame.SelectSystem`, which runs after LibEditMode's own hook
  (that one hides and resets Core's window on every native selection). Never join native layout
  containers or access LibEditMode internals.
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
  so it stays in the native draft. Frames without one use a binding a feature registered with
  `core:RegisterEditModeSystemScale` (the action bar endcaps), snapped to its step; without
  either (or while Edit Mode hides the setting) the row shows the frame's scale greyed out.
- Validates names, numbers and anchor cycles, then uses LibEditModeOverride's `LoadLayouts`/
  `ReanchorFrame`, mirrors the anchor into the live draft and calls the frame's
  `ApplySystemAnchor`. Never call `SaveOnly` or `ApplyChanges` while editing (they save a separate
  layout copy, and the latter closes Edit Mode); native Save/Revert own persistence. Preset layouts
  are read-only.
- The footer Revert button combines Core's custom setting snapshots with a full native system
  comparison against `savedSystemInfo`. It restores custom values and the saved native system,
  revalidates changed anchors first, and keeps other frames' pending edits. The Position binding's
  own Revert remains limited to position state.
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

`features/combinedbags.lua` registers an addon-owned selection outline for the native combined
bags window in Edit Mode. The Frames checkbox defaults off and controls only that outline; inventory visibility,
parenting, scale and item logic remain native. Positions live in profile `combinedBags.layouts`,
with layout copy/rename/delete support. A secure post-hook on `UpdateContainerFrameAnchors`
reapplies only saved positions, converting offsets for the native bag scale; other bags keep
their native anchors. Reset removes the override and restores Blizzard placement. Combat defers
position writes, including restoration when disabled. The per-frame "Keep position in combat"
option (`positionInCombat`, default off) reapplies saved bag positions in combat only when
the bag is unprotected; it never updates the Edit Mode outline in combat.
Run `lua src/tests/combined-bags.lua`.

`features/minimap.lua` owns minimap visibility. `options/minimap.lua` declares the page and
Style controls; Edit Mode derives its Style rows from that declaration. New visibility settings
live in profile `minimap`; the existing `hideMinimapDayNight` key stays at its original path.
Individual switches combine independently. `hideHeader` overrides the header buttons and status
indicators. `square` (default off) uses the supplied `media/minimap_square_arrow.blp` border,
fitting its off-center opening to the map and replacing the mask with a square. Button addons
read the public `GetMinimapShape()` compatibility API (`SQUARE`
or `ROUND` from the current profile); disabling restores the previous provider if still owned.
The border uses the native compass texture so the engine rotates it with the square mask.
Its UVs center the artwork's opening on the map's rotation pivot. Never change the minimap's
dimensions or scale to accommodate this style: button addons use its native geometry.
With Rotate Minimap enabled, use the native round style and report `ROUND` to button addons;
retain the square preference and reapply it when rotation stops. A rotating square has unresolved
client rendering gaps and must not be enabled. Disabling restores native UVs, anchors, art and mask. `hideHeader`
fits the cluster's fixed bounds to the scaled map container and removes its header
anchor gap. Native scale, header placement and rotation updates reapply that compact layout.
Restoring the header restores the native layout sizing and current header placement; disabling
the addon restores frames it hid. Run `lua src/tests/minimap-day-night.lua`.

`editmodekeyboard.lua` owns the Blizzard Editmode option "Pass unused Edit Mode keys through"
(`editModeKeyboard`, default on), independently of the Edit Mode extensions toggle. Native
key handlers stay intact; arrows, Escape and Print Screen are consumed, other keys propagate.
A disabled profile installs no hooks or events and never touches the native dialog. Enabling
activates the module; disabling restores native capture and deactivates its AceHook callbacks.
Secure post-hook wrappers remain inert until reload. The toggle is unavailable during combat;
an active module defers profile transitions until combat ends.
Run `lua src/tests/editmode-keyboard.lua`.

Feature modules go in `src/features/`, listed in the TOC in dependency order. Register hooks and
events in `OnEnable`, restore changes in `OnDisable`, read `app.db.profile` at use time and
implement `OnProfileRefresh` for profile-dependent behavior.

All settings use the page contract documented in the root `CLAUDE.md`; do not register native AddOns panels.
