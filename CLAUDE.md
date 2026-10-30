# CLAUDE.md

Repository-wide guidance. Read the applicable nested `CLAUDE.md` before changing an addon
or the custom configuration window.

## `description.md` is human-only

`description.md` in the repo root belongs to the maintainer. Agents must never write to it:
don't create, edit, format, rename, move or delete it, even when asked to update docs. Reading it
is fine. It is excluded from packaging (`.pkgmeta`) and from `npm run format` (`.prettierignore`).

## What this is

Seamless is a modular WoW Forever addon suite (Lua 5.1 / Ace3; client version in the TOCs).
`Seamless/` is the required core; the other `Seamless*/` folders are independently selectable
feature addons. `src/` holds Node 20+ / TypeScript tooling; `docs/` holds design references.

Every feature declares `## Dependencies: Seamless` and uses an AceDB namespace in Core's
`SeamlessDB`. Core works with all features disabled. Profile changes and slash-command resets
apply to the whole suite. Keep legacy SavedVariables for one-time migration; new settings use
namespaces. Read `app.db.profile` at use time, never cache it across profile changes.
See `Seamless/CLAUDE.md` for database registration.

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

## Tooling and packaging

TypeScript uses strict ESM with `.js` extensions in relative imports; `tsx` runs `.ts` directly.
`src/addons.ts` discovers addons; `src/config.ts` owns shared paths and package configuration.

`.pkgmeta` controls releases: add each addon to `move-folders` (or `ignore` if unshipped).
**Add new non-addon root files/folders to `ignore`**, or they ship inside Core. Release workflows
use the BigWigs packager, which substitutes `@project-version@` in TOCs. Never publish a release
unless requested.

## Settings pages

Seamless owns one AceConfig-shaped settings format and its custom window. Blizzard's AddOns
options panels are intentionally not registered. AceDBOptions is used only to build Core's
Profiles page; AceConfigRegistry, AceConfigDialog and AceGUI are not loaded for settings.

Every navigation page is a separate file in its addon's `src/options/` folder. Declare
`app.optionPages.<key> = { defaults = <AceDB schema fragment>, config = <group>, tooltip = <optional resolver> }`.
The `config` group uses readable `type`, `name`, `order`, `args`, `get`, `set`, `disabled`,
`hidden`, `values`, `min`, `max` and `step` fields. `new`, `blizzard`, `editMode` and `default`
are native fields of our schema: they stay on the table and are never stripped.

Keep the page's defaults beside its declaration, at existing SavedVariables paths. Database
files contain only the schema skeleton and non-option data. Before AceDB initializes,
`core:GetOptionsDefaults(app.optionPages, app.dbDefaults)` combines the page fragments and
rejects conflicting defaults. Never change saved keys as part of reorganizing pages.

Each addon registers once with `core:RegisterOptions(addonName, { title = L["Title"],
pages = app.optionPages })`. Its header contains the page groups in `order`; General is first,
and only Core has Profiles. List every page in the TOC before the registration module and before
AceDB's `OnInitialize` runs. Page declarations must not read a live profile at file load.

Switchable sections use a plain group with `feature = true`, `settings = function() return
app.db.profile.feature end`, `toggled`, optional `changed`, and subordinate controls in `args`.
Core supplies their accessors, Enable switch and disabled behavior. With no subordinate controls,
the feature becomes one named toggle. An explicit `disabled` must include the feature-off check
for subordinate controls while leaving the Enable switch usable. Getters always resolve the
current profile; never cache its tables. Use small shared helpers for repeated controls such as
position, scale and window inheritance, rather than factories for entire pages.

`tooltip(path)` returns a declared default and an optional per-character boolean. A control's
own `default` wins. Dynamic defaults may come from `GetCVarOptionInfo` or native position
bindings. Castbar and Unitframes derive their Edit Mode Style rows from these same page trees;
do not declare those settings a second time.

`OpenOptions(addonName, page)` opens a page; `RefreshOptions(addonName)` schedules its existing
controls to refresh after the current callback. The window and controls live in `src/config/`;
read its `CLAUDE.md` when changing rendering. Run `lua src/tests/config-options.lua`, plus the
affected addon's harnesses. Check navigation, controls, defaults, profile changes and Edit Mode
in game.

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

Moving a frame always breaks its anchor: when the user drags a frame away (Edit Mode or otherwise),
store it on UIParent exactly where it was dropped, like Blizzard's Edit Mode. Never keep the old
anchor frame and re-measure offsets from it. Frames anchored to the moved frame keep following it.

`Seamless/CLAUDE.md` documents the APIs, row types and callbacks.

## Localization

All addon-authored text shown to users comes from the suite's AceLocale object:
`local L = LibStub("AceLocale-3.0"):GetLocale("Seamless")`, then `L["Open"]`. That covers
options, frame names, menus, tooltips, dialogs, Edit Mode controls and chat/log messages. Game
content (names, chat, API errors), user-entered names and library-owned UI stay as they are;
technical IDs, slash-command tokens, registry keys, patterns and empty strings are not translated.

Add complete English phrases and format strings to `Seamless/locales/enUS.lua` first, in the
right section (shared phrases and frame names, then one section per addon, then one
`-- Embed: <Library>` section per embedded library, holding all strings its adapter passes in),
sorted within it.
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
