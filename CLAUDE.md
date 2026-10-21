# CLAUDE.md

Guidance for Claude Code in this repository. This file holds the map and the rules that apply
everywhere; each addon folder has its own `CLAUDE.md` with its load order and file map.

## What this is

Seamless is a modular World of Warcraft addon suite (Lua 5.1 / Ace3) for the client in the TOCs
(`16001` = WoW Forever). Each direct child folder with a same-named TOC is an independently
selectable addon:

- `Seamless/`: the required core: shared libraries, logger, locales, core settings, minimap
  launcher, `/seamless`, the shared options layout and the shared Edit Mode API.
- `SeamlessUnitframes/`: health colors, name display, class icons, PvP and quest icons and an
  optional legacy layout on the game's unit frames.
- `SeamlessTooltip/`: switchable tooltip enhancements.
- `SeamlessChat/`: the same chat setup on every character, history, copy/log windows and chat
  enhancements.
- `SeamlessDamageMeter/`: damage/threat meter windows on a shared live/archive combat-data service.
- `SeamlessUI/`: general UI improvements: XP bar tooltip, FPS display and extensions of the game's
  Edit Mode settings windows (position controls, other addons' Style sections).
- `SeamlessDarkmode/`: one shared tint for unit frame, minimap, action bar, gryphon and
  XP/reputation borders.
- `SeamlessActionBars/`: range/mana icon colors and short keybind labels on the game's action buttons.
- `SeamlessCastbar/`: cast time, spell rank, channel ticks and hold time on the game's cast bars.

Also at the root: `src/` (Node 20+ / TypeScript tooling, never shipped), `docs/`, `.github/`
(release workflows).

Every feature addon declares `## Dependencies: Seamless` and stores settings in a namespace of Core's `SeamlessDB`, sharing its AceDB profiles. Core works without any feature addon enabled; users enable or disable features
in the game's AddOns screen and reload. Tooling discovers addons automatically, but every addon
must be added to `.pkgmeta` `move-folders` (or its `ignore` list, to keep it out of releases).

## Working on the code

There is no build step. `npm run dev:link -- "<WoW>/Interface/AddOns"` (once; also honors
`WOW_ADDONS_DIR`) links every addon into a client, then `/reload` in game. `/seamless` opens the
options, `/seamless loglevel debug` shows the debug log.

## Commands (Node 20+, from the root after `npm install`)

| Command                            | Does                                                                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `npm run check`                    | typecheck, check:addons, check:lua, check:xml, format:check, in that order. Run it before finishing a change.                  |
| `npm run format`                   | Prettier on TS/JSON/Markdown/YAML, then StyLua on Lua. XML is left to the editor. `format:check` only reports.                 |
| `npm run check:addons`             | Every TOC entry exists (for every client language of `[TextLocale]`), features depend on `Seamless`, no dependency cycles.     |
| `npm run check:lua`                | `luac -p` on every addon Lua file (needs Lua 5.1 `luac` on PATH).                                                              |
| `npm run check:xml`                | Validates addon XML against Blizzard's `UI.xsd` (python + lxml); skipped without `../_data/wow_classic_beta`; `lib/` skipped.  |
| `npm run typecheck`                | `tsc --noEmit` on `src/`.                                                                                                      |
| `npm run locales:sync`             | Synchronizes the client locale files with the English catalogue (see Localization).                                            |
| `npm run dev:link -- <AddOns dir>` | Symlinks (junctions on Windows) every addon into a client; never replaces a path that isn't already our link.                  |
| `npm run package:addons`           | Quick `dist/Seamless-<version>.zip` of the addons in `.pkgmeta` `move-folders`, without `CLAUDE.md` files.                     |
| `npm run package:local`            | The BigWigs packager the release workflows use, locally and without uploading, into `.release/`. Needs bash (Git for Windows). |

Tests are plain Lua harnesses with mocks, run from the root: `lua src/tests/<name>.lua` (each
addon's `CLAUDE.md` names its own), plus `npx tsx src/tests/sync-locales.ts`. LuaLS
(`lua-language-server --check`, `.luarc.json`) is used ad hoc; `lib/` is excluded from LuaLS,
StyLua and Prettier.

## Tooling (`src/`)

ESM with `.js` extensions in relative imports; `tsx` runs the `.ts` directly; strict `tsc`.

- `config.ts`: `ROOT`, `CLIENT_LOCALES`, `CORE_ADDON`, `packageName()` (`.pkgmeta` `package-as`).
- `addons.ts`: `addonDirectories()`, `addonVersion`, `walkFiles`.
- One script per `npm run` command above; `zip.ts` is shared by the two packaging scripts.
- `generate-*.py`: regenerate the unit frame atlas tables and the damage meter bar texture.

## Releases

`.github/workflows/` runs the BigWigs packager on a pushed `v*` tag (`release-tag.yml`) and from
Actions > Run workflow (`release.yml`, `beta.yml`, `alpha.yml`, which tag the head of `main`
first); all call `package.yml`. `v1.1.0-beta1` is a beta, `v1.1.0-alpha1` an alpha, anything
else a release. The packager fills in `@project-version@` in the TOCs.

`.pkgmeta` decides what ships: **a new root file or folder that is not an addon must be added to
its `ignore` list**, or it ships inside the core's folder. Each site needs its repository secret
(`CF_API_KEY`, `WAGO_API_TOKEN`, `WOWI_API_TOKEN`) and its project id in `Seamless.toc`
(`## X-Curse-Project-ID`, `## X-Wago-ID`, `## X-WoWI-ID`); a site missing either is skipped.

## Shared Edit Mode controls

Terms for every Edit Mode request:

- **Main Edit Mode window**: Seamless's shared window below Blizzard's main Edit Mode window. It
  holds **GLOBAL options** and the **Frames** list.
- **GLOBAL options**: suite-wide controls in that window (`section = "options"`, the default).
  Add one only when the user explicitly asks for a global option.
- **Frames**: the list of checkboxes that let a frame take part in Edit Mode (preview/selection),
  registered with `core:RegisterEditModeOptions(id, { section = "frames", options = { ... } })`.
  These are not the frame's settings.
- **Edit Mode settings** / "add an option to Edit Mode": the settings window of the selected
  frame. Put the option there unless the user says otherwise.

`Seamless/CLAUDE.md` documents the APIs, row types and callbacks.

## Localization

All addon-authored text shown to users comes from the suite's AceLocale object:
`local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")`, then `L["Open"]`. That covers
options, frame names, menus, tooltips, dialogs, Edit Mode controls and chat/log messages. Game
content (names, chat, API errors), user-entered names and library-owned UI stay as they are;
technical IDs, slash-command tokens, registry keys, patterns and empty strings are not translated.

Add complete English phrases and format strings to `Seamless/locales/enUS.lua` first, in the
right section (shared phrases and frame names, then one section per addon), sorted within it.
Reuse common keys, keep placeholders, never build sentences from fragments, and use a distinct
key when the same English needs a different meaning. Never localize SavedVariables keys or API
IDs. Then run `npm run locales:sync`: it keeps existing translations in
`Seamless/locales/<locale>/strings.lua` and inserts commented English stubs in baseline order
(one double-quoted assignment per line; obsolete keys are reported, resolve them by hand).
Untranslated entries fall back to English.

## WoW addon constraints

- Lua 5.1 with Blizzard's restricted API: no `require`, `io`, `os` or loading external files.
  Every code file must be listed in its addon's TOC, in dependency order.
- Addons share one global namespace. Keep state in the addon's private table, declared per file as

  ```lua
  ---@type string, SeamlessUnitframes
  local appName, app = ...
  ```

  (`local _, app = ...` when the name is unused). When a file adds a member to `app`, add a
  matching `---@field` to that addon's `src/types.lua` (annotations only, not in the TOC).

- Sanctioned globals: SavedVariables tables, XML-required mixins/frames, and documented public
  frames (e.g. `SeamlessDamageMeterWindow<ID>`), all prefixed with their addon's name.
- SavedVariables are populated after `ADDON_LOADED`, not at file load; AceDB `OnInitialize` is the
  first safe place.
- Ace3 and WoW API types come from the `ketho.wow-api` VS Code extension
  (`.vscode/settings.json`), not from `lib/`; inherit from them rather than redeclaring the API.
- Never patch vendored libraries in `Seamless/lib/`.

## XML files

Every XML file starts with `<Ui xmlns="http://www.blizzard.com/wow/ui/">` and **no**
`xsi:schemaLocation`. Validation comes from `.vscode/settings.json` and `npm run check:xml`. Lua
mixin files are listed in the TOC _before_ the XML that uses them.

## Files with backslashes

Texture paths in Lua need `\\` (`"Interface\\Icons\\INV_Misc_Bag_10"`). Shell heredocs and inline
Python strip the doubled backslash; write such files with the Write/Edit tools.

## Blizzard's UI source and art (optional, read-only)

A developer may place Blizzard's exported interface files next to the repo:

- `../_data/wow_classic_beta/`: `/run ExportInterfaceFiles("code")` of the WoW Forever client.
- `../_data/BlizzardInterfaceArt/`: `/run ExportInterfaceFiles("art")`, every texture as `.blp`.

If present, **read them, never edit them**. Use the code for exact API signatures, event
payloads, templates and global strings (this client differs from retail and Classic), and the art
file list to verify texture paths (case-insensitive). Atlas names are not in the art export; find
them in XML under `wow_classic_beta`. Never list these files in a TOC or copy them into the repo.

## Textures and Blizzard frames: reuse art, remake code

- **Don't create new textures unless there is no other way**; prefer the game's textures and
  atlases (the client does not load `.png`). Ask before drawing anything.
- **Don't hard-reference a frame from retail or Classic WoW**: don't inherit its templates, call
  its mixins or anchor to it. Remake the look with our own template and mixin; its art may be
  reused freely.
- Code the WoW Forever client itself ships and loads (`Blizzard_*/Camelot/`, `Blizzard_SharedXML`
  templates such as `PortraitFrameBaseTemplate`) may be used directly; verify it is loaded first.
- A screenshot the user shares is a look reference, not a pixel template.
