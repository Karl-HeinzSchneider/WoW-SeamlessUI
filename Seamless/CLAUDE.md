# Seamless (core)

Required entry point of the suite; works with no feature addon enabled.

## Ownership

- `embeds.xml`: shared libraries. LibEditMode is namespaced into Core, not registered with
  LibStub; features use `core:GetEditModeLibrary()`.
- `src/core/`: lifecycle, defaults, profiles, logger, options, minimap launcher, quests and tweaks.
  `frameposition.lua` owns native position validation and persistence; `editmode.lua`,
  `editmodelib.lua`, `editmoderows.lua`, `editmodeposition.lua`, `systemoptions.lua` and
  `anchorpicker.lua` own shared Edit Mode services.
- `src/config/`: custom options renderer and reusable Position groups; read its `CLAUDE.md`.
- `locales/`: the suite's shared AceLocale catalogue.

Only `src/core/editmodelib.lua` may access LibEditMode's `lib.internal`.

## Public API

- `src/core/previewcharacters.lua`: `RegisterPreviewCharacter(id, record)` registers a flat,
  validated VIP record. `previewcharacters-data.lua` is the shipped, editable catalogue, loaded
  immediately after the service. `GetPreviewCharacter(consumerID)` returns a copy, or nil outside
  Edit Mode/in combat/with an empty catalogue. Assignments stay stable for the session, drawing
  from a shuffled bag without repeats until exhausted. Assignments survive Edit Mode enter/exit
  and reset only on logout or UI reload. Core owns
  only data and never modifies unit APIs, secure bindings or feature frames.
- Records allow missing names/classes. Missing names use the client's localized unknown label;
  missing classes retain the consumer's fallback portrait. Optional text resolves to empty strings.
  Keep missing fields commented out in the authored catalogue; never invent VIP metadata.
  Records use optional `name`/`surname`, uppercase `class`, numeric `health`/`healthMax` and
  `power`/`powerMax` (default 100), `powerType` and `reaction` (1–8). Optional `displayTexture` is
  a full path to an existing BLP/TGA. Without an asset, consumers may show a class icon. Metadata
  (`level`, titles, realm, guild/rank, zone, race/sex, faction, role, classification, `displayID`)
  is available for future consumers; registration does not automatically render it. Add scalar
  metadata as needed; nested tables are rejected. Character names and guilds are proper names,
  not localization keys. Do not draw new portraits without asking.
- Run `lua src/tests/preview-characters.lua` and `lua src/tests/preview-catalogue.lua`.
  The latter accepts an optional original VIP Lua path to audit every migrated field for exact
  preservation. `assets/VIP/` contains all 14 supplied, unmodified portrait BLPs; the catalogue
  contains 15 records, with shared portraits retained and missing portrait paths commented out.

At file load a feature gets Core with `LibStub("AceAddon-3.0"):GetAddon("Seamless")`.

- `core.logger`: shared logger; its level follows the core profile.
- `core:GetEditModeLibrary()`: the suite's namespaced LibEditMode.
- `core:GetQuestLogSummary()`: a fresh `{ totalQuests, completedQuests, completedQuestXP }`,
  counting quests under collapsed headers without changing the selection. Call again on
  `QUEST_LOG_UPDATE`.
- `core:RegisterAddonDatabase`: a feature's AceDB namespace, see Shared feature databases.
- `core:RegisterOptions`, `OpenOptions`, `RefreshOptions`, `core.FeatureGroup`,
  `GetOptionDefault`, `GetCVarOptionInfo`: see Options.
- Custom config window: `RegisterConfigCategory`, `OpenConfig`, `ToggleConfig`, `RefreshConfig`,
  and the Position groups `GetPositionOptions`, `GetNativePositionOptions`,
  `GetFramePositionService`: see `src/config/CLAUDE.md`.
- Edit Mode: `RegisterEditModeOptions`, `RefreshEditModeOptions`, `RegisterEditModeSystemOptions`
  and the `editmodelib.lua` helpers, below.

Core never references a feature by name or loads disabled features; core profiles include all
feature namespaces. `/seamless [options]`, `/seamless loglevel <level>` and `/seamless reset` act
on the suite profile.

