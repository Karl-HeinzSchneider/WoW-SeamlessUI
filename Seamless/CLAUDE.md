# Seamless (core)

Required entry point of the suite; works with no feature addon enabled.

## Load order and ownership

- `embeds.xml`: every shared vendored library from `lib/` (Ace3, AceGUI, AceConfig, AceDBOptions,
  LibSharedMedia, LibDBIcon, LibEditModeOverride, LibEditMode). LibEditMode loads `namespaced.lua`
  before `embed.xml` into Core's private table and is never registered with LibStub; feature
  addons get it through `core:GetEditModeLibrary()`. Never patch vendored code.
- `locales/enUS.lua`, then only the client's `locales/[TextLocale]/strings.lua`: the shared
  `Seamless` AceLocale catalogue every addon uses (see the root `CLAUDE.md`).
- `src/core/logger.lua`: the shared logger, `core.logger`.
- `db.lua`: `SeamlessDB` defaults (logging, minimap, tweaks).
- `ace.lua`: AceAddon lifecycle, core profiles, `/seamless`, the public API below.
- `editmodelib.lua`: suite additions to the namespaced LibEditMode (see below). The only file
  allowed to use `lib.internal`.
- `anchorpicker.lua`: the quick anchor picker (see below).
- `editmode.lua`: the shared Edit Mode panel below the main Edit Mode window (see below).
- `systemoptions.lua`: registry of settings sections feature addons add to a Blizzard Edit Mode
  system (see below).
- `quests.lua`: `core:GetQuestLogSummary()`. `questlog.lua`: completed quest count and XP in the
  quest log header.
- `xptooltip.lua`: `tweaks.enhancedXPTooltip` (on by default) adds XP left and rested XP to the
  player XP bar tooltip. SeamlessUI's XP bar tooltip replaces it while enabled. Time to max rested
  uses `restedXPCap` (150%) and `restedXPRate` (5% per eight hours), because the client exposes
  neither.
- `tweaks.lua`: `/rl` (on by default) and showing the framerate once on startup (off; its toggle is
  in the FPS display's Edit Mode settings, owned by SeamlessUI).
- `options.lua`: the shared options layout (`Register`, `FeatureGroup`) and Core's panels:
  "Seamless" (General: minimap button, log level, a button per enabled feature addon; Profiles)
  and its "Tweaks" child.
- `minimapbutton.lua`: the suite's launcher, as a minimap button and an optional addon
  compartment entry (off by default, disabled where the client lacks it).
- `src/config/`: the standalone draggable configuration shell and public category/page API.
  See `src/config/CLAUDE.md`. `/seamless` and minimap right-click open it; existing options
  remain available through minimap left-click pending migration.
- `src/types.lua`: annotations only, not in the TOC. Annotate new public API here.

## Public API

At file load a feature gets Core with `LibStub("AceAddon-3.0"):GetAddon("Seamless")`.

- `core.logger`: shared logger; its level follows the core profile.
- `core:GetEditModeLibrary()`: the suite's namespaced LibEditMode.
- `core:GetQuestLogSummary()`: a fresh `{ totalQuests, completedQuests, completedQuestXP }`,
  counting quests under collapsed headers without changing the selection. Call again on
  `QUEST_LOG_UPDATE`.
- `core:RegisterOptions`, `OpenOptions`, `RefreshOptions`, `core.FeatureGroup`: see Options.
- Edit Mode: `RegisterEditModeOptions`, `RefreshEditModeOptions`, `RegisterEditModeSystemOptions`
  and the `editmodelib.lua` helpers, below.

Core never references a feature by name or loads disabled features; core profiles include all feature namespaces. `/seamless [options]`, `/seamless loglevel <level>` and `/seamless reset` act on
the suite profile.

## Options: one panel per addon, tabs inside

Every addon has one AceConfig panel in Settings > AddOns; Core's "Seamless" panel is the parent.
Tabs are always **General**, then the addon's own tabs (`order` 1–999; few and broad, related
controls in inline groups), then **Profiles** (added by Core).

- `core:RegisterOptions(addonName, spec)`, from `OnInitialize` after the database exists: `title`,
  `general` (args of the General tab), optional `tabs` (groups by key with `order` and `name`;
  `type = "group"` is filled in) and `db` (adds the shared suite Profiles tab).
- `core:OpenOptions(addonName, tab)`: opens the panel, optionally on a tab; no name opens Seamless.
- `core:RefreshOptions(addonName)`: redraws after an outside change (CVar, slash command). Profile
  changes redraw on their own.
- `core.FeatureGroup(spec)`: an inline group for one switchable feature: Enable toggle with its
  description, then the options. Options without their own `get`/`set` use
  `spec.settings()[key]` (colors as `{ r, g, b, a }`) and are disabled while the feature is off
  unless they define `disabled`. `spec.toggled` runs after the switch, `spec.changed` after any
  other setting.

Always read `app.db.profile` inside accessors (a cached table breaks profile switching). Put shared
`get`/`set` on the group (`info[#info]` is the key). AceConfigRegistry rejects unknown keys. Use
`width = "full"` and `descStyle = "inline"` for toggles whose description should show.

## Shared Edit Mode panel (`editmode.lua`)

The panel below the main Edit Mode window, with the native translucent border and the window's
width. Feature addons register once and call `core:RefreshEditModeOptions()` when their profile,
enabled state or other outside values change; Core refreshes on Edit Mode enter/exit, layout
changes and combat.

