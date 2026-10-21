# SeamlessCastbar

Optional addon requiring Seamless that adds information to the game's own player, target and focus
cast bars without replacing them: cast time text, the spell rank in the name, channel tick marks,
the spell icon on the detached player bar and how long a bar stays after a cast.
Ships in releases. Open `/seamlesscastbar` or Seamless > Castbar: one tab per bar
(Player, Target, Focus). The player bar's options are also under a collapsible Style header in
SeamlessUI's extended Edit Mode window for the cast bar. The `SeamlessCastbar` namespace holds settings in shared suite profiles with one table per bar
(`player`, `target`, `focus`), each with `enabled`, `castTime` (`enabled`, `format`, `decimals`),
`rank`, `ticks`, `hold` (`enabled`, `success`, `interrupt`) and, for the player only, `icon`.
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
5. `src/options.lua`: a short General tab and one tab per bar: its Enable switch, then
   `core.FeatureGroup` groups (greyed out while the bar is off).
6. `src/editmode.lua`: `app.StyleOptions(key)` builds a bar's Style rows (Core system-option rows
   with defaults) writing its profile and refreshing the options. `app.RegisterEditMode` (from
   `OnEnable`, once) registers the player's for the cast bar system with Core's
   `RegisterEditModeSystemOptions`. SeamlessUI draws it in its extended window below the cast
   bar's settings, so it needs SeamlessUI with the cast bar's Edit Mode extension on; it is never
   a window of its own. `app.LibEditModeSettings(key)` turns target/focus rows into LibEditMode
   settings under a Style header. `Refresh` and `OnDisable` call `RefreshEditModeSystemOptions`.
7. `src/preview.lua`: target and focus bars have no Edit Mode system and are placed by their
   unit frames, so they are never moved (moving them was tried: once the client anchors a bar to
   the aura rows, its size, position and even its number of points are secret). In Edit Mode,
   `app.RegisterPreviews` (from `OnEnable`, once) shows a preview of each, made from the game's
   cast bar art and a child of the unit frame at the client's spot without aura rows. Each is
   registered with LibEditMode and `core:SetEditModeFrameFixed`, so selecting it opens its Style
   settings and it cannot be dragged, nudged or reset. A Frames checkbox each ("Target cast bar",
   "Focus cast bar", on for the session by default) hides the preview. `app.UpdatePreviews` runs
   on Edit Mode enter/exit and every `Refresh`, showing the name and a sample cast time.
8. `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

## Rules

- Never call the bars' own methods (`UpdateCastTimeText`, `UpdateIconShown`, `SetLook`); only
  post-hook them and set text, textures and animation timings. Nothing is stored on the bars:
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
options; check `/console taintLog 1` stays clean.

## Shared suite profiles

Settings now live in the `SeamlessCastbar` namespace of Core's `SeamlessDB`.
`src/db.lua` is the editable source of defaults (including feature defaults).
Core's `RegisterAddonDatabase` imports the legacy `SeamlessCastbarDB` once and
subscribes the addon to shared profile changes, copies and resets. Profiles controls and
slash-command profile resets operate on the whole suite. Character/global data stay in the
namespace; the old standalone database is retained only for migration.
