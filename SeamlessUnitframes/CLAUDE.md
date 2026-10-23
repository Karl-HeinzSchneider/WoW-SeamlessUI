# SeamlessUnitframes

Optional unit frame addon: changes the game's own unit frames. Settings and profiles live in
the `SeamlessUnitframes` namespace of `SeamlessDB`.

## Ownership

- `src/core/`: lifecycle, database defaults, unit-frame registry, options and Edit Mode sections.
  `unitframes.lua` maps keys to native systems or linked frames; `style.lua` is the single
  source for per-frame settings (`StyleGroups`, `StyleOptions`).
- `src/healthcolor/`, `src/name/`, `src/portrait/`, `src/pvpicon/`, `src/questicon/`: visual
  features reading `profile.unitFrames[key]`. Preserve secret-value guards and restore only
  regions the feature changed. Pets use the player's class color; native class-icon CVars win
  when restoring portraits.
- `src/totposition/`: ToT positions and addon-owned Edit Mode stand-ins.
- `src/layout/`: optional legacy geometry and artwork.

Native Player, Pet, Target and Focus position controls use Core's `GetNativePositionOptions` and
`GetNativeSettingScale`, reading the active layout without a SeamlessUI dependency. ToT frames
use `app.totPosition:GetOptions`. Linked frames' Style rows appear with their parent.

New per-frame settings need a default in `db.lua` and a row in `style.lua`, which puts them in both
the frame's tab and its Edit Mode Style section; global settings go in `options.lua`'s General tab.
Run `lua src/tests/unitframes-options.lua`.

## `src/totposition/`: movable ToT frames

`TargetFrameToT` and `FocusFrameToT` have no Edit Mode system: the client creates them as secure
children of their unit frame (`TargetFrameMixin:CreateTargetofTarget`), anchored TOPRIGHT to its
BOTTOMRIGHT (12, 10; the small focus frame 20, 8 from `FocusFrameMixin:SetSmallSize`).

- `totposition.lua`, `app.totPosition`: positions per Edit Mode layout name in
  `profile.totPositions[key][layout]` (point, relativeTo, relativePoint, x, y in the ToT's own
  scale), following layout copies, renames and deletes. A layout without one keeps the client's
  anchor: the frame is never touched until moved, and Reset or disabling puts the client's anchor
  back. `Apply` only runs out of combat (queued to `PLAYER_REGEN_ENABLED`); a post-hook on
  `FocusFrame.SetSmallSize` re-applies a moved focus ToT. Anchor frames are validated with Core's
  position service and fall back to the unit frame. `GetOptions(key)` is the options tab's
  Position group (Scale disabled: the ToT takes its unit frame's Frame Size).
- `mover.lua`, `app.totMover`: an addon-owned UIParent stand-in per frame with the ToT art, size
  and effective scale, registered with LibEditMode and shown only in Edit Mode (a Frames checkbox
  each, on for the session), with Core's Position section. A drag releases the anchor frame: the
  ToT is stored on UIParent where it was dropped, like Blizzard's Edit Mode. LibEditMode's Reset Position reports the registered default (`RESET`), which means
  Reset.
  The stand-ins show live player name, portrait, health and power. They reuse the layout's fixed
  ToT geometry and the name, class icon and health color modules' `ApplyPreview` methods with
  their own ToT settings key. Hooks on those modules' `Refresh` keep visible previews in sync.

Never drag, reparent or `SetUserPlaced` the real frames, change their scripts, store anything on
them or anchor them to the aura container or cast bar (Forever restricts those). Blizzard still
reserves the ToT's room under its unit frame (`haveToT` lowers the cast bar, `TOT_AURA_ROW_WIDTH`
narrows two aura rows); that state lives on the secure unit frame, so it is left alone.
Run `lua src/tests/unitframes-totposition.lua`.

## `src/layout/`: legacy layout

