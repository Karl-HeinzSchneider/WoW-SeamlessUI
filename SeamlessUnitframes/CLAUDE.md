# SeamlessUnitframes (the addon)

The distributable addon: everything in this folder ships; the packager copies it to the top of the
zip (`.pkgmeta`). User settings live in `SeamlessUnitframesDB` (AceDB).

## Load order (`SeamlessUnitframes.toc`)

The TOC is the manifest and the source of truth for the load order; **every new Lua/XML file must
be listed**. The order follows these rules:

1. `embeds.xml` first: every vendored library in dependency order (LibStub → CallbackHandler →
   Ace\* → LibDataBroker → LibDBIcon).
2. `src\core\`: `logger.lua` first (everything logs), `db.lua` (the defaults `ace.lua` needs),
   `ace.lua` (creates `app.addon`), `unitframes.lua` (the frame list `options.lua` builds its groups
   from), then the Ace modules that hang off the addon (`options.lua`, `minimapbutton.lua`).
3. Feature code after the core: `src\<feature>\*.lua`, or `modules\<name>\` with a loader XML
   per module listed in a `modules\modules.xml`. In UI code, each Lua mixin comes before the XML
   that names it.
4. `SeamlessUnitframes.lua` last; it only logs.

## Files

### `src/core/`

- `logger.lua` — `app.logger`: leveled, colored chat logging; `log("x")` is `log:info("x")`,
  `log:debug("Looted %s x%d", link, count)` formats, `log:chat(...)` is unfiltered user-facing
  output, `log:dump(tbl)` prints a table at DEBUG. The threshold comes from `profile.logLevel`.
- `db.lua` — `app.dbDefaults` for AceDB: `profile` = user settings (`logLevel`, `minimap`;
  `minimapPos` = 200° so an undragged button doesn't sit on LibDBIcon's shared 225° default;
  `unitFrames[key]` = the settings of one unit frame, defaults for every key via AceDB's `["**"]`,
  overridden per key where a frame needs other defaults),
  `char` = per-character data, `global.dbVersion` for future migrations.
- `ace.lua` — `app.addon`, the AceAddon object (AceConsole, AceEvent). `OnInitialize` opens
  `app.db`, wires the profile callbacks to `OnProfileRefresh` (log level, then every module's
  `OnProfileRefresh`) and registers `/seamlessunitframes`; `OnSlashCommand` handles `options` (the
  default), `loglevel <level>` and `reset`. Register game events in `OnEnable`.
- `options.lua` — `app.options`: the user options as **one** AceConfig table (plus the AceDBOptions
  profiles tab), registered in the game's Settings panel (`AddToBlizOptions`) and opened in a
  standalone AceConfigDialog window by `Open()`. A new option goes only here. `Refresh()` redraws
  them after a setting changed elsewhere. Besides the general options there is one group per
  `app.unitFrames.list` entry, built by `UnitFrameOptions`; a new per-frame option goes there.
- `unitframes.lua` — `app.unitFrames`: the game's unit frames this addon changes (`list`: player,
  pet, target, target of target, focus, target of focus, party; `key` is the key in
  `profile.unitFrames`), `Exists(entry)`, `KeyOf(unitFrame)` (which entry a frame belongs to; the
  party member frames are the children of `PartyFrame`) and `All()` (every frame that exists now).
- `minimapbutton.lua` — `app.minimapButton`, a LibDataBroker launcher + LibDBIcon that opens the
  options and honors `profile.minimap`. Optional: to drop it, delete the file, its TOC line, the
  `minimap` option and `profile.minimap`.

### `src/healthcolor/`

- `healthcolor.lua` — `app.healthColor`: health bar colors on the game's own unit frames, per frame
  from `profile.unitFrames[key].healthBarColor`: `default` (the game's green), `class` (players),
  `reaction` (`UnitSelectionColor`, the game's own unit reaction colors — not the muted
  `FACTION_BAR_COLORS` — grey for a tap-denied mob) or `classReaction`
  (class for players, reaction for the rest). It post-hooks `UnitFrameHealthBar_Update`, swaps
  the bar's green fill atlas for the game's white `…-Bar-Health-Status` variant and tints it; a
  hook on each bar texture's `SetAtlas` puts the white atlas back when the game swaps it (target
  classification, vehicles), and `UNIT_FACTION` recolors on reaction changes. A pet takes the
  player's class; disconnected players and units whose class or reaction is secret keep the
  default color. It restores only the bars it colored. `Refresh()` reapplies after a setting
  changed.

### Annotations (not in the TOC)

- `src/types.lua` — the private-table class `SeamlessUnitframes` (`app.*` fields) and
  `SeamlessUnitframes.DB`. When a file adds a member to `app`, add a matching `---@field` here.

### Other

- `lib/` — vendored Ace3, LibStub, CallbackHandler, LibDBIcon (+ LibDataBroker). Excluded from
  LuaLS, StyLua and Prettier; update by replacing the folder, don't patch. `embeds.xml` loads all
  of them; drop a line there (not the folder) to skip a library the addon doesn't use.
- `assets/` — textures the game files cannot provide (`assets/core/coffee.tga` is the TOC notes'
  donation icon).

## Conventions

- Prototype-style Ace modules: define methods on a local `module` table and pass it to
  `addon:NewModule("Name", module, …)`; state lives on the object Ace returns (see
  `minimapbutton.lua`). A module that depends on profile settings defines `OnProfileRefresh`.
- New user settings get a default in `db.lua` and an entry in `options.lua`.
