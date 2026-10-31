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

- `src/options/`: per-bar feature defaults and page declarations. `src/core.lua`: lifecycle,
  hooks and `app.Settings(bar)`. All three bars follow the addon lifecycle; there are no per-bar
  Enable switches. Individual feature switches remain independent.
- `src/text.lua`: cast-time formatting, spell ranks and detached player icon; restore native
  text when disabled. The player reuses native cast-time text and visibility; target/focus get
  addon-owned font strings.
- `src/ticks.lua`: channel intervals by first-rank spell ID, matched by name.
- `src/hold.lua`: animation delays, retaining native values for restoration.
- `src/options/`: the pages, also shown in Edit Mode; `src/editmode.lua` registers the player page
  for Blizzard's cast bar system.
  The Player tab's Position and Size groups is Core's native group for the cast bar system
  (`GetNativePositionOptions`); position is stored in the Edit Mode layout and unavailable while
  Lock to Player Frame is on. The player's Size controls override that group's Scale placeholder:
  Scale (0.5–3), Width and Height use `profile.player` and apply directly to the native frame.
  `src/size.lua` retains native values for restoration and reapplies overrides after native updates.
  Actual sizing defaults live in the Player page schema: 208 × 11, scale 1 and icon size 16,
  from the client's player/base casting bar templates and default Bar Size. Tooltips and Reset
  To Default Size use that schema; captured live frame values are only for disabling overrides.
- `src/position.lua`, `app.position`: target/focus positions per Edit Mode layout name in
  `profile.positions[key][layout]` (point, relativeTo, relativePoint, x, y in the bar's scale),
  following layout copies, renames and deletes. A layout without one keeps the client's anchor.
  Post-hooks on the bar's `AdjustPosition` and its `OnShow` script (the client's placement on
  target change, cast start and aura rows) re-anchor a moved bar. The bars are not protected, so
  this also runs in combat. Reset and disabling only stop re-anchoring; the client's next
  placement puts the bar back. Old `profile.scales` values are no longer applied.
  `GetOptions(key)` is the tab's Position and Size groups (Scale is Core's dead placeholder).
- `src/preview.lua`: target/focus Edit Mode stand-ins using client art: addon-owned UIParent
  children at the bar's position and effective scale, registered with LibEditMode with Core's
  Position section and their page's rows. A drag releases the anchor frame (stored on UIParent where
  dropped, like Blizzard's Edit Mode); Reset Position reports the registered default (`RESET`). Preview Frames checkboxes are
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
Moved target/focus bars: drag, Position rows, Reset Position, layout switch, target with aura
rows and a ToT, casts in combat.
Check `/console taintLog 1` stays clean.

All settings use the page contract documented in the root `CLAUDE.md`; do not register native AddOns panels.
