# CLAUDE.md

Guidance for Claude Code when working in this repository. This file holds the map and the rules
that apply everywhere; the addon folder has its own `CLAUDE.md` with its load order and file map.

## What this is

Seamless is a modular World of Warcraft addon suite (Lua 5.1 / Ace3), targeting the
client in the TOCs (`16001` = WoW Forever). Each direct child folder with a same-named
TOC is an independently selectable addon.

- `Seamless/`: required shared libraries, logger, AceDB core settings, minimap launcher,
  `/seamless`, the "Seamless" options panel and the AceConfig options layout every addon uses
  (General tab, the addon's tabs, Profiles tab). See its `CLAUDE.md` for the public API.
- `SeamlessUnitframes/`: optional unit-frame features, depending on Seamless. Keeps
  `SeamlessUnitframesDB` and its existing profiles. See its `CLAUDE.md`.
- `SeamlessTooltip/`: optional tooltip features, depending on Seamless. Keeps
  `SeamlessTooltipDB` and existing profiles. See its `CLAUDE.md`.
- `SeamlessChat/`: optional chat sync, history, copy/log windows and chat enhancements. Keeps
  its profile and per-character SavedVariables. See its `CLAUDE.md`.
- `SeamlessDamageMeter/`: optional windows and a shared live/archive combat-data service.
  Saves public per-character fight history independently of appearance profiles. See its `CLAUDE.md`.
- `src/`: Node 20+ / TypeScript tooling, never shipped.
- `SeamlessUI/`: optional general UI improvements, with independent `SeamlessUIDB` profiles.
  Currently an internal scaffold. See its `CLAUDE.md`.
- `SeamlessDarkmode/`: optional shared tint for unit frame, minimap and minimap button borders, with independent profiles.
  Internal pending in-game validation. See its `CLAUDE.md`.
- `SeamlessActionBars/`: optional range/mana icon colors and short keybind labels on the game's
  action buttons, with independent profiles. Internal pending in-game validation. See its `CLAUDE.md`.
- `SeamlessCastbar/`: optional cast time, spell rank, channel ticks and hold time on the game's player,
  target and focus cast bars, with independent profiles. Internal pending in-game validation. See its `CLAUDE.md`.
- `.github/`: release workflows using the BigWigs packager.

Every feature addon must declare `## Dependencies: Seamless`; `check:addons` enforces
this and checks dependency cycles. Addons are discovered automatically by tooling; add each
release-ready addon to `.pkgmeta` move-folders for releases. Internal addons must stay in its ignore list.
Only Core, Tooltip and Unitframes currently ship; Chat, DamageMeter, UI, Darkmode, ActionBars and Castbar are internal. Users enable or disable feature addons
in the game's AddOns screen and reload. Core works without any feature addon enabled.

## Working on the code

WoW addons are plain Lua/XML files loaded by the game; there is no build step. To try a change:
`npm run dev:link -- "<WoW>/Interface/AddOns"` (once; links every addon directory, also honors
`WOW_ADDONS_DIR`) and `/reload` in-game. `/seamless` opens the suite options,
`/seamless loglevel debug` shows the debug log.

## Commands (Node 20+, run from the root after `npm install` once)

| Command                            | Does                                                                                                                                                                                                                                |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `npm run check`                    | Everything below that validates, in order: typecheck, addons, Lua syntax, XML schema, formatting. Run it before finishing a change.                                                                                                 |
| `npm run format`                   | Prettier (`.prettierrc.json`, `.prettierignore`) on TS/JSON/Markdown/YAML, then StyLua (`stylua.toml`, `.styluaignore`) on Lua. Leaves XML to the editor. `npm run format:check` only reports.                                      |
| `npm run check:addons`             | Every TOC load entry exists (a `[TextLocale]` entry for every client language), all feature addons depend on `Seamless`, no dependency cycles.                                                                                      |
| `npm run check:lua`                | `luac -p` on every addon Lua file (needs a Lua 5.1 `luac` on PATH).                                                                                                                                                                 |
| `npm run check:xml`                | Validates every addon XML against Blizzard's `UI.xsd` via python + lxml; skipped when `../_data/wow_classic_beta` is absent; `lib/` is not checked.                                                                                 |
| `npm run typecheck`                | `tsc --noEmit` on `src/`.                                                                                                                                                                                                           |
| `npm run dev:link -- <AddOns dir>` | Symlink (junction on Windows) every addon into a client; refuses to replace a path that isn't already our link.                                                                                                                     |
| `npm run package:addons`           | Deterministic `dist/Seamless-<version>.zip` of public addons listed in `.pkgmeta` move-folders (gitignored), without `CLAUDE.md` files.                                                                                             |
| `npm run package:local`            | The BigWigs packager the release workflows use (`.pkgmeta`), run locally without uploading: addon folders and zip in `.release/` (gitignored). Extra `release.sh` options go after `--`. On Windows it needs Git for Windows' bash. |

Static checks also used ad hoc: `lua-language-server --check` (config in `.luarc.json`; `lib/` is
excluded from LuaLS, StyLua and Prettier).

`npm run locales:sync` synchronizes translation stubs with the English catalogue.
Run `npx tsx src/tests/sync-locales.ts` and `lua src/tests/locales.lua` for locale regressions.

## Tooling (`src/`)

ESM with `.js` extensions in relative imports; `tsx` runs the `.ts` directly; strict `tsc`.

- `config.ts` â€” `ROOT`, `CLIENT_LOCALES` (every `[TextLocale]` value), `packageName()` (the
  `package-as` of `.pkgmeta`, used for zip names; `CORE_ADDON` identifies the core addon, Seamless).
- `addons.ts` â€” `addonDirectories()` (every direct child with a same-named `.toc`),
  `addonVersion`, `walkFiles`.
- `check-addons.ts`, `check-lua.ts`, `check-xml.ts`, `link-addons.ts`, `package-addons.ts`,
  `package-local.ts` â€” one per `npm run` script above.
- `zip.ts` â€” `createZip` (stored, fixed timestamps), `directoryEntries`, `fileNamePart` (a TOC
  version as a file name), shared by the two packaging scripts.

## Releases

`.github/workflows/` runs the BigWigs packager on a pushed `v*` tag (`release-tag.yml`) and from
Actions > Run workflow (`release.yml`, `beta.yml`, `alpha.yml`, which tag the head of `main`
first); all four call `package.yml`. The tag decides the type: `v1.1.0-beta1` is a beta,
`v1.1.0-alpha1` an alpha, anything else a release. `## Version: @project-version@` in the TOC is
filled in by the packager.

What goes into the zip is set by `.pkgmeta` â€” **a new root file or folder that is not an addon
must be added to its `ignore` list**, or it ships inside the addon's folder. Uploads need the
repository secrets `CF_API_KEY`, `WAGO_API_TOKEN`, `WOWI_API_TOKEN` and the project ids in the TOC
(`## X-Curse-Project-ID`, `## X-Wago-ID`, `## X-WoWI-ID`); a site without both is skipped.

## Shared Edit Mode controls

These terms and placement rules apply to every Edit Mode request:

- **Main Edit Mode window** means Seamless's shared window anchored to Blizzard's main
  Edit Mode window in the middle of the screen. It contains **GLOBAL options** and a
  **Frames** list where users activate or deactivate Edit Mode for individual frames.
- **GLOBAL options** are suite-wide controls in that main window. Add an option there
  only when the user explicitly requests a global option. Frame-specific settings belong
  in the selected frame's settings window.
- **Frames** is the heading for the main window's frame activation/deactivation list.
  Entries here control whether a frame participates in Edit Mode; they are not the
  frame's individual settings.
- **Edit Mode settings** or a request to **add an option to Edit Mode** means the settings
  window shown when the user selects the relevant frame in Edit Mode. Put the requested
  option in that frame's settings window unless the user explicitly specifies otherwise.

Register frame activation/deactivation (preview/movability) checkboxes in the main window with
`core:RegisterEditModeOptions(id, { section = "frames", options = { ... } })`.
They belong under the shared **Frames** heading. `section = "options"` (the default) places
controls in the main window's GLOBAL options area; use it only for explicitly requested
global options. See `Seamless/CLAUDE.md` for the APIs, row types and callbacks used by
the shared panel and selected-frame settings.

## Localization

All addon-authored text displayed to users must come from the suite's AceLocale object:
`local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")`, then `L["Open"]`.
This applies to every addon, including options, frame names, menus, tooltips, dialogs,
Edit Mode controls and chat/log messages. Do not introduce literal English display text.
Game-provided content (player/item/spell names, chat messages, API error messages), user-entered
names and library-owned UI remain owned by their source. Technical IDs, slash-command tokens,
texture/font registry keys, patterns and empty strings are not translated.

Add complete English phrases and format strings to `Seamless/locales/enUS.lua` first.
Keep generic/shared phrases and frame names together, then addon-specific sections; sort
within each section. Reuse common keys, preserve format placeholders and avoid concatenating
sentence fragments so translators can change word order. Use a distinct descriptive key when
the same English phrase needs different meanings. Never localize SavedVariables keys or API IDs.
Run `npm run locales:sync` after changing the baseline. It creates guarded client files under
`Seamless/locales/<locale>/strings.lua`, keeps existing translations, and inserts commented English
stubs in exactly the baseline order. Uncomment and replace the value to translate it. Use one
double-quoted key/value assignment per line; resolve obsolete keys explicitly when reported.
Core loads English first and only the client's `[TextLocale]` file afterward. Untranslated entries
fall back to English; `enGB` uses AceLocale's English normalization.

## WoW addon constraints

- Lua 5.1 with Blizzard's restricted API. No `require`, `io`, `os`, or `loadstring` of external
  files; every code file must be listed in its addon's TOC, in dependency order, or it will not
  load.
- Addons share one global namespace. Keep state in the private table passed to each file. Each addon has its own private table. A Unitframes file
  that uses it starts with

  ```lua
  ---@type string, SeamlessUnitframes
  local appName, app = ...
  ```

  (`local _, app = ...` when the name is unused, or LuaLS flags it). The `---@type` line gives the
  language server completion on `app.*`. When a file adds a member to `app`, add a matching
  `---@field` to `SeamlessUnitframes/src/types.lua`.

- The only sanctioned globals are the SavedVariables tables and XML-required mixins/frames, which
  are prefixed `SeamlessUnitframesâ€¦`.
- Persistent state lives only in tables declared via `## SavedVariables`; they are populated after
  `ADDON_LOADED`, not at file-load time (AceDB `OnInitialize` is the first safe place).
- Ace3 types (`AceAddon`, `AceDBObject-3.0`, `AceDB.Schema`, â€¦) come from the `ketho.wow-api`
  VS Code extension (`.vscode/settings.json` â†’ `Lua.workspace.library`), not from `lib/`;
  inherit from them rather than redeclaring the API.

## XML files

Every XML file starts with `<Ui xmlns="http://www.blizzard.com/wow/ui/">` and **no**
`xsi:schemaLocation` â€” the client ignores it and a wrong path makes the VS Code XML extension
report errors. Schema validation comes from `xml.fileAssociations` in `.vscode/settings.json`
(mapping `**/*.xml` to `../_data/wow_classic_beta/.../Blizzard_SharedXML/UI.xsd`) and from
`npm run check:xml`. Lua mixin files must be listed in the TOC _before_ the XML that references
them.

## Files with backslashes

Lua strings for texture paths need `\\` (`"Interface\\Icons\\INV_Misc_Bag_10"`). Shell heredocs
and inline Python strip the doubled backslash; write such files with the Write/Edit tools (or a
script file with raw strings).

## Optional: Blizzard's own UI source and art for reference

A developer may place Blizzard's exported interface files in `../_data/` (a sibling of the repo,
`E:\Projects\_data\` here â€” outside the repo, so nothing needs gitignoring):

- `../_data/wow_classic_beta/` â€” the WoW Forever (classic beta) client's `/run ExportInterfaceFiles("code")`: Lua/XML of all
  FrameXML/AddOns.
- `../_data/BlizzardInterfaceArt/` â€” from `/run ExportInterfaceFiles("art")`: every texture as
  `.blp` under `BlizzardInterfaceArt/Interface/...`.

If they exist, **read them, never edit them**:

- Code: look up exact API signatures/return values, event payloads, frame templates and global
  strings. Prefer it over memory; this client's API differs from retail and from Classic.
- Art: verify that a texture path used in code exists (case-insensitive) and browse for suitable
  icons/textures by name. `.blp` can't be viewed; the file list is what matters. Atlas names
  (`atlas="..."`) are _not_ in the export â€” find them in XML usages under `wow_classic_beta`.

Never list anything from these folders in a TOC or copy files out of them into the repo.

## Textures and Blizzard frames: reuse art, remake code

- **Don't create new textures unless there is no other way.** Prefer the game's own textures
  and atlases (they scale with the frame and need no shipping; the client does not load `.png`).
  If something really must be drawn, ask first.
- **Don't hard-reference a frame from retail or Classic WoW.** Don't inherit its templates, call
  its mixins, anchor to its frames or name it as the thing being copied in comments or docs.
  Learn how it is built, then remake the look with our own template and mixin; naming it as "an
  example" in a comment is fine. Its _art_ (atlases, textures) may be reused freely.
- On WoW Forever, code the client itself ships (`Blizzard_*/Camelot/` and shared templates it
  loads such as `Blizzard_SharedXML`) may be leaned on directly: inheriting from e.g.
  `PortraitFrameBaseTemplate` or `PagingControlsTemplate` is fine. Verify the file is loaded by
  this client before depending on it.
- A screenshot the user shares is a look reference, not a template to reproduce pixel by pixel.
