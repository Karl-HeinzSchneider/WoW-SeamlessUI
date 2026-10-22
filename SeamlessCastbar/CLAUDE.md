# SeamlessCastbar

Optional addon requiring Seamless that adds information to the game's own player, target and focus
cast bars without replacing them: cast time text, the spell rank in the name, channel tick marks,
the spell icon on the detached player bar and how long a bar stays after a cast. It also makes
the target and focus bars movable. Options have Player, Target and Focus tabs. The player's Style
section uses SeamlessUI's native Edit Mode extension; target/focus previews use LibEditMode
settings.

## What the client already does (don't duplicate)

The client uses the shared `CastingBarMixin` (`Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua`).
Edit Mode's cast bar system offers Bar Size, Lock to Player Frame and Show Cast Time
(`PlayerCastingBarFrame.CastTimeText`, remaining seconds). Target and focus frames only offer
Cast Bar Underneath; their `ShowCastTime` setting is commented out, and their bars
(`SmallCastingBarFrameTemplate`) have no cast time text. They already show the spell icon and the
uninterruptible shield. Breath/fatigue timers are the client's own Edit Mode "Timer bars"
system, so they are not part of this addon.

## Ownership

- `src/db.lua`: per-bar defaults. `src/core.lua`: lifecycle, hooks, `app.Settings(bar)` and
  `app.Active(bar)`.
- `src/text.lua`: cast-time formatting, spell ranks and detached player icon; restore native
  text when disabled. The player reuses native cast-time text and visibility; target/focus get
  addon-owned font strings.
- `src/ticks.lua`: channel intervals by first-rank spell ID, matched by name.
- `src/hold.lua`: animation delays, retaining native values for restoration.
- `src/options.lua`, `src/editmode.lua`: options and shared Style declarations.
- `src/position.lua`, `app.position`: target/focus positions per Edit Mode layout name in
  `profile.positions[key][layout]` (point, relativeTo, relativePoint, x, y in the bar's scale),
  following layout copies, renames and deletes. A layout without one keeps the client's anchor.
  Post-hooks on the bar's `AdjustPosition` and its `OnShow` script (the client's placement on
  target change, cast start and aura rows) re-anchor a moved bar. The bars are not protected, so
  this also runs in combat. Reset and disabling only stop re-anchoring; the client's next
  placement puts the bar back. A scale per layout in `profile.scales[key][layout]` is set on
  the bar at the same moments (the client never scales these bars; 1 is not stored, and a bar we
  scaled gets 1 back); changing it rescales stored offsets so the anchor point stays put.
  `GetOptions(key)` is the tab's Position and scale group; `ScaleOption(key)` also feeds the Edit
  Mode Scale slider.
- `src/preview.lua`: target/focus Edit Mode stand-ins using client art: addon-owned UIParent
  children at the bar's position and effective scale, registered with LibEditMode with Core's
  Position section and the Style rows. A drag keeps the stored anchor frame and measures offsets
  from it; Reset Position reports the registered default (`RESET`). Preview Frames checkboxes are
  session-only.

## Rules

- Never call the bars' own methods (`UpdateCastTimeText`, `UpdateIconShown`, `SetLook`); only
  post-hook them and set text, textures and animation timings. Nothing is stored on the bars:
  our regions and saved values live in local tables keyed by bar.
- Target and focus casts and the bars' geometry can be secret: skip any value `issecretvalue`
  reports (`app.Known`); ticks use the bar's last known width. This is why the real bars are
  only anchored, never dragged or measured (the approach EditModeExpanded uses too): once the
  client anchors a bar to the aura container it inherits the container's forbidden aspects.
  Never reparent the bars or anchor other frames to them.
- New channeled spells go into `intervalsBySpellID` with their tick interval, not a tick count.

`lua src/tests/castbar.lua` from the repository root checks formats, rank, icon, ticks, hold and the
Edit Mode rows, target/focus previews and positions.

Manual validation: player cast bar locked/unlocked, native Show Cast Time on/off, target/focus
casts and interruptions, channel pushback, spell ranks, profile changes and Edit Mode previews.
Moved target/focus bars: drag, Position rows, Scale, Reset Position, layout switch, target with aura
rows and a ToT, casts in combat.
Check `/console taintLog 1` stays clean.
