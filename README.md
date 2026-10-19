# Seamless

A modular World of Warcraft addon suite for WoW Forever.

## Addons

- **Seamless** (required, the core): shared libraries, logging, profiles for shared settings, one
  minimap button and the **Seamless** entry in WoW Settings > AddOns.
- **SeamlessUnitframes** (optional): per-frame health colors for player, pet, target, focus,
  their targets and party. Choose default, class, reaction or combined colors, and configure
  the client's numeric target threat display.

- **SeamlessTooltip** (optional): 23 switchable tooltip enhancements, including cursor/action-button
  anchoring, scale, shared-media backgrounds and borders, player/NPC text, status and raid markers,
  targets, health bars, item details and vendor prices, spell IDs and aura casters.

## Installation and usage

Extract `Seamless` and your chosen feature folders (`SeamlessUnitframes`, `SeamlessTooltip`) from the release zip into your client's
`Interface/AddOns` directory. Keep Core enabled and select the feature addons you want in
WoW's AddOns screen, then reload. Each feature requires Core; Core can run alone.

- `/seamless`: open Settings > AddOns > Seamless.
- `/rl`: reload the UI. Enabled by default; toggle it in Settings > AddOns > Seamless > Tweaks.
- Core can show the FPS counter on startup (off by default). Enable this in the Tweaks category; Ctrl+R still toggles the counter normally.
- `/seamless loglevel <level>`: set shared logging (`none`, `error`, `warn`, `info`, `verbose`, `debug`, `silly`).
- `/seamless reset`: reset the current core profile (shared preferences only).
- `/seamlessunitframes`: open the Unit Frames options.
- `/seamlessunitframes reset`: reset the current Unitframes profile.
- `/seamlesstooltip`: open the Tooltip options.
- `/seamlesstooltip reset`: reset the current Tooltip profile.

Existing Unitframes settings and profiles remain in `SeamlessUnitframesDB`; Tooltip keeps
`SeamlessTooltipDB` and all feature keys from the standalone addon. Core preferences
use `SeamlessDB`; logging and minimap preferences initially use the core defaults.
Each feature manages its own profiles, independently of the core profile.

Every addon has one entry under Settings > AddOns > Seamless, with tabs: General first, then the
addon's own sections, and Profiles last, where its profiles are selected, created, copied, deleted
and reset.

When replacing standalone SeamlessTooltip, replace its existing AddOns folder with the suite version
and install Core. Keep its SavedVariables file to retain profiles. A development junction pointing to
the old repository must be replaced with one pointing to this repo; `dev:link` refuses to overwrite it.

## Internal development modules

SeamlessChat, SeamlessDamageMeter, SeamlessUI and SeamlessDarkmode are unfinished and excluded from public release archives.
Their source remains in this repository for internal development and testing.

- **SeamlessDarkmode** (optional): tints the borders of the unit frames, the minimap and its
  addon buttons with one shared color, with a switch per group. Install beside Core and use `/seamlessdarkmode`. Includes independent `SeamlessDarkmodeDB` profiles.

- **SeamlessUI** (optional): the foundation for general UI improvements, with independent
  `SeamlessUIDB` profiles and a UI panel under Seamless. No improvements are implemented yet.
  Install its folder alongside Core and use `/seamlessui` to open settings or
  `/seamlessui reset` to reset its current profile.

- **SeamlessChat** (optional): shared chat layouts/colors/channels, input history, timestamps,
  persistent message history, copy and searchable log windows, clickable URLs, short channel labels,
  class colors, fading and backgrounds.

**SeamlessDamageMeter** (optional) provides multiple movable, resizable meter windows using
the client's `C_DamageMeter` combat statistics. Each window independently selects damage,
DPS, healing, HPS, absorbs, interrupts, dispels or damage taken, and current, overall or a
retained fight. Layouts and selections are saved in its own AceDB profiles.
Install its folder alongside Core. `/sdm` opens settings, `/sdm new` adds a window, and
`/sdm show` restores hidden windows. Windows use Blizzard's default meter art and fonts.
The gear menu adds or removes windows; the collapse button hides a window.
Drag the header or bottom-right corner to move or resize; mouse-wheel over
the window to scroll players. Enable Blizzard combat tracking in its settings if needed.
The "SeamlessUI" panel below Edit Mode has a "Seamless Damage Meter" checkbox controlling previews of active windows,
including temporarily hidden slots. It does not change normal window visibility or activation.
Edit Mode displays sample bars with classic WoW
characters, class colors and example amounts instead of reading live combat data.
Collapsed windows temporarily expand to show the preview. Select a window to move it
or adjust its scale. Use the Width/Height sliders in its Edit Mode dialog or drag the
visible bottom-right grip to resize it. Leaving Edit Mode restores live data and the saved collapse state.
Edit Mode changes update
the window's position and scale overrides in the current Damage Meter profile.
Position, size, scale and anchor links are remembered separately for each Edit Mode layout;
new layouts start with the current geometry.
The built-in meter's visibility remains controlled by the game's own settings; keep tracking
enabled for data. Fight history belongs to Blizzard and may expire or reset independently
of saved layouts. This first version intentionally focuses on the base windows, without
spell drilldowns or an independent combat recorder.

## Development

Node 20+; run `npm install` once. `npm run dev:link -- "<WoW>/Interface/AddOns"` links every addon
into a client; rerun it after this upgrade to link Core too. `/reload` picks up changes.
`npm run format` formats the repo; `npm run check` validates it (Lua 5.1 `luac` required).
`npm run package:addons` creates a source zip of the public addons in `dist/`; it leaves version
tokens unchanged. `npm run package:local` uses the release packager and replaces version tokens.
Both include only Core, Tooltip and Unitframes as listed in `.pkgmeta`. Use the release packager
for distributable archives.

To add a feature, create `SeamlessFeature/SeamlessFeature.toc` with `## Dependencies: Seamless`,
list its runtime files, and, once ready for public release, add `Seamless/SeamlessFeature: SeamlessFeature` to `.pkgmeta` move-folders.
Use the core API documented in [Seamless/CLAUDE.md](Seamless/CLAUDE.md) for shared options
and logging. Keep feature state in its private addon table and its own SavedVariables.
No core code change is needed to register another feature.

## Credits

Thanks to **p3lim** for the **LibEditMode** library
used to integrate the damage meter windows with Edit Mode.

- [LibEditMode on GitHub](https://github.com/p3lim-wow/LibEditMode)

## License

[MIT](LICENSE)
