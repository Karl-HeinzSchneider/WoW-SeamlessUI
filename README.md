# Seamless

A modular World of Warcraft addon suite for WoW Forever.

## Addons

- **SeamlessCore** (required): shared libraries, logging, profiles for shared settings, one
  minimap button and the **Seamless** entry in WoW Settings > AddOns.
- **SeamlessUnitframes** (optional): per-frame health colors for player, pet, target, focus,
  their targets and party. Choose default, class, reaction or combined colors, and configure
  the client's numeric target threat display.

- **SeamlessTooltip** (optional): 23 switchable tooltip enhancements, including cursor/action-button
  anchoring, scale, shared-media backgrounds and borders, player/NPC text, status and raid markers,
  targets, health bars, item details and vendor prices, spell IDs and aura casters.

- **SeamlessChat** (optional): shared chat layouts/colors/channels, input history, timestamps,
  persistent message history, copy and searchable log windows, clickable URLs, short channel labels,
  class colors, fading and backgrounds.

## Installation and usage

**SeamlessDamageMeter** (optional) provides multiple movable, resizable meter windows using
the client's `C_DamageMeter` combat statistics. Each window independently selects damage,
DPS, healing, HPS, absorbs, interrupts, dispels or damage taken, and current, overall or a
retained fight. Layouts and selections are saved in its own AceDB profiles.
Install its folder alongside Core. `/sdm` opens settings, `/sdm new` adds a window, and
`/sdm show` restores hidden windows. Windows use Blizzard's default meter art and fonts.
The gear menu adds or removes windows; the collapse button hides a window.
Drag the header or bottom-right corner to move or resize; mouse-wheel over
the window to scroll players. Enable Blizzard combat tracking in its settings if needed.
All ten windows also appear in Edit Mode Expanded's Expanded list, including inactive
and hidden slots, named "Seamless Damage 1" through "Seamless Damage 10". Inactive slots
are unchecked by default; check their entry to preview them. Select a window to move it
or adjust its scale. Leaving Edit Mode restores normal visibility without activating
inactive windows. Edit Mode changes update
the window's position and scale overrides in the current Damage Meter profile.
The built-in meter's visibility remains controlled by the game's own settings; keep tracking
enabled for data. Fight history belongs to Blizzard and may expire or reset independently
of saved layouts. This first version intentionally focuses on the base windows, without
spell drilldowns or an independent combat recorder.

Extract `SeamlessCore` and your chosen feature folders (`SeamlessUnitframes`, `SeamlessTooltip`, `SeamlessChat`) from the release zip into your client's
`Interface/AddOns` directory. Keep Core enabled and select the feature addons you want in
WoW's AddOns screen, then reload. Each feature requires Core; Core can run alone.

- `/seamless`: open Settings > AddOns > Seamless.
- `/rl`: reload the UI. Enabled by default; toggle it on the Tweaks tab of Seamless in Settings.
- Core also shows the FPS counter on startup by default. Disable this on the Tweaks tab; Ctrl+R still toggles the counter normally.
- `/seamless loglevel <level>`: set shared logging (`none`, `error`, `warn`, `info`, `verbose`, `debug`, `silly`).
- `/seamless reset`: reset the current core profile (shared preferences only).
- `/seamlessunitframes`: open the Unit Frames options.
- `/seamlessunitframes reset`: reset the current Unitframes profile.
- `/seamlesstooltip`: open the Tooltip options.
- `/seamlesstooltip reset`: reset the current Tooltip profile.
- `/seamlesschat`: open the Chat options; `save`/`apply` manage its shared chat setup.
- `/seamlesschat log` or `/seamlesschat search <text>`: open the searchable chat log.
- `/seamlesschat reset`: reset the current Chat profile.

Existing Unitframes settings and profiles remain in `SeamlessUnitframesDB`; Tooltip keeps
`SeamlessTooltipDB` and all feature keys from the standalone addon. Core preferences
use `SeamlessCoreDB`; logging and minimap preferences initially use the core defaults.
Each feature manages its own profiles, independently of the core profile.
Chat retains `SeamlessChatDB`, `SeamlessChatHistoryDB` and `SeamlessChatLogDB`, including existing
sync snapshots, input history and per-character message data.

Every addon has one entry under Settings > AddOns > Seamless, with tabs: General first, then the
addon's own sections, and Profiles last, where its profiles are selected, created, copied, deleted
and reset.

When replacing standalone SeamlessTooltip or SeamlessChat, replace its existing AddOns folder with the suite version
and install Core. Keep its SavedVariables file to retain profiles. A development junction pointing to
the old repository must be replaced with one pointing to this repo; `dev:link` refuses to overwrite it.

## Development

Node 20+; run `npm install` once. `npm run dev:link -- "<WoW>/Interface/AddOns"` links every addon
into a client; rerun it after this upgrade to link Core too. `/reload` picks up changes.
`npm run format` formats the repo; `npm run check` validates it (Lua 5.1 `luac` required).
`npm run package:addons` creates a suite zip in `dist/`; `npm run package:local` uses the release packager.

To add a feature, create `SeamlessFeature/SeamlessFeature.toc` with `## Dependencies: SeamlessCore`,
list its runtime files, and add `Seamless/SeamlessFeature: SeamlessFeature` to `.pkgmeta` move-folders.
Use the core API documented in [SeamlessCore/CLAUDE.md](SeamlessCore/CLAUDE.md) for shared options
and logging. Keep feature state in its private addon table and its own SavedVariables.
No core code change is needed to register another feature.

## Credits

Thanks to **Teelo** for Edit Mode Expanded and the **EditModeExpanded-1.0** library
used to integrate the damage meter windows with Edit Mode.

- [Edit Mode Expanded on GitHub](https://github.com/teelolws/EditModeExpanded)
- [Edit Mode Expanded on CurseForge](https://www.curseforge.com/wow/addons/edit-mode-expanded)

## License

[MIT](LICENSE)
