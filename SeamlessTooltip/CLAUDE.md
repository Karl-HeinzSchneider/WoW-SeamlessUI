# SeamlessTooltip

Optional tooltip addon: switchable enhancements of the game's tooltips. Settings and profiles
live in the `SeamlessTooltip` namespace in `SeamlessDB`; feature keys there are persistent (see Features and conventions).

## Load order and ownership

1. `src/core/bootstrap.lua`: obtains Core through AceAddon and shares its logger.
2. `db.lua`, then `ace.lua`: defaults, AceAddon/AceDB lifecycle and `/seamlesstooltip` (opens
   the Tooltip panel). `loglevel` delegates to Core; `reset` resets only Tooltip's profile.
3. `features.lua`: nested feature modules and their options sections (`OptionsByCategory`). Defaults are declared
   at file load; all modules exist before AceDB initialization.
4. `media.lua`: LibSharedMedia lookup helpers (the library is vendored and loaded by Core).
5. `lines.lua`: consistent label/value lines. `unittooltip.lua`: shared unit lookup and line helpers,
   including secret-value checks and this client's surname-aware `DisplayName`.
6. `border.lua`: shared content-driven border painting and restoration.
7. `options.lua`: the Tooltip panel: a tab per feature category (`all` is General, then Units,
   Items, Spells with the game aura CVars), then Profiles. CVAR_UPDATE refreshes external game-setting changes.
8. `src/features/*.lua`: the features below, in category order.
9. `SeamlessTooltip.lua`: load diagnostic.

### `src/features/`

#### All tooltips (`all`)

- `cursoranchor.lua` — `CursorAnchor` (off by default): post-hooks the global `GameTooltip_SetDefaultAnchor` and
  re-owns the tooltip with a cursor anchor (`position`: `ANCHOR_CURSOR_RIGHT` by default,
  `offsetX` = 16, `offsetY` = 0). Action buttons call the default anchor before `SetAction`, so
  `ActionButtonAnchor` wins for them while both are on. Unit frames (a parent with `.unit` or a
  "unit" attribute) and forbidden parents are left alone.
- `actionbuttonanchor.lua` — `ActionButtonAnchor`: a tooltip filled by `GameTooltip:SetAction`,
  `SetPetAction` or `SetShapeshift` is re-anchored to its owner, the button, with
  `SetAnchorType` (`position`: an `ANCHOR_*` type, default `ANCHOR_RIGHT` = above, to the right;
  or `AUTO` = above or below toward the screen center).
- `backdrop.lua` — `Backdrop`: the border and background of the top-level tooltips (`GameTooltip`,
  `ItemRefTooltip`, the shopping tooltips) from LibSharedMedia (`background`, `border` by name,
  their colors, `edgeSize`, `inset`). Each tooltip gets a `BackdropTemplate` child at its own
  level; its `NineSlice` is faded to alpha 0, which the game never resets (it restyles the
  NineSlice on every show). `ApplySettings` redraws them; a late `LibSharedMedia_Registered` of
  the chosen texture re-applies. The target/focus frames' aura tooltip (`AuraButtonTooltip`) is
  forbidden, but Blizzard's `AuraContainerInbound` (secure delegates, global) styles it:
  `SetTooltipBackdrop` with the same backdrop (needs a background or border, else
  `ResetTooltipStyle`), `ResetTooltipStyle` on disable. Its content can't be changed.
  Each backdrop frame is registered with `app.border.SetFrame`, so border colors by content paint it.
- `scale.lua` — `Scale` (off by default): `scale` (0.5–2) times each tooltip's own scale on the
  top-level and comparison tooltips (the comparison tooltips are UIParent's children, not the
  tooltip's); the original scales come back on disable.

#### Units (`units`)

- `playertext.lua` — `PlayerText`: the text of player tooltips (`classColorName`,
  `classColorClass`, `raceReactionColor`, `shortLevel`, `hideClass`, `guildLine`, `guildRank`,
  `guildRankIndex`, `faction`: `SHOW`, `OWN` =
  hide your own faction, `HIDE`). The line pre-call drops the faction line and, with `shortLevel`
  or `hideClass`, the class line (text = `UnitClass`). The post-call changes font strings: the
  name and a kept class line in class color; the level line (the first after the name with a
  level) becomes "3 Dwarf Priest" with `shortLevel`, else keeps the game's form with colored
  race/class words. The race is colored by `unitTooltip.UnitColor` (the name's PvP-aware
  reaction color). The guild line (text = `GetGuildInfo`'s name, maybe with a realm or brackets;
  checked before the level line) becomes "<Guild>" in that reaction color, or `OWN_GUILD_COLOR`
  when `UnitIsInMyGuild`, plus the rank name and index (`guildRank`, `guildRankIndex`, 0 = guild
  master) in grey (`guildLine`). Secret unit data is left alone.
- `npctext.lua` — `NpcText`: the text of NPC tooltips (`shortLevel`, `faction`). With
  `shortLevel`, "Level 10 (Elite)" and the creature type line of enemies (text =
  `UnitCreatureType`, dropped in the pre-call) become "10 Beast (Elite)". The type line may come
  before or after the level line, so the level line's pieces and the type are kept per tooltip
  and whichever comes last composes the line.
- `hidetitle.lua` — `HideTitle` (off by default): a name line post-call takes the player's title out
  of the name line: the text around `UnitName` in `UnitPVPName`, a surname after the name kept.
  Only the title's text is replaced, so it works with what other features add to that line.
- `statustags.lua` — `StatusTags`: tags behind a player's name (`afk`: `<AFK>`/`<DND>`,
  `offline`, `dead`: `<Dead>`/`<Ghost>` in red, `pvp`: `<PvP>` for `UnitIsPVP`/FFA), not doubled
  where the name line has them already; `hidePvpLine` drops the game's "PvP" line (text = `PVP`).
