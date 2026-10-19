# SeamlessDarkmode

Optional addon requiring Seamless that tints the borders and frame art of specific Blizzard
frames with one shared color. Internal until verified in game. Enable its folder beside Core and
open `/seamlessdarkmode` or Seamless > Darkmode.

- `src/frames.lua`: one function per frame (`PlayerFrame`, `TargetFrame`, `MainActionBar`,
  `Minimap`, `ContainerFrames`, …) naming the exact textures of that frame and its subframes,
  and `app.groups`, the option groups listing those functions.
- `src/core.lua`: AceAddon/AceDB lifecycle, independent `SeamlessDarkmodeDB` profiles and the
  `tint`/`restore` painters passed to the frame functions.
- `src/options.lua`: master switch, shared color and one toggle per group, plus Profiles.
- `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- No scanning: never walk `GetRegions`/`GetChildren` or match texture names. A frame is
  supported only when it has a function here that names its textures.
- Each frame function takes `paint` and calls it on every texture it owns. The same function
  applies darkmode (`tint`) and removes it (`restore`), so a texture listed once is undone too.
- Only decoration: never pass portraits, icons, bar fills, text, flash/glow/status textures or
  quality/proc borders (an action button's `Border`).
- Look up frames through `_G` and guard nil, since a frame may not exist in this client.
- To support a frame: add a function to `frames.lua` and put it in a group in `app.groups`.

`lua src/tests/darkmode.lua` from the repository root checks tint, alpha, restore and toggles.

Manual validation: toggle every group and the master switch, change the color, switch profiles,
and check the frames in vehicle, party, boss fights and with the bank open.
