# SeamlessDarkmode

Optional addon requiring Seamless that tints the borders of specific game frames with one shared
color, switchable per group (unit frames, minimap, action bars). Internal until verified in game.
Enable its folder beside Core and open `/seamlessdarkmode` or Seamless > Darkmode.

- `src/frames.lua`: one function per frame naming the exact textures of that frame and its
  subframes, and `app.groups`, the option groups listing those functions:
  - Unit frames: `PlayerFrame`, `TargetFrame`, `FocusFrame`, `PetFrame`, `PartyFrame`,
    `BossFrames` (frame texture, level background circle).
  - Minimap: `Minimap` (`MinimapCompassTexture`, its rotating underlay, the zone header).
  - Action bars: `MainActionBar` (border art, end caps), `MultiBars`, `PetActionBar`,
    `StanceBar`, `PossessActionBar`; buttons come from each bar's `actionButtons`, the list the
    client's `ActionBarMixin` fills (ring `NormalTexture` and `SlotArt`).
- `src/core.lua`: AceAddon/AceDB lifecycle, independent `SeamlessDarkmodeDB` profiles and the
  `tint`/`restore` painters passed to the frame functions.
- `src/options.lua`: master switch, shared color, one toggle per group, plus Profiles.
- `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- No scanning: never walk `GetRegions`/`GetChildren` or match texture names. A frame is
  supported only when it has a function here that names its textures.
- Each frame function takes `paint` and calls it on every texture it owns. The same function
  applies darkmode (`tint`) and removes it (`restore`), so a texture listed once is undone too.
- Only decoration: never pass portraits, icons, bar fills, text, flash/status/highlight
  textures or an action button's `Border` (equipped/proc indicator).
- Take texture keys from the client's export (`Blizzard_UnitFrame`, `Blizzard_Minimap`,
  `Blizzard_ActionBar`; Camelot overrides Mainline).
- To support a frame: add a function to `frames.lua` and put it in a group in `app.groups`.

`lua src/tests/darkmode.lua` from the repository root checks tint, alpha, restore and toggles.

Manual validation: toggle each group and the master switch, change the color, switch profiles,
rotate the minimap, and check the frames in a vehicle, in a party and in boss fights.
