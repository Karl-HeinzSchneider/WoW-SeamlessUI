# SeamlessActionBars

Optional addon requiring Seamless that changes how the game's own action buttons look, without
replacing them: icon colors for actions out of range or lacking mana, and short keybind labels.
The `SeamlessActionBars` namespace holds settings in shared suite profiles: `range` and `mana` (`enabled`, `color`) and
`keybinds` (`enabled`), all on by default, and `endCaps.left`/`endCaps.right` (`scale`, default 1; `texture`, default `"default"`).

## Ownership

- `src/options/`: page defaults and declarations; `src/db.lua`: schema skeleton. `src/core.lua`: lifecycle, `app.Buttons()` (main and seven multi bars),
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
- `src/options/`: on General, a Show action bars button opening the game's Action Bars
  settings (`Settings.OpenToCategory(Settings.ACTION_BAR_CATEGORY_ID)`), then the feature groups;
  then one tab per native Edit Mode frame (action bars 1-8, both XP / reputation bars, pet action bar, leave vehicle button, left and right endcap) holding
  Core's native Position and scale group. Scale is Icon Size for action bars, Size for status bars,
  the profile scale for the endcaps and disabled for the leave vehicle button. The endcap tabs
  also have Hide endcap, bound to the native Hidden setting, and independent Texture selectors
  (Default leaves native art unchanged, Alliance uses gryphons, Horde uses wyverns). Texture
  overrides reuse the native atlases and restore the original atlas on Default or disable. Bars 4 and 5 are `MultiBarRight` and `MultiBarLeft`.
- `src/micromenu.lua`: the Micro menu tab uses `MicroMenuContainer` for native position,
  scale, orientation and order, saved in the active Edit Mode layout through Core's position
  service. Scale binds the native Size setting. The Style section shares orientation, order and
  artwork controls with the selected frame's extended Edit Mode details window. Profile
  `microMenu.hideArtwork` (default false) hides only `MicroMenu.BorderArt` and `BackgroundArt`,
  restoring their original alpha on profile changes and disable. The buttons stay intact.
- `src/options/bags.lua`: the Bags tab uses the client's `BagsBar` for native position and
  Size, with explicit Revert and Reset Position footer actions. Orientation, direction (left/right
  horizontally, up/down vertically) use the native layout service as well;
  unavailable settings and read-only layouts disable editing. `src/bags.lua` adapts the same Style
  controls into the selected frame's extended Edit Mode window. Native Size is exposed only as
  Position's Scale. These native settings stay in Edit Mode layouts.
  Show free bag slots binds Blizzard's `displayFreeBagSlots` CVar directly and works with either
  skin; the native backpack handles the count and its visibility. It is shared with Edit Mode's
  Style section, and the config page refreshes on external CVar changes.
- `src/barvisibility.lua`: profile `microMenu.hidden` and `bags.hidden` (both default false)
  hide `MicroMenuContainer` and `BagsBar` with ordinary Hide calls. Their Style sections share
  these toggles with the selected frame's Edit Mode settings. Temporarily shows opted-in frames
  during Edit Mode and restores their original shown state on opt-out, profile changes or disable.
  Frames with hiding off are untouched unless restoring our own change. Visibility writes wait
  until combat ends; no visibility hooks, method replacements or reparenting are installed.
  Run `lua src/tests/bar-visibility.lua` for opt-in ownership, preview, profiles and deferred restore.
- `src/bagstyle.lua`: opt-in `bags.retailStyle` (default false) on the Bags Style page and its
  selected-frame Edit Mode section. Profile `bags.spacing` (default 0, 0–20 pixels) controls the
  gaps for this style; `bags.smallButtonSize` (default 30, 15-48 pixels) sizes only the small
  bag buttons, reagent bag and keyring, leaving the 48-pixel backpack unchanged. Both controls
  are shared with Edit Mode and disabled with the style off or during combat. The profile's
  `bags.expanded` (default true) remembers manual collapse/expand across reloads and
  profile changes, synchronizing the native expand CVar. Cursor-driven auto-expansion is not saved.
  Reuses the client's `bag-*` atlases (BagSlots2x art) and
  portrait mask, with a 48-pixel backpack and 30-pixel circular bags, reagent bag and keyring.
  Keeps the native buttons, scripts, inventory updates, free-slot counter and expand manager.
  The disabled module installs no hooks, events or masks until first enabled. Its native
  UpdateTextures/Layout and expand-manager post-hooks then remain inert when off. The manager
  hook runs after the native cached Layout callback; native arrow dimensions are set while
  active and restored on disable (Forever initializes them to zero). Existing unprotected bag
  buttons keep their skin and layout during combat; first activation and restoration defer until
  combat ends. Collapse keeps the expanded bar footprint so the backpack stays fixed for any
  native anchor, while visible small bags pack toward it. Restoration uses a lazy event frame
  that survives module teardown.
  Restores textures, masks, icon anchors, button sizes, frame artwork and native expand policy on
  disable/profile changes, then runs the native bar layout. No retail templates/mixins are used.
  Run `lua src/tests/bag-style.lua` for inactivity, all seven buttons, directions and restoration.

- `src/xpbartooltip.lua`: XP/rested tooltip hooks and Core quest totals. The two XP / reputation
  pages and both bars' selected-frame Edit Mode windows share `xpBarTooltip` settings. Edit Mode
  rows derive from the same prepared options declaration. Imports former UI/Core choices once, including when UI is
  disabled. Automatic rested values use Adventure-tree Well Rested (1225478) purchased ranks,
  4% per rank on the base 150% cap and 5% per eight hours; manual values are the fallback.
  Run `lua src/tests/xp-bar-tooltip.lua`. Check actual rested cap and Legacy changes in game.

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

All settings use the page contract documented in the root `CLAUDE.md`; do not register native AddOns panels.