- `atlas.lua`: generated coordinates of the old artwork; regenerate with
  `python src/generate-legacy-unitframe-atlas.py`. The BLP sheets are in `assets/legacy/`; see
  `docs/unit-frame-layout.md` for provenance and limits.
- `layout.lua`: `app.legacyLayout`; inert until Legacy is selected.
- `geometry.lua`: fixed 70374/70425 definitions for player, target/focus/boss, pet/ToT, party and
  combo points.

Rules:

- Only named components are changed. No recursive frame/region scans, no render getters
  (`GetAtlas`, UVs, sizes) to infer a layout: atlas names, geometry and restoration come from the
  fixed definitions. `GetStatusBarTexture` only obtains the named bar's texture object.
- Validate frame paths and setters (`CheckPaths`/`CheckRegion`); missing or forbidden components
  log one deduplicated warning.
- Health colors resolve atlases with `HealthAtlas(bar, key)` and change them through
  `SetHealthAtlas`.
- Never write addon state onto protected frame tables or anchor protected frames to the
  target/focus health bars (secure templates); use ordinary visual bars and forward secret values
  directly. Layout changes and protected geometry wait out combat.
- Restore static atlases with `resetTexCoords = true`, reapplying fixed definitions, not observed
  state. Keep native root positions and scale; don't change draw/frame levels to hide health loss
  flashes.
- In Legacy the animated health loss bar uses the live bar's white fill and tint (Current restores
  its red); party health loss uses the Player atlas; unknown power types use the native mana fill.
- Apply repairs synchronously, never on the next frame. Cache only our own last writes and
  invalidate them on native setters.
  Fixed anchors remember only our last successful `ClearAllPoints`/`SetPoint`
  pair. Native point/all-points/parent setters invalidate that entry without
  inspecting their arguments. Nested setters leave it uncached. Never infer
  anchor state from rendering getters or populate the cache for combat-skipped writes.
- Native frame hooks repair only their owner with `Refresh(false, frame)` and
  `healthColor:RefreshFrame(frame)`. Global mana-bar hooks resolve `bar.unitFrame`,
  player-art hooks use PlayerFrame, and unrelated/secret owners are ignored. Full
  refreshes remain for settings and roster/lifecycle events. Never rebuild all
  frames or recolor the entire suite in response to one frame's native update.
- During native Edit Mode entry (`manager:IsEditModeActive()` before the shared
  library enters), deduplicate affected owners and flush one scoped refresh from
  the library's synchronous `enter` callback. The client's `EnterEditMode` fires
  that event after native frame setup, in the same call stack and before drawing.
  No next-frame timer is used. Exit/disable clear pending owners; all ordinary
  native updates still repair immediately.
- Treat gameplay values and frame fields as possibly secret: check access before comparing,
  branching, concatenating or indexing.

Run `lua src/test-legacy-layout.lua` (its render getters throw if called) and
`python -m unittest src/test_legacy_unitframe_atlas.py`.

## Conventions

- `src/core/previewcharacters.lua` consumes Core's VIP catalogue only for the addon-owned
  Target of Target and Target of Focus Edit Mode stand-ins. Getters require both an allowed key
  and the exact frame in `totMover.movers`; native frames cannot consume VIP data. No native
  frame enumeration, native update hooks or native refresh/restoration calls belong in this
  controller. Native name, portrait and health-color paths never consult the catalogue; only
  their explicit `ApplyPreview` methods do. The stand-ins render names, portraits, health/power
  and configured health colors. Combat/disable refresh only those custom frames with live
  fallback data. Core retains metadata for future custom-frame consumers.
  Run `lua src/tests/preview-unitframes.lua`, `lua src/tests/unitframes-options.lua` and
  `lua src/tests/unitframes-totposition.lua`. The isolation test rejects native hooks and calls.

- Modules are prototype-style Ace modules (`addon:NewModule("Name", module, …)`); a module that
  depends on profile settings defines `OnProfileRefresh`.
- `src/types.lua`: annotations for `app.*` and `SeamlessUnitframes.DB`; not in the TOC.