## Options: two panels in parallel, one panel per addon, tabs inside

Each `RegisterOptions` call feeds two panels from the same AceConfig table:

- our **custom config window**: a category header per addon with one child page per tab, drawn
  with our Settings-style controls (`src/config/`). It is what `/seamless`, the minimap button
  and `OpenOptions` show;
- the **Blizzard AddOns options**: one AceConfig panel per addon in Settings > AddOns, Core's
  "Seamless" panel as the parent, kept alongside the custom window.

Add every option through this declaration so it shows in both; never build it for one panel only.
Only keys both renderers understand belong in it (the custom-only `new`/`blizzard` tags and the
`tooltip` resolver are kept outside AceConfig). Check a new option in both panels.
Tabs are always **General**, then the addon's own tabs (`order` 1–999; few and broad, related
controls in inline groups). Only the core Seamless panel has a **Profiles** tab.

- `core:RegisterOptions(addonName, spec)`, from `OnInitialize` after the database exists: `title`,
  `general` (args of the General tab), optional `tabs` (groups by key with `order` and `name`;
  `type = "group"` is filled in).
  `tooltip(path)` optionally returns the declared default and a per-character boolean for
  the custom window's info tooltip. Use `core:GetOptionDefault(schema, path, first)` for
  schema lookup or `core:GetCVarOptionInfo(name)` for CVar defaults and scope.
  Add `new = true` or `blizzard = true` to a tab or individual option to show a native
  glowing label in the custom config view; the flags are removed before AceConfig validation.
  The same flags work on `FeatureGroup` specs and `RegisterConfigCategory` specs.
- `core:OpenOptions(addonName, tab)`: opens the addon's page in the custom config window,
  optionally on a tab; no name opens Seamless General.
- `core:RefreshOptions(addonName)`: redraws after an outside change (CVar, slash command). Profile
  changes redraw on their own.
- `core.FeatureGroup(spec)`: an inline group for one switchable feature: Enable toggle with its
  description, then the options. Features without subordinate options instead return a standalone
  toggle named after the feature, in both the custom and native options windows. Features with
  subordinate controls retain their section and Enable toggle. Options without their own `get`/`set` use
  `spec.settings()[key]` (colors as `{ r, g, b, a }`) and are disabled while the feature is off
  unless they define `disabled`. `spec.toggled` runs after the switch, `spec.changed` after any
  other setting.

Always read `app.db.profile` inside accessors (a cached table breaks profile switching). Put shared
`get`/`set` on the group (`info[#info]` is the key). AceConfigRegistry rejects unknown keys. Use
`width = "full"` and `descStyle = "inline"` for toggles whose description should show.

## Shared Edit Mode panel (`editmode.lua`)

The panel below the main Edit Mode window, with the native translucent border and the window's
width. It is the public frame `SeamlessEditModeWindow` (created once it first has rows to show). Feature addons register once and call `core:RefreshEditModeOptions()` when their profile,
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

- `section = "frames"` rows go under the shared **Frames** header, two checkbox columns like the
  native window. The header is collapsible like the Position headers (key `"panel:frames"`) and
  starts collapsed. Register the movable frame itself through `core:GetEditModeLibrary()`.
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

The settings window of a selected Seamless frame is Core's own frame
`SeamlessEditModeSettingsDialog`. The namespaced library keeps selection, dragging and the
OnHide reset; Core only replaces `internal:CreateDialog` (before the library creates its dialog)
so it returns this window. The vendored file stays untouched.

- The window is drawn by the shared renderer (`core:LayoutEditModeSections`): it splits the
  frame's settings into sections at each Header, appends Reset To Default, and lists the frame's
  buttons plus Reset Position below, under a divider, outside the scrolling list. Fixed width (370), the list scrolls past 400 pixels or 60%
  of the screen height, grows downward only and keeps its scroll offset across refreshes.
- Supported kinds: Checkbox, Dropdown (`values`, `height` scrolls the menu), Slider (`minValue`,
  `maxValue`, `valueStep`, `formatter`), `lib.SettingType.Header` and `lib.SettingType.Button`.
  Any other kind raises an error: add it to `ConvertSetting` and the renderer first.