- `raidicon.lua` — `RaidIcon`: the raid marker in front of the name. `GetRaidTargetIndex` returns a
  secret to addon code, so (like Blizzard's target frame) a texture per tooltip on the
  `UI-RaidTargetingIcons` sheet gets it through `SetSpriteSheetCell`, over a transparent
  `Interface\Common\spacer` inline texture put in front of the name; a secret return counts as
  "has a marker" (nil is never secret). The texture hides on `OnTooltipCleared`/`OnHide`;
  `RAID_TARGET_UPDATE` updates it (and the spacer) while `GameTooltip` shows the unit.
- `tappedname.lua` — `TappedName`: the name of an NPC with `UnitIsTapDenied` in grey.
- `targetline.lua` — `TargetLine`: a Unit post-call adds "T: Name" for `<unit>target` (class
  color for players, `unitTooltip.UnitColor` otherwise; ">>YOU<<" in red when it targets you and
  `you` is set). World units keep their tooltip while hovered, so a `GameTooltip` `OnUpdate` hook
  re-checks the target every 0.05 s and rewrites the line (or adds it; "T: -" once the target is
  gone). No line while `UnitExists`/`UnitIsUnit`/`UnitName` are secret.
- `targetedby.lua` — `TargetedBy`: in a group, the members whose target is the unit (`raid<n>`,
  else `player` + `party<n>`, `UnitIsUnit`): "Targeted by (2): Name, Name" in class colors, at most
  6 names (`names`), or only the count; `you` counts yourself.
- `creaturefamily.lua` — `CreatureFamily` (off by default): "Family Wolf" for NPCs with a
  `UnitCreatureFamily`.
- `healthbar.lua` — `HealthBar`: restyles `GameTooltip.StatusBar` (Blizzard's unit/object health
  bar, secure mixin, fed possibly secret health): `texture`, `height`, `backgroundColor`, a status
  `text` (`NONE`, `PERCENT`, `VALUE`, `VALUE_MAX`, `VALUE_PERCENT`) and `inside` + `inset`. Inside,
  a Unit/Object post-call anchors the bar to the tooltip's bottom and sets a bottom padding (the
  tooltip clears padding on hide, so it is set per tooltip). Nothing is written to the bar's
  table; our texture/font string and its original look are locals. The text only passes health
  values to secret-accepting APIs (`AbbreviateNumbers`, `UnitHealthPercent` with
  `CurveConstants.ScaleTo100`, `SetFormattedText`) and refreshes on the bar's `OnValueChanged`.
- `unitborder.lua` — `UnitBorder`: `app.border.Paint` in a Unit post-call: players in class color
  (`players`), NPCs in `unitTooltip.UnitColor` (`npcs`), tapped NPCs in grey (`tapped`).
- `hideunits.lua` — `HideUnits` (off by default): a `GameTooltip` `OnShow` hook hides unit tooltips
  (`when`: `COMBAT` = `InCombatLockdown`, `ALWAYS`) unless `modifier` (`SHIFT`/`CTRL`/`ALT`,
  `NONE`) is held. World units only (owner `UIParent`/`WorldFrame`; the unit token can't tell, it
  is "target" for a hovered target) unless `unitFrames`. `MODIFIER_STATE_CHANGED` over the world
  with a `mouseover` unit shows it with the default anchor and `SetUnit("mouseover")`.

#### Items (`items`)

- `itemids.lua` — `ItemIDs`: the item ID (`item`, on) and its icon's file ID (`icon`, off,
  `C_Item.GetItemIconByID`).
- `itemlevel.lua` — `ItemLevel`: "Item Level 52" for weapons and armor
  (`C_Item.GetDetailedItemLevelInfo`), in the quality color (`qualityColor`); left out when the
  game's data has an `ItemLevel` line (seen in a line pre-call).
