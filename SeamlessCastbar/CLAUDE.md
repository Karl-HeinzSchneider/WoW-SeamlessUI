# SeamlessCastbar

Optional addon requiring Seamless that adds information to the game's own player, target and focus
cast bars without replacing them: cast time text, the spell rank in the name, channel tick marks,
the spell icon on the detached player bar and how long a bar stays after a cast.
Options have Player, Target and Focus tabs. The player's Style section uses SeamlessUI's
native Edit Mode extension; target/focus previews use LibEditMode settings.

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
- `src/preview.lua`: fixed target/focus previews using client art, registered through
  `core:SetEditModeFrameFixed`. Never move the real bars: aura anchoring makes their geometry
  secret. Preview Frames checkboxes are session-only.

## Rules

- Never call the bars' own methods (`UpdateCastTimeText`, `UpdateIconShown`, `SetLook`); only
  post-hook them and set text, textures and animation timings. Nothing is stored on the bars:
  our regions and saved values live in local tables keyed by bar.
- Target and focus casts and the bars' geometry can be secret: skip any value `issecretvalue`
  reports (`app.Known`); ticks use the bar's last known width.
- New channeled spells go into `intervalsBySpellID` with their tick interval, not a tick count.

`lua src/tests/castbar.lua` from the repository root checks formats, rank, icon, ticks, hold and the
Edit Mode rows and target/focus previews.

Manual validation: player cast bar locked/unlocked, native Show Cast Time on/off, target/focus
casts and interruptions, channel pushback, spell ranks, profile changes and Edit Mode previews.
Check `/console taintLog 1` stays clean.
