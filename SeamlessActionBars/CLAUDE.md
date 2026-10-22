# SeamlessActionBars

Optional addon requiring Seamless that changes how the game's own action buttons look, without
replacing them: icon colors for actions out of range or lacking mana, and short keybind labels.
The `SeamlessActionBars` namespace holds settings in shared suite profiles: `range` and `mana` (`enabled`, `color`) and
`keybinds` (`enabled`), all on by default.

## Ownership

- `src/db.lua`: defaults. `src/core.lua`: lifecycle, `app.Buttons()` (main and seven multi bars),
  hooks and restoration. Filter the global range hook because pet buttons call it too.
- `src/icons.lua`: range tint before mana tint; restore the client's white/light-blue/grey
  usability colors. Leave secret values alone.
- `src/hotkeys.lua`: `ShortKeyLabel`, `UpdateHotkey`, `RestoreHotkey`; skip range dots and
  gamepad bindings and retain original text for restoration.
- `src/options.lua`: feature groups on General, then one tab per native Edit Mode frame (action
  bars 1-8, both XP / reputation bars, pet action bar, leave vehicle button) holding only Core's
  native Position and scale group. Scale is Icon Size for action bars, Size for status bars and
  disabled for the leave vehicle button. Bars 4 and 5 are `MultiBarRight` and `MultiBarLeft`.

## Rules

- Never call the buttons' own methods (`UpdateUsable`, `UpdateHotkeys`, `Update`): running
  Blizzard code from addon code taints fields such as `bindingAction`. Only post-hook them and
  set icon colors and hotkey text.
- All key abbreviations come from the locale catalogue (`... (short)` entries).

`lua src/tests/actionbars.lua` from the repository root checks labels, tints and restores.

Manual validation: target a mob and step in and out of range; run out of mana, rage and energy;
check every multi bar, page switching (stance, stealth), bound/unbound buttons, Shift/Ctrl/Alt,
mouse button, wheel and num pad bindings, toggling each option and switching profiles.
