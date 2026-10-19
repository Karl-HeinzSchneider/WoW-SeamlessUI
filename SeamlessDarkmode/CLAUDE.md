# SeamlessDarkmode

Optional addon requiring Seamless that tints the borders of specific game frames with one shared
color, switchable per group (unit frames, minimap, action bar slots, gryphons, XP border,
reputation border). Internal until verified in game.
Enable its folder beside Core and open `/seamlessdarkmode` or Seamless > Darkmode.

- `src/frames.lua`: one function per frame naming the exact textures of that frame and its
  subframes, and `app.groups`, the option groups listing those functions:
  - Unit frames: `PlayerFrame`, `TargetFrame`, `FocusFrame`, `PetFrame`, `PartyFrame`,
    `BossFrames` (frame texture, level background circle).
  - Minimap: `Minimap` (`MinimapCompassTexture`, its rotating underlay, the zone header) and
    `AddonCompartmentButton` (its `StateTexture`, leaving text, notifications and additive
    interaction highlights untouched), and `MinimapButtons`
    (the `border` of every LibDBIcon button from `GetButtonList`; core.lua
    refreshes on `LibDBIcon_IconCreated` so later buttons are painted too).
    Tracking: tint the separate `MinimapCluster.Tracking.Background` on the parent frame.
    Calendar and tracking button artwork (`StateTexture`) keeps its original color.
    Calendar has no separate border layer in its client template.
  - Action bars: `NormalTexture` on the main bar, seven multi bars, pet, stance and possess
    bars. Leave `SlotArt` and `SlotBackground` unchanged. Gryphons: `MainActionBar.EndCaps`
    left and right `Texture`.
  - XP and reputation: `StatusTrackingBars` selects the painter for each container's shared
    `BarFrameTexture` from `shownBarIndex`, restoring it for unrelated bars. These groups have
    no individual frame functions because the same texture belongs to different bars over time.
- `src/core.lua`: AceAddon/AceDB lifecycle, independent `SeamlessDarkmodeDB` profiles and the
  `tint`/`restore` painters passed to the frame functions. Hooks `ApplyPendingBarToShow` on
  both status containers; retries hook installation on addon load and entering the world.
- `src/options.lua`: master switch, shared color, one toggle per group, plus Profiles.
- `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- No scanning: never walk `GetRegions`/`GetChildren` or match texture names. A frame is
  supported only when it has a function here that names its textures.
- Each frame function takes `paint` and calls it on every texture it owns. The same function
  applies darkmode (`tint`) and removes it (`restore`), so a texture listed once is undone too.
- Only decoration: never pass portraits, icons, bar fills, text or flash/status/highlight
  textures.
- Take texture keys from the client's export (`Blizzard_UnitFrame`, `Blizzard_Minimap`; Camelot
  overrides Mainline), including `Blizzard_ActionBar` and `Blizzard_StatusTrackingBar`.
- To support a frame: add a function to `frames.lua` and put it in a group in `app.groups`.

`lua src/tests/darkmode.lua` from the repository root checks tint, alpha, restore and toggles.

Manual validation: toggle each group and the master switch, change the color, switch profiles,
rotate the minimap, and check the frames in a vehicle, in a party and in boss fights. Check
occupied and empty action slots, pet/stance bars, gryphons, and XP/reputation swapping between
the main and secondary containers (including a switch to honor with its original border).