- `lib.SettingType.Header` (via `core:CreateEditModeHeader`): a collapsible header styled like the
  reputation headers (`name`, optional `key`, `hidden`). Collapsed sections are saved in
  `SeamlessDB.global.editModeCollapsed` (`core:Is/SetEditModeSectionCollapsed`). Position
  sections start collapsed.
- `lib.SettingType.Button`: a button row whose `click(frame)` gets the selected frame.
- `core:GetEditModePositionSetting(spec, options)`: one `lib.SettingType.Position` frame setting
  that the window draws as the shared Position section (`editmodeposition.lua`), the same one
  Blizzard frames get: Scale (from `spec.scale`, the settings panel's binding; greyed out without
  one), Anchor, AnchorParent, AnchorFrame, X, Y, "Quick anchor to frame" (targets
  `spec.anchorFrames`, resolved by optional `spec.anchorFrame(value)` or the global name;
  UIParent excluded) and Revert (back to the position at selection). Only changed fields reach
  `spec.set`. `options` are LibEditMode settings shown at the top of the section (Reset To Default
  resets them, never the position); settings after it go below without a header. Collapse key
  `core:GetEditModePositionSectionKey()`, shared by every Position header.
- `core:SetEditModeFrameFixed(frame)`: keeps a frame selectable with its settings but removes
  dragging, arrow-key nudges and Reset Position (previews of frames the client places).
- The window opens 16 pixels beside its frame (the side with more room).
  `core:SetEditModeDialogsBesideManager(enabled)` (off by default, SeamlessUI sets it) opens it
  4 pixels right of Blizzard's Edit Mode window instead; `core:PlaceBesideEditModeManager(dialog)`
  does that placement for any dialog. Both only re-anchor, in absolute coordinates.
- Rows are converted once per setting and reused, so refreshes while a slider is held never end
  the drag.
