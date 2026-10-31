# Seamless

A modular World of Warcraft addon suite for WoW Forever. It improves the game's own interface
instead of replacing it: each part is a separate addon you can switch on or off.

## Addons

- **Seamless** (required): the core. Shared libraries, logging, the **Seamless** settings window
  (`/seamless`, a minimap button and an addon compartment entry), suite-wide profiles and the
  shared Edit Mode panel. It adds a "SeamlessUI (Preset)" Edit Mode layout, `/rl` to reload, `/kb`
  for Quick Keybind Mode, completed quests and their XP in the quest log, and BetterGroupLoot roll
  frames (Embed page).
- **SeamlessUnitframes**: per-frame settings for the player, pet, target, target of target, focus,
  target of focus and party frames: health colors (default, class, reaction or class and reaction),
  name display, class icons as portraits, level display, the player's portrait dragon, hiding the
  PvP icon or name background, a quest icon on quest targets, threat percentage, status text, a
  shared Default, Beta or Beta (rounded) layout and movable target of target frames.
- **SeamlessTooltip**: 23 switchable tooltip enhancements, including cursor or action button
  anchoring, scale, backgrounds and borders, player and NPC text, status tags and raid markers,
  targets and "targeted by", health bars, item level, IDs, stack sizes, vendor prices, spell IDs
  and aura casters.
- **SeamlessChat**: the same chat setup (windows, channels, message types, colors) on every
  character, input history, timestamps, saved message history, copy and searchable log windows,
  clickable URLs, short channel names, class colors, fading, backgrounds, unread counts on tabs
  and a restyled chat button bar.
- **SeamlessDamageMeter**: up to six movable, resizable meter windows on the client's combat
  statistics (damage, DPS, healing, HPS, absorbs, interrupts, dispels, damage taken, deaths) and a
  live threat meter, with spell breakdowns on hover or click, shared skins and favorites.
- **SeamlessUI**: extra controls in the game's Edit Mode (exact positions and anchors for Blizzard
  frames, and the Style settings of the other addons), minimap options (square shape, hidden
  header buttons), a movable combined bags window, an FPS display with optional latency and
  keyboard pass-through in Edit Mode.
- **SeamlessDarkmode**: one shared dark tint for the borders of unit frames, the minimap and its
  addon buttons, action bar slots, gryphons and the XP and reputation bars, switchable per group.
- **SeamlessActionBars**: action button icons turn red when out of range and blue when you lack
  mana, rage or energy (both colors configurable), and keybind labels get shorter (`SM4`, `N5`,
  `WU`). It also adds endcap scale and textures, micro menu and bag bar options (hiding, a
  retail-style bag bar, free bag slots) and a fuller XP bar tooltip with rested details.
- **SeamlessCastbar**: cast time on the player, target and focus cast bars, the spell rank in the
  spell name, tick marks on channeled spells, the spell icon on the detached player bar, a
  configurable hold time after a cast, player bar size and movable target and focus bars, with
  each bar's settings in Edit Mode.

## Installation

Extract the release zip into your client's `Interface/AddOns` folder. Keep **Seamless** enabled
and choose the other addons in the game's AddOns screen, then reload. Every addon needs Seamless;
Seamless works on its own.

Open `/seamless` for the suite's settings window. Each addon has a header with separate pages:
General first, followed by its frame or feature pages. Core's Profiles page manages the whole
suite. Blizzard's AddOns options panels are currently not registered.

## Commands

| Command                                                        | Does                                                                                           |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `/seamless`                                                    | Opens the Seamless options.                                                                    |
| `/seamless loglevel <level>`                                   | Sets logging (`none`, `error`, `warn`, `info`, `verbose`, `debug`, `silly`).                   |
| `/seamless reset`                                              | Resets the current suite profile.                                                              |
| `/rl`, `/kb`                                                   | Reload the UI and start Quick Keybind Mode (each can be switched off under Seamless > Tweaks). |
| `/seamlessunitframes`, `/seamlesstooltip`                      | Open the addon's options; `reset` resets its current profile.                                  |
| `/seamlesschat`                                                | Opens the Chat options; `log` or `search <text>` opens the chat log, `save`/`apply` the sync.  |
| `/sdm`, `/seamlessdamagemeter`                                 | Opens the Damage Meter options; `/sdm new` adds a window, `/sdm show` shows hidden windows.    |
| `/seamlessui`                                                  | Opens the UI options; `reset` resets its current profile.                                      |
| `/seamlessdarkmode`, `/seamlessactionbars`, `/seamlesscastbar` | Open the addon's options.                                                                      |

## Edit Mode

Seamless adds a panel below the game's Edit Mode window. Its **Frames** list turns on previews of
the suite's own frames (damage meter windows, FPS display, target and focus cast bars, target of
target frames, combined bags, group loot) so they can be selected and moved. Selecting a frame shows its settings, including a Position section with
exact anchors and a quick anchor picker. With SeamlessUI enabled, Blizzard's own frames get the
same position controls and the Style settings of the other addons.

## Development

Node 20+; run `npm install` once. `npm run dev:link -- "<WoW>/Interface/AddOns"` links every addon
into a client; `/reload` picks up changes. `npm run format` formats the repo, `npm run check`
validates it (needs Lua 5.1 `luac`). `npm run package:local` builds the release archive with the
same packager the release workflows use.

To add an addon, create `SeamlessFeature/SeamlessFeature.toc` with `## Dependencies: Seamless`,
list its files, and add `Seamless/SeamlessFeature: SeamlessFeature` to `.pkgmeta` move-folders.
[CLAUDE.md](CLAUDE.md) and [Seamless/CLAUDE.md](Seamless/CLAUDE.md) document the structure and the
core API.

## Credits

Thanks to **p3lim** for [LibEditMode](https://github.com/p3lim-wow/LibEditMode), used for the
Edit Mode integration.

## License

[MIT](LICENSE)
