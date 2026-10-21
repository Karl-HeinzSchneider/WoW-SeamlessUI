# SeamlessActionBars

Optional addon requiring Seamless that changes how the game's own action buttons look, without
replacing them: icon colors for actions out of range or lacking mana, and short keybind labels.
Ships in releases. Open `/seamlessactionbars` or Seamless > Action Bars.
The `SeamlessActionBars` namespace holds settings in shared suite profiles: `range` and `mana` (`enabled`, `color`) and
`keybinds` (`enabled`), all on by default.

## Load order and ownership

1. `src/core.lua`: AceAddon/AceDB lifecycle and `app.Buttons()`, the `actionButtons` of
   `MainActionBar` and the seven `MultiBar*` bars. `OnEnable` post-hooks each button's
   `UpdateUsable` and `UpdateHotkeys` and the global `ActionButton_UpdateRangeIndicator`
   (filtered to those buttons; the pet bar calls it too). `Refresh` repaints every button.
   `OnDisable` unhooks and restores icons and labels.
2. `src/icons.lua`: `app.PaintIcon` reads `C_ActionBar.IsActionInRange`/`IsUsableAction` and
   tints the icon (range before mana). When a tint ends it puts back the colors
   `ActionBarActionButtonMixin:UpdateUsable` uses (white, light blue, grey). Secret values are
   left alone.
3. `src/hotkeys.lua`: `app.ShortKeyLabel(key)` builds the label from the binding key
   (modifier letters, `M4`, `N5`, `WU`, ...), falling back to `GetBindingText(base, 1)`.
   `app.UpdateHotkey` uses the same key lookup as the client, skips the range dot and gamepad
   bindings and remembers the client's text for `app.RestoreHotkey`.
4. `src/options.lua`: three `core.FeatureGroup` groups on the General tab.
5. `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- Never call the buttons' own methods (`UpdateUsable`, `UpdateHotkeys`, `Update`): running
  Blizzard code from addon code taints fields such as `bindingAction`. Only post-hook them and
  set icon colors and hotkey text.
- All key abbreviations come from the locale catalogue (`... (short)` entries).

`lua src/tests/actionbars.lua` from the repository root checks labels, tints and restores.

Manual validation: target a mob and step in and out of range; run out of mana, rage and energy;
check every multi bar, page switching (stance, stealth), bound/unbound buttons, Shift/Ctrl/Alt,
mouse button, wheel and num pad bindings, toggling each option and switching profiles.

## Shared suite profiles

Settings now live in the `SeamlessActionBars` namespace of Core's `SeamlessDB`.
`src/db.lua` is the editable source of defaults (including feature defaults).
Core's `RegisterAddonDatabase` imports the legacy `SeamlessActionBarsDB` once and
subscribes the addon to shared profile changes, copies and resets. Core's Profiles controls and
slash-command profile resets operate on the whole suite. Character/global data stay in the
namespace; the old standalone database is retained only for migration.