- `core:AttachEditModeSettingsWindow(spec)` shows the same window below another dialog
  (`spec.anchor`, SeamlessUI passes Blizzard's `EditModeSystemSettingsDialog`) with `spec.title`
  and the renderer sections `spec.sections()`, built again on every layout; `spec.key` names what
  is shown (the list scrolls to the top when it changes) and `spec.changed` runs after a row
  changes a value. Attached, it takes the anchor's width, sits above it, has no close button,
  frame buttons or dragging, and polls `RefreshEditModeSections` every 0.15 s. Call it again to
  refresh. `core:DetachEditModeSettingsWindow()` hides it, but only while attached. Selecting a
  suite frame, or the library's Reset on a native selection, ends the attached placement.

It asserts on the library internals it relies on: rerun `lua src/tests/editmode-dialog.lua`
whenever LibEditMode is updated.

## Quick anchor picker (`anchorpicker.lua`)

`core:StartEditModeAnchorPicker(spec)` (also `Stop…`, `IsEditModeAnchorPickerActive`): nine
markers on the selected frame's anchor points, then on the smallest hovered frame from
`spec.targets()` (`{ frame, value }`). The second click calls
`spec.apply(point, value, relativePoint, x, y)`, with a 5-pixel gap where the two points face each
other. Right-click, Escape, combat, leaving Edit Mode or hiding the frame cancel. Run
`lua src/tests/anchor-picker.lua`.

## Seamless Edit Mode layout (`defaultlayout.lua`)

`defaultlayout-data.lua` holds the in-game export string of the suite's Edit Mode layout; replace
the whole string to update it (players keep the copy they already have). Each session, once Edit
Mode has loaded and outside combat and Edit Mode, the account layout named "SeamlessUI (Preset)" is
added if missing, without switching to it: Blizzard reloads its layout list only on an active
layout change, so `Create` activates the new layout and then selects the previous one again. The
General tab's "Use Seamless layout" button adds it if needed and switches to it. It is not a real
preset: never add entries to `EditModePresetLayoutManager` or write `EditModeManagerFrame`'s tables
(index shift and taint). Save through `C_EditMode` like the native import. Run
`lua src/tests/default-layout.lua`.

## Shared row renderer (`editmoderows.lua`)

`core:LayoutEditModeSections(parent, sections, y, spaced, changed)` draws sections (`id`, `name`,
collapse `key`, `options`) into an addon-owned frame from `y` down and returns the bottom. Each
section gets the shared collapsible header. Rows (`key`, `type`, `name`, optional `desc` tooltip,
`hidden`, `disabled`):

- `toggle`, `select` and `range`: the row schema of `RegisterEditModeSystemOptions`, on
  LibEditMode's templates. `select` also takes `values` as a function, entries with `disabled`,
  `scroll` (menu height) and `text(value)` for the shown text. `range` also takes `min`/`max`/`step`
  as functions and `editable = true` for a click-to-type value (Enter passes the typed text to
  `set`, Escape discards).
- `button`: `click()`, half the row's width on the native dialog button template.
- `text`: a wrapped message from `get()`, as tall as its text.

Headers and rows are created once per parent and reused by section `id` and row `key`; only what a
pass leaves out is hidden, so a click or drag in progress survives a redraw. `changed` runs after
every click; redraw there. `core:RefreshEditModeSections(parent)` refreshes the last pass's rows in
place for polling and returns true when the layout itself must run again. Add new row types here,
never a second renderer.

## Position section (`editmodeposition.lua`)

`core:CreateEditModePositionSection(id, binding)` returns a section for the renderer: Scale,
Anchor, AnchorParent, AnchorFrame, X, Y (editable, screen-sized ranges that grow with the value),
"Quick anchor to frame", Revert and the last refusal message. The binding
(`SeamlessCore.EditModePositionBinding`) reads, validates and applies; the section only builds rows
and drops changes once `isCurrent()` is false. Build one per selected frame. SeamlessUI uses it for
Blizzard frames; Seamless frames get it through `GetEditModePositionSetting`.

## Settings for Blizzard systems (`systemoptions.lua`)

`core:RegisterEditModeSystemOptions(id, spec)` adds a section to a Blizzard Edit Mode system's
settings: `system` (`Enum.EditModeSystem`), optional `systemIndex`, `name` (collapsible header),
optional `key` (collapse key `"settings:" .. (key or name)`), `order`, `enabled` and `options`
(rows with `key`, `type` = `toggle`, `select` with `values = { { text, value } }` or `range` with
`min`, `max`, `step`, optional `format`; `name`, optional `desc`, `get()`, `set(value)`, `hidden`,
`disabled`). Core keeps the registry and the row renderer; SeamlessUI places the sections in its
window, so no feature depends on SeamlessUI. `core:RefreshEditModeSystemOptions()` sends
`core:GetEditModeSystemOptionsMessage()`; `core:GetEditModeSystemOptions(system)` returns the
enabled sections in order.

`core:RegisterEditModeSystemScale(id, spec)` gives a system without a native size setting (the
action bar endcaps) a Scale: `system`, optional `systemIndex`, `enabled` and `scale` (a
`PositionScale` binding with `get`/`set`, optional `min`/`max`/`step`/`disabled`). The feature
stores and applies it; `core:GetEditModeSystemScale(system)` returns the enabled binding, which
SeamlessUI's Position section uses for its Scale row.

## Shared feature databases

`core:RegisterAddonDatabase(name, defaults, owner, refreshMethod, legacySavedVariable)` runs
from each feature addon's `OnInitialize`. It returns an AceDB namespace under `SeamlessDB`
and registers the owner's refresh method on the parent profile changed/copied/reset events,
after every namespace has been updated. Read `app.db.profile` at use time. Namespaces do not
expose `GetCurrentProfile`/`SetProfile`; use `core.db` for profile management. Core's Profiles tab
and every slash-command profile reset controls the whole suite.

`src/core/profiles.lua` owns registration and one-time import. Legacy feature SavedVariables
remain declared as migration inputs and are preserved, but new settings only use namespaces.
Named legacy profiles and non-profile scopes are copied; the current character's previous
feature profile also seeds the active core profile. An existing namespace is never reimported.
Disabled addons import when first loaded. Chat's separate per-character log/history stores stay
separate. Run `lua src/tests/shared-profiles.lua`.
