# SeamlessDarkmode

Optional addon requiring Seamless that tints the borders of the game's unit frames with one
shared color. Internal until verified in game. Enable its folder beside Core and open
`/seamlessdarkmode` or Seamless > Darkmode.

- `src/frames.lua`: one function per unit frame (`PlayerFrame`, `TargetFrame`, `FocusFrame`,
  `PetFrame`, `PartyFrame`, `BossFrames`) naming the exact textures of that frame and its
  subframes (frame texture, level background circle), and `app.frames`, the list of them.
- `src/core.lua`: AceAddon/AceDB lifecycle, independent `SeamlessDarkmodeDB` profiles and the
  `tint`/`restore` painters passed to the frame functions.
- `src/options.lua`: master switch and shared color, plus Profiles.
- `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- No scanning: never walk `GetRegions`/`GetChildren` or match texture names. A frame is
  supported only when it has a function here that names its textures.
- Each frame function takes `paint` and calls it on every texture it owns. The same function
  applies darkmode (`tint`) and removes it (`restore`), so a texture listed once is undone too.
- Only decoration: never pass portraits, bar fills, text or flash/status textures.
- Take texture keys from the client's `Blizzard_UnitFrame` export (Camelot overrides Mainline).
- To support a frame: add a function to `frames.lua` and list it in `app.frames`.

`lua src/tests/darkmode.lua` from the repository root checks tint, alpha, restore and toggles.

Manual validation: toggle the master switch, change the color, switch profiles, and check
the frames in a vehicle, in a party and in boss fights.
