# SeamlessCastbar

Optional addon requiring Seamless that adds information to the game's own player, target and focus
cast bars without replacing them: cast time text, the spell rank in the name, channel tick marks,
the spell icon on the detached player bar and how long a bar stays after a cast.
Internal until verified in game. Open `/seamlesscastbar` or Seamless > Castbar: one tab per bar
(Player, Target, Focus). The player bar's options are also under a collapsible Style header in
SeamlessUI's extended Edit Mode window for the cast bar. `SeamlessCastbarDB` holds independent profiles with one table per bar
(`player`, `target`, `focus`), each with `enabled`, `castTime` (`enabled`, `format`, `decimals`),
`rank`, `ticks`, `hold` (`enabled`, `success`, `interrupt`), for the player only `icon`, and for
target and focus `move` (`enabled`, `layouts` by Edit Mode layout name). Everything but `hold` and
`move` is on by default.

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
5. `src/options.lua`: a short General tab and one tab per bar: its Enable switch, then
   `core.FeatureGroup` groups (greyed out while the bar is off).
6. `src/editmode.lua`: `app.RegisterEditMode` (from `OnEnable`, once) registers the Style section
   for the cast bar system with Core's `RegisterEditModeSystemOptions`. SeamlessUI draws it in its
   extended window below the cast bar's settings, so it needs SeamlessUI with the cast bar's Edit
   Mode extension on; it is never a window of its own. The rows write the player profile and
   refresh the options; `Refresh` and `OnDisable` call `RefreshEditModeSystemOptions`, and the
   section leaves while the addon is disabled.
7. `src/move.lua`: `app.RegisterMove` (from `OnEnable`, once) gives target and focus an addon-owned
   anchor frame registered with LibEditMode ("Target cast bar", "Focus cast bar"), with Core's
   Position section and a checkbox each under Edit Mode's Frames heading. The client places these
   bars only in their `AdjustPosition` (unit frame size, Target of Target, aura rows, alternate
   power bar); `OnEnable` post-hooks it, and `app.UpdateMove` then saves the client's points and
   anchors the bar's CENTER to ours. The bars are not protected frames, so this works in combat and
   taints nothing: no client method is called or replaced, and no protected frame is anchored to
   ours. Switching off, disabling the addon or a profile without `move` puts the client's latest
   points back (`app.RestoreMove`; if they hold secret values and cannot be set again, the client's
   default spot until its next `AdjustPosition`). The first switch-on in a layout starts at the
   client's default spot under the unit frame (`TOPLEFT` to its `BOTTOMLEFT`), read from the unit
   frame: once the client anchors a bar to the aura rows, the bar's geometry can stay secret,
   so never compute with its size or position (the anchor keeps its last known size, ticks the
   last known width). Layout copy, rename and delete carry the positions along.
8. `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- Never call the bars' own methods (`UpdateCastTimeText`, `UpdateIconShown`, `SetLook`); only
  post-hook them and set text, textures and animation timings. Nothing is stored on the bars:
  our regions and saved values live in local tables keyed by bar.
- Target and focus casts and the bars' geometry can be secret: skip any value `issecretvalue`
  reports (`app.Known`).
- New channeled spells go into `intervalsBySpellID` with their tick interval, not a tick count.

`lua src/tests/castbar.lua` from the repository root checks formats, rank, icon, ticks, hold and the
Edit Mode rows and moving the target bar.

Manual validation: cast and channel with each bar locked and unlocked from the player frame, with
Edit Mode's Show Cast Time on and off; target and focus a caster (interrupt it, change target
mid-cast, Target of Target shown); Drain Life with pushback, Arcane Missiles rank 1 and max rank,
bandages; spells without a rank; each option and profile switch; Edit Mode preview; move the target and focus bars, then change
target, show Target of Target and many auras, enter and leave combat, switch layouts, check
`/console taintLog 1` stays clean.