```lua
core:RegisterEditModeOptions("MyAddon", {
    section = "frames", -- or "options" (the default): GLOBAL options, only when asked for
    order = 100,
    name = L["My frames"], -- optional group heading
    enabled = function() return addon:IsEnabled() end,
    options = {
        { key = "preview", type = "toggle", name = L["Show my frames"],
          get = function() return showFrames end, set = function(value) showFrames = value end },
        { key = "reset", type = "button", name = L["Reset my frames"], click = ResetMyFrames },
    },
})
```

- `section = "frames"` rows go under the shared **Frames** heading, two checkbox columns like the
  native window. Register the movable frame itself through `core:GetEditModeLibrary()`.
- Options always come before Frames. Groups sort by `order` (default 100), then ID; rows by
  `order`, then array position. IDs are unique; row keys are unique within a group.
- `hidden`/`disabled` take booleans or functions. Getters always read current state; Core stores
  nothing. Combat, hidden/disabled features and calls outside Edit Mode are guarded.
- `type = "header"` with a `name`: a collapsible section title (collapsed state saved like the
  settings window's headers).
- `type = "custom"`: `create(parent)` returns an addon-owned frame parented to `parent`, with a
  height; optional `layout(frame, width, disabled)` returns its measured height and must honor
  `disabled`. Never reposition, reparent or register the row with Blizzard layout containers.
- The panel scrolls when it would pass the screen bottom. It owns its UIParent frame; never touch
  native layout containers.

Run `lua src/tests/editmode-panel.lua`.

## Selected frame settings (`editmodelib.lua`)

- `lib.SettingType.Header` (via `core:CreateEditModeHeader`): a collapsible header styled like the
  reputation headers (`name`, optional `key`, `hidden`). It hides every row up to the next
  header; collapsed sections are saved in `SeamlessDB.global.editModeCollapsed`
  (`core:Is/SetEditModeSectionCollapsed`). Position sections start collapsed.
- `lib.SettingType.Button`: a button row whose `click(frame)` gets the selected frame.
- `core:GetEditModePositionSettings(spec)`: the Position header plus Anchor, AnchorParent,
  AnchorFrame, X, Y and "Quick anchor to frame" (targets `spec.anchorFrames`, resolved by optional
  `spec.anchorFrame(value)` or the global name; UIParent excluded). Collapse key
  `core:GetEditModePositionSectionKey()`, shared by every Position header.
- `core:SetEditModeFrameFixed(frame)`: keeps a frame selectable with its settings but removes
  dragging, arrow-key nudges and Reset Position (previews of frames the client places).
- The settings list scrolls past 400 pixels or 60% of the screen height. The dialog opens
  16 pixels beside its frame (the side with more room), grows downward only and never changes
  width.

It asserts on the library internals it relies on: rerun `lua src/tests/editmode-dialog.lua`
whenever LibEditMode is updated.

## Quick anchor picker (`anchorpicker.lua`)

`core:StartEditModeAnchorPicker(spec)` (also `Stop…`, `IsEditModeAnchorPickerActive`): nine
markers on the selected frame's anchor points, then on the smallest hovered frame from
`spec.targets()` (`{ frame, value }`). The second click calls
`spec.apply(point, value, relativePoint, x, y)`, with a 5-pixel gap where the two points face each
other. Right-click, Escape, combat, leaving Edit Mode or hiding the frame cancel. Run
`lua src/tests/anchor-picker.lua`.

## Settings for Blizzard systems (`systemoptions.lua`)

`core:RegisterEditModeSystemOptions(id, spec)` adds a section to a Blizzard Edit Mode system's
settings: `system` (`Enum.EditModeSystem`), optional `systemIndex`, `name` (collapsible header),
optional `key` (collapse key `"settings:" .. (key or name)`), `order`, `enabled` and `options`
(rows with `key`, `type` = `toggle`, `select` with `values = { { text, value } }` or `range` with
`min`, `max`, `step`, optional `format`; `name`, optional `desc`, `get()`, `set(value)`, `hidden`,
`disabled`). Core only keeps the registry; SeamlessUI draws the sections, so no feature depends
on SeamlessUI. `core:RefreshEditModeSystemOptions()` sends
`core:GetEditModeSystemOptionsMessage()`; `core:GetEditModeSystemOptions(system)` returns the
enabled sections in order.

## Shared feature databases

`core:RegisterAddonDatabase(name, defaults, owner, refreshMethod, legacySavedVariable)` runs
from each feature addon's `OnInitialize`. It returns an AceDB namespace under `SeamlessDB`
and registers the owner's refresh method on the parent profile changed/copied/reset events,
after every namespace has been updated. Read `app.db.profile` at use time. Namespaces do not
expose `GetCurrentProfile`/`SetProfile`; use `core.db` for profile management. Every Profiles tab
and every slash-command profile reset controls the whole suite.

`src/core/profiles.lua` owns registration and one-time import. Legacy feature SavedVariables
remain declared as migration inputs and are preserved, but new settings only use namespaces.
Named legacy profiles and non-profile scopes are copied; the current character's previous
feature profile also seeds the active core profile. An existing namespace is never reimported.
Disabled addons import when first loaded. Chat's separate per-character log/history stores stay
separate. Run `lua src/tests/shared-profiles.lua`.
