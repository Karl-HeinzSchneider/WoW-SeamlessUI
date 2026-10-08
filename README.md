# Seamless

A modular World of Warcraft addon suite for WoW Forever.

## Addons

- **SeamlessCore** (required): shared libraries, logging, profiles for shared settings, one
  minimap button and a native **Seamless** category in WoW Settings.
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

Extract `SeamlessCore` and your chosen feature folders (`SeamlessUnitframes`, `SeamlessTooltip`, `SeamlessChat`) from the release zip into your client's
`Interface/AddOns` directory. Keep Core enabled and select the feature addons you want in
WoW's AddOns screen, then reload. Each feature requires Core; Core can run alone.

- `/seamless`: open Settings > AddOns > Seamless.
- `/rl`: reload the UI. Enabled by default; toggle it under Seamless > Tweaks in Settings.
- Core also shows the FPS counter on startup by default. Disable this under Seamless > Tweaks; Ctrl+R still toggles the counter normally.
- `/seamless loglevel <level>`: set shared logging (`none`, `error`, `warn`, `info`, `verbose`, `debug`, `silly`).
- `/seamless reset`: reset the current core profile (shared preferences only).
- `/seamlessunitframes`: open the Unit Frames subcategory.
- `/seamlessunitframes reset`: reset the current Unitframes profile.
- `/seamlesstooltip`: open the Tooltip subcategory.
- `/seamlesstooltip reset`: reset the current Tooltip profile.
- `/seamlesschat`: open the Chat subcategory; `save`/`apply` manage its shared chat setup.
- `/seamlesschat log` or `/seamlesschat search <text>`: open the searchable chat log.
- `/seamlesschat reset`: reset the current Chat profile.

Existing Unitframes settings and profiles remain in `SeamlessUnitframesDB`; Tooltip keeps
`SeamlessTooltipDB` and all feature keys from the standalone addon. Core preferences
use `SeamlessCoreDB`; logging and minimap preferences initially use the core defaults.
Each feature manages its own profiles, independently of the core profile.
Chat retains `SeamlessChatDB`, `SeamlessChatHistoryDB` and `SeamlessChatLogDB`, including existing
sync snapshots, input history and per-character message data.

Settings use native checkboxes and dropdowns and participate in WoW's Settings search.
Each category includes controls to select, create, copy, delete and reset its AceDB profiles.
Copying, deletion and reset ask for confirmation. Native Defaults resets controls without switching profiles.

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

## License

[MIT](LICENSE)
