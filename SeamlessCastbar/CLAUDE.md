# SeamlessCastbar

Optional addon requiring Seamless that adds information to the game's own player, target and focus
cast bars without replacing them: cast time text, the spell rank in the name, channel tick marks,
the spell icon on the detached player bar and how long a bar stays after a cast. It also makes
the target and focus bars movable and the player bar resizable.

## What the client already does (don't duplicate)

The client uses the shared `CastingBarMixin` (`Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua`).
Edit Mode's cast bar system offers Bar Size, Lock to Player Frame and Show Cast Time
(`PlayerCastingBarFrame.CastTimeText`, remaining seconds). Target and focus frames only offer
Cast Bar Underneath; their `ShowCastTime` setting is commented out, and their bars
(`SmallCastingBarFrameTemplate`) have no cast time text. They already show the spell icon and the
uninterruptible shield. Breath/fatigue timers are the client's own Edit Mode "Timer bars"
system, so they are not part of this addon.

## Ownership

- `src/player.lua`: independent `SeamlessCastbarPlayer`, using the native template and its own cast subscriptions. Always uses the detached appearance and direct profile scale, with no Lock To Player Frame behavior. The original player display is suppressed while enabled and restored on disable.

- `src/playerposition.lua`: UIParent-only position per layout in `profile.positions.player`, independent of native frames. Imports a saved UIParent layout anchor once; otherwise snapshots Blizzard's default managed-slot calculation per layout (bottom action-bar height, game-rule overlay, native margins, castbar padding and lower managed children). It anchors that snapshot directly to UIParent without following the native bar or later action-bar movement. Reset uses this same default; user scale is accounted for in screen coordinates. A separate LibEditMode preview owns selection, dragging and the Player page. Show Cast Time is imported once per profile and then controlled by the independent Show cast time option. Existing position layout-copy/rename/delete callbacks include player entries.

- `src/crafting.lua`: automatic batch crafting on the custom player bar only. Secure post-hooks on DoTradeSkill and C_TradeSkillUI.CraftRecipe capture quantity; the custom frame tracks successful cast IDs. The range is rebased from each actual cast end plus unfinished casts, retaining elapsed gaps. The spell label shows the current craft and total (for example, Copper Bar (3/10)); refreshes preserve rank without duplicating the suffix. Intermediate stops keep the bar alive; final completion, interruption, queue cancellation and disabling clear the batch.

- `src/options/`: per-bar feature defaults and the Player, Target and Focus pages (`shared.lua`
  holds their common controls). `src/editmode.lua` registers the player's Style and Size rows as
  system options for SeamlessUI's Blizzard Edit Mode extension. `src/core.lua`: lifecycle,
  hooks and `app.Settings(bar)`. All three bars follow the addon lifecycle; there are no per-bar
  Enable switches. Individual feature switches remain independent.
- `src/text.lua`: cast-time formatting, spell ranks and detached player icon; restore native
  text when disabled. Both player bars use inherited cast-time text; our player uses profile.player.showCastTime for visibility; target/focus get
  addon-owned font strings.
- `src/ticks.lua`: channel intervals by first-rank spell ID, matched by name.
- `src/hold.lua`: animation delays, retaining native values for restoration.
- `src/size.lua`: player bar size. The Player tab's Position and Size groups are Core's native group
  for the custom preview; position is stored per layout with UIParent as its only anchor. The player's Size controls override that group's
  Scale placeholder: Scale (0.5–3), Width and Height use `profile.player` and apply directly to the
  native and addon-owned frames. It retains per-frame values for restoration and reapplies overrides after style
  updates. Actual sizing defaults live in the Player page schema: 208 × 11, scale 1 and icon size
  16, from the client's player/base casting bar templates and default Bar Size. Tooltips and Reset
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
  dropped); Reset Position reports the registered default (`RESET`). Preview Frames checkboxes
  are session-only.

## Rules

- Never call the bars' own methods (`UpdateCastTimeText`, `UpdateIconShown`, `SetLook`); only
  post-hook them and set text, textures and animation timings. Nothing is stored on the bars:
  our regions and saved values live in local tables keyed by bar. This restriction applies to
  Blizzard-owned bars; the addon-owned comparison bar calls its inherited methods normally.
- Target and focus casts and the bars' geometry can be secret: skip any value `issecretvalue`
  reports (`app.Known`); ticks use the bar's last known width. This is why the real bars are
  only anchored, never dragged or measured (the approach EditModeExpanded uses too): once the
  client anchors a bar to the aura container it inherits the container's forbidden aspects.
  Never reparent the bars or anchor other frames to them.
- New channeled spells go into `intervalsBySpellID` with their tick interval, not a tick count.

`lua src/tests/castbar.lua` from the repository root checks formats, rank, icon, ticks, hold and the
Edit Mode rows, target/focus previews and positions.
`lua src/tests/player-castbar.lua` checks the custom player's independent lifecycle, inherited
method dispatch and current-profile refresh. Player visual settings affect both player bars;
the player preview supplies independent positioning.

`lua src/tests/crafting-castbar.lua` checks batch timing, gaps, changed durations, duplicate and reordered events, synchronous first casts, interruption and cancellation.

Manual validation: multi-craft batches with gaps, stop/movement cancellation, insufficient reagents, final completion and ordinary casts afterward. Player cast bar locked/unlocked, native Show Cast Time on/off, target/focus
casts and interruptions, channel pushback, spell ranks, profile changes and Edit Mode previews.
Moved target/focus bars: drag, Position rows, Reset Position, layout switch, target with aura
rows and a ToT, casts in combat.
Check `/console taintLog 1` stays clean.

`lua src/tests/player-castbar-position.lua` checks one-time import, UIParent-only anchors, dragging, layout changes and reset.
