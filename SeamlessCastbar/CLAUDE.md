# SeamlessCastbar

Optional addon requiring Seamless that adds information to the game's own player, target and focus
cast bars without replacing them: cast time text, the spell rank in the name, channel tick marks,
the spell icon on the detached player bar and how long a bar stays after a cast.
Ships in releases. Open `/seamlesscastbar` or Seamless > Castbar: one tab per bar
(Player, Target, Focus). The player bar's options are also under a collapsible Style header in
SeamlessUI's extended Edit Mode window for the cast bar. The `SeamlessCastbar` namespace holds settings in shared suite profiles with one table per bar
(`player`, `target`, `focus`), each with `enabled`, `castTime` (`enabled`, `format`, `decimals`),
`rank`, `ticks`, `hold` (`enabled`, `success`, `interrupt`) and, for the player only, `icon`.
Target and focus also store `scale` and an optional custom `position`.
Everything but `hold` is on by default.

## What the client already does (don't duplicate)

The client uses the shared `CastingBarMixin` (`Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua`).
Edit Mode's cast bar system offers Bar Size, Lock to Player Frame and Show Cast Time
(`PlayerCastingBarFrame.CastTimeText`, remaining seconds). Target and focus frames only offer
Cast Bar Underneath; their `ShowCastTime` setting is commented out, and their bars
(`SmallCastingBarFrameTemplate`) have no cast time text. They already show the spell icon and the
uninterruptible shield. Breath/fatigue timers are the client's own Edit Mode "Timer bars"
system, so they are not part of this addon.

## Load order and ownership

1. `src/core.lua`: AceAddon/AceDB lifecycle. `OnEnable` post-hooks `UpdateCastTimeText`,
   `HandleCastStart`, `HandleChannelUpdateDelayed`, `HandleCastDelayed` and `UpdateIconShown` on
   `PlayerCastingBarFrame`, `TargetFrameSpellBar` and `FocusFrameSpellBar`. `app.Settings(bar)` is
   the bar's profile table and `app.Active(bar)` its `enabled` switch. `OnDisable` unhooks and restores every bar.
2. `src/text.lua`: `app.FormatCastTime` and `app.UpdateCastTime` (reformats the player's own
   text, which Edit Mode shows or hides; creates one font string right of target/focus bars).
   `app.UpdateName` appends `C_Spell.GetSpellSubtext(bar.spellID)` and remembers the original for
   `app.RestoreName`. `app.UpdateIcon` shows the player icon while the bar has the `CLASSIC` look
   (detached), where the mixin hides it.
3. `src/ticks.lua`: tick intervals by first-rank spell ID, matched by name; `app.TickTimes` and
   `app.UpdateTicks` draw `ui-castingbar-empower-pip` lines on channels and redraw after pushback.
4. `src/hold.lua`: `app.ApplyHold` changes the start delay of `FadeOutAnim`'s alpha and the
   duration of `HoldFadeOutAnim`'s first alpha, remembering the client's values.
5. `src/position.lua`: target/focus `CastbarPositionSpec` supplies one Position and scale
   binding to both options panels and Edit Mode (anchors, offsets, quick anchor and reset).
   `position` stores `{ point, relativeTo, relativePoint, x, y }`; older drag-only positions
   keep their UIParent anchors. Dragging preserves the selected anchor using preview geometry
   only. `scale` (default 1, range 0.5�2) multiplies the live bar's original local scale; the
   preview follows its effective scale. Disable/profile reset restore original scale without
   compounding it on repeated refreshes. Position edits and scale controls are combat guarded.
6. `src/options.lua`: a short General tab and one tab per bar: its Enable switch, then
   standalone Spell rank, Channel ticks and Spell icon switches, plus `core.FeatureGroup`
   sections for Cast time and Hold time (greyed out while the bar is off). The same declarations
   drive the custom and native options windows.
7. `src/editmode.lua`: `app.StyleOptions(key)` builds a bar's Style rows (Core system-option rows
   with defaults) writing its profile and refreshing the options. `app.RegisterEditMode` (from
   `OnEnable`, once) registers the player's for the cast bar system with Core's
   `RegisterEditModeSystemOptions`. SeamlessUI draws it in its extended window below the cast
   bar's settings, so it needs SeamlessUI with the cast bar's Edit Mode extension on; it is never
   a window of its own. `app.LibEditModeSettings(key)` turns target/focus rows into LibEditMode
   settings under Style and Position headers, including scale. `Refresh` and `OnDisable` call `RefreshEditModeSystemOptions`.
8. `src/preview.lua`: target/focus have addon-owned UIParent castbar previews registered with
   LibEditMode. Dragging stores an anchor and offsets in that bar's shared profile `position`;
   Reset Position clears it and restores the client's aura/ToT-dependent placement. With a saved
   position, the real castbar anchors to the preview even when its artwork is hidden. Secure
   post-hooks of `AdjustPosition` and `OnShow` reapply this anchor, including in combat, without
   reading real geometry or replacing casting logic. Disabling the bar/addon restores native
   placement; re-enabling reinstalls Ace hooks. Frames checkboxes only hide Edit Mode artwork.
   Previews animate a cast, channel and interrupted cast, showing localized spell names/icons,
   rank, time formatting, tick marks and hold durations from the current settings. They remain
   visible without a target/focus. Position resets when the shared profile resets.
9. `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- Never call the bars' own methods (`UpdateCastTimeText`, `UpdateIconShown`, `SetLook`); only
  post-hook them and set text, textures and animation timings. Movement may call `AdjustPosition`
  solely to restore native placement after reset/disable. Movement also sets the live bar's scale.
  Nothing is stored on the bars:
  our regions and saved values live in local tables keyed by bar.
- Target and focus casts and the bars' geometry can be secret: skip any value `issecretvalue`
  reports (`app.Known`); ticks use the bar's last known width.
- New channeled spells go into `intervalsBySpellID` with their tick interval, not a tick count.

`lua src/tests/castbar.lua` from the repository root checks formats, rank, icon, ticks, hold and the
Edit Mode rows and target/focus previews.

Manual validation: cast and channel with each bar locked and unlocked from the player frame, with
Edit Mode's Show Cast Time on and off; target and focus a caster (interrupt it, change target
mid-cast, Target of Target shown); Drain Life with pushback, Arcane Missiles rank 1 and max rank,
bandages; spells without a rank; each option and profile switch; Edit Mode preview; select the target and focus previews in Edit Mode and change their Style
options; change Position and scale in both options panels and Edit Mode (anchors, X/Y, scale,
quick anchor and reset), verifying the preview and live bar match; drag both previews, leave Edit Mode and change target/focus during combat; reload and
switch/reset profiles; reset positions and disable/re-enable the addon; check `/console taintLog 1` stays clean.

## Shared suite profiles

Settings now live in the `SeamlessCastbar` namespace of Core's `SeamlessDB`.
`src/db.lua` is the editable source of defaults (including feature defaults).
Core's `RegisterAddonDatabase` imports the legacy `SeamlessCastbarDB` once and
subscribes the addon to shared profile changes, copies and resets. Core's Profiles controls and
slash-command profile resets operate on the whole suite. Character/global data stay in the
namespace; the old standalone database is retained only for migration.