- `itemdetails.lua` — `ItemDetails`: further item information; so far `stackSize` (off,
  `C_Item.GetItemMaxStackSizeByID`, only above 1).
- `vendorprice.lua` — `VendorPrice`: "Sell Price <money>" (`MoneyFormatterUtil.FormatMoney` with
  `GameTooltipMoneyFormat`) for the stack, plus "(<money> each)" (`perItem`). The game's
  `SellPrice` line is dropped in its pre-call where one item's price (`C_Item.GetItemInfo`) is
  known and the line has no min/max; its price over that gives the count. Without a game line the
  count comes from a bag slot owner (`GetBagID`, `count`). Not on comparison tooltips
  (`isShopping`).
- `qualityborder.lua` — `QualityBorder`: `app.border.Paint` in an Item post-call with
  `C_Item.GetItemQualityColor`, from `minQuality` (a select of the quality names in their colors;
  default Uncommon).

#### Spells (`spells`)

- `spellids.lua` — `SpellIDs`: the spell ID (`spell`, on) and its icon's file ID (`icon`, off,
  `C_Spell.GetSpellTexture`) on `Spell` and `UnitAura` tooltips (buffs/debuffs are a type of
  their own; `tooltipData.id` is the aura's spell ID, secret while auras are restricted).
  With the game's CVar `tooltipShowAuraSpellIDs` on (Spells section, "Game settings"), the client
  adds its own "Spell ID: 687" line, which also reaches the forbidden target/focus aura tooltip.
  Where we can, a line pre-call drops it for ours: an aura tooltip's second line
  (`NumLines() == 1`) whose only number is the spell ID, so any language.
- `aurasource.lua` — `AuraSource`: `Source: <name>` on buff/debuff tooltips, players in class
  color. A `UnitAura` post-call reads how the tooltip was filled from its processing info
  (`getterName` "GetUnitAura"/"GetUnitBuffByAuraInstanceID"/..., `getterArgs` = unit, index or
  instance ID, filter) and looks the aura up with the matching `C_UnitAuras` getter for
  `sourceUnit`. With the game's CVar `tooltipShowAuraCasterNames` on (Spells section, "Game
  settings"), the client adds its own "Cast by Name" line (line type `AuraCaster`), which also
  reaches the target/focus auras; a pre-call drops it wherever our line can be built, so in combat
  (secret data) it stays. Aura data is secret
  while auras are restricted, so any secret argument or value leaves the line out. The target and
  focus frames' auras use a forbidden tooltip (`AuraButtonTooltip`) that addons can't reach.

### Annotations (not in the TOC)

- `src/types.lua` — the private-table class `SeamlessTooltip` (`app.*` fields) and
  `SeamlessTooltip.DB`. When a file adds a member to `app`, add a matching `---@field` here.

## Features and conventions

A feature is one file in `src/features/` plus its TOC entry. It declares itself through
`app.features:NewFeature(key, info)`, where `key` is the persistent key in `profile.features`.
Never rename an existing key without migration. `info` declares category (`all`, `units`, `items`,
`spells`), name, description (`desc`), order, options; define enabled and setting defaults in `src/core/db.lua`.

Options are AceConfig args; each key maps to the same key in the feature's settings, read and
written by `core.FeatureGroup` (colors as `{ r, g, b, a }` tables) unless the option has its own
get/set. Each feature is an inline section on its category's tab: an Enable toggle with `desc`
under it, then its options, disabled while the feature is off.

Features are sorted by `order` within their tab. An option's own `disabled` replaces the
feature-off check, so include `not settings.enabled` in it.
Feature options need no manual edits in `options.lua`; define defaults in `src/core/db.lua`.

Features are nested Ace modules with AceEvent/AceHook. Register hooks/events in `OnEnable` and
undo frame changes in `OnDisable`. TooltipDataProcessor wrappers register once from `OnInitialize`
and skip callbacks when disabled or the tooltip is forbidden. Keep existing secret-value checks;
never write to the game's tooltip data tables or call Show from post-calls.

Read settings through `self:Settings()` at use time. `ApplySettings()` reapplies frame changes
when enabled settings or profiles change; `OnEnable` applies settings on activation.
New private-table members belong in `src/types.lua`. Update this map and the suite README when
adding features.

## Shared suite profiles

Settings now live in the `SeamlessTooltip` namespace of Core's `SeamlessDB`.
`src/core/db.lua` is the editable source of defaults (including feature defaults).
Core's `RegisterAddonDatabase` imports the legacy `SeamlessTooltipDB` once and
subscribes the addon to shared profile changes, copies and resets. Core's Profiles controls and
slash-command profile resets operate on the whole suite. Character/global data stay in the
namespace; the old standalone database is retained only for migration.
