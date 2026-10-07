# Seamless

A modular World of Warcraft addon suite for WoW Forever.

## Addons

- **SeamlessCore** (required): shared libraries, logging, profiles for shared settings, one
  minimap button and the `/seamless` options window.
- **SeamlessUnitframes** (optional): per-frame health colors for player, pet, target, focus,
  their targets and party. Choose default, class, reaction or combined colors, and configure
  the client's numeric target threat display.

## Installation and usage

Extract both `SeamlessCore` and `SeamlessUnitframes` from the release zip into your client's
`Interface/AddOns` directory. Keep Core enabled and select the feature addons you want in
WoW's AddOns screen, then reload. Each feature requires Core; Core can run alone.

- `/seamless`: open suite options.
- `/seamless loglevel <level>`: set shared logging (`none`, `error`, `warn`, `info`, `verbose`, `debug`, `silly`).
- `/seamless reset`: reset the current core profile (shared preferences only).
- `/seamlessunitframes`: open the Unit frames group.
- `/seamlessunitframes reset`: reset the current Unitframes profile.

Existing Unitframes settings and profiles remain in `SeamlessUnitframesDB`. Core preferences
use `SeamlessCoreDB`; logging and minimap preferences initially use the core defaults.
Each feature manages its own profiles, independently of the core profile.

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
