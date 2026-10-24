# SeamlessActionBars

Optional addon requiring Seamless that changes how the game's own action buttons look, without
replacing them: icon colors for actions out of range or lacking mana, and short keybind labels.
The `SeamlessActionBars` namespace holds settings in shared suite profiles: `range` and `mana` (`enabled`, `color`) and
`keybinds` (`enabled`), all on by default, and `endCaps.left`/`endCaps.right` (`scale`, default 1).

## Ownership

- `src/db.lua`: defaults. `src/core.lua`: lifecycle, `app.Buttons()` (main and seven multi bars),
  hooks and restoration. Filter the global range hook because pet buttons call it too.
- `src/icons.lua`: range tint before mana tint; restore the client's white/light-blue/grey
  usability colors. Leave secret values alone.
- `src/hotkeys.lua`: `ShortKeyLabel`, `UpdateHotkey`, `RestoreHotkey`; skip range dots and
  gamepad bindings and retain original text for restoration.
- `src/endcaps.lua`: the main action bar's gryphons (`MainActionBar.EndCaps.LeftEndCap`/
  `RightEndCap`, Edit Mode system `MainActionBarEndCap`, no global names). Their position and
  Hidden setting are native layout settings; they have no size setting, so their Scale is ours:
  stored per profile, applied with the frame's own `SetScale` (Edit Mode's override keeps the
  offsets in place), outside combat only (re-applied on `PLAYER_REGEN_ENABLED`), restored to 1 on
  disable. The same binding goes to the settings tab and, through
  `core:RegisterEditModeSystemScale`, to SeamlessUI's Edit Mode Position section.
- `src/options.lua`: on General, a Show action bars button opening the game's Action Bars
  settings (`Settings.OpenToCategory(Settings.ACTION_BAR_CATEGORY_ID)`), then the feature groups;
  then one tab per native Edit Mode frame (action bars 1-8, both XP / reputation bars, pet action bar, leave vehicle button, left and right endcap) holding
  Core's native Position and scale group. Scale is Icon Size for action bars, Size for status bars,
  the profile scale for the endcaps and disabled for the leave vehicle button. The endcap tabs
  also have Hide endcap, bound to the native Hidden setting. Bars 4 and 5 are `MultiBarRight` and `MultiBarLeft`.

## Rules

- Never change the game's bar visibility settings (`PROXY_SHOW_ACTIONBAR_<n>`,
  `SetActionBarToggles`) from addon code: the bars' update then runs in our call and taints the
  buttons, blocking their `SetShown` in combat. Open the game's settings page instead.

- Never call the buttons' own methods (`UpdateUsable`, `UpdateHotkeys`, `Update`): running
  Blizzard code from addon code taints fields such as `bindingAction`. Only post-hook them and
  set icon colors and hotkey text.
- All key abbreviations come from the locale catalogue (`... (short)` entries).

`lua src/tests/actionbars.lua` from the repository root checks labels, tints and restores.

Manual validation: target a mob and step in and out of range; run out of mana, rage and energy;
check every multi bar, page switching (stance, stealth), bound/unbound buttons, Shift/Ctrl/Alt,
mouse button, wheel and num pad bindings, toggling each option and switching profiles.
