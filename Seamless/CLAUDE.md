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
- `core:RegisterOptions`, `OpenOptions`, `RefreshOptions`, `GetSettingsOption`,
  `GetOptionDefault`, `GetCVarOptionInfo`: see Options.
- Custom config window: `RegisterConfigCategory`, `OpenConfig`, `ToggleConfig`, `RefreshConfig`,
  and the Position groups `GetPositionOptions`, `GetNativePositionOptions`,
  `GetFramePositionService`: see `src/config/CLAUDE.md`.
- Edit Mode: `RegisterEditModeOptions`, `RefreshEditModeOptions`, `RegisterEditModeSystemOptions`
  and the `editmodelib.lua` helpers, below.

Core never references a feature by name or loads disabled features; core profiles include all
feature namespaces. `/seamless [options]`, `/seamless loglevel <level>` and `/seamless reset` act
on the suite profile.

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

## Shared Edit Mode panel (`editmode.lua`)

`core:EditModeVisibility(accountSettingID, value)` is the shared native visibility binding.
With no value it reads the pending choice, or LibEditModeOverride's saved account value.
With a boolean it stores the latest choice in `db.global.editModeVisibilityPending`, surviving
reloads and profile changes. Inside Edit Mode it applies through the library; outside it waits.
The library's enter callback schedules a flush after the user's native entry stack. The service
never opens, closes or reopens Edit Mode, and never calls `ApplyChanges`, `LoadLayouts` or
`SaveOnly`. Each frame declares `config.editModeVisibility = core:GetEditModeVisibility(settingID,
update)` at file load. This registers its in-place `update(boolean)` callback and returns the
header's read/write function. The callback runs only while Edit Mode is active and out of
combat, after `SetGlobalSetting`; clear the pending choice only if the callback and library
readback succeed. Failed writes or refreshes stay queued. Combat defers writes. A recursion
guard covers the batch. Pet updates only its native checkbox and preview; it never calls
`OnAccountSettingChanged` or rebuilds the shared account-setting map. Future frame bindings
must likewise avoid changing native shared caches. Run `lua src/tests/editmode-visibility.lua`.

Custom frame pages use `core:GetCustomEditModeVisibility(id, get, set)` with a namespaced
string ID and the addon's existing preview visibility getter/setter. It uses the same queue,
combat guards, entry flush and error handling without native account-setting calls. Frame-list
controls and header controls must share their underlying getter/setter. All damage-meter window
pages use the single ID `SeamlessDamageMeter.windows`, matching the shared Frames checkbox.
Custom preview state remains session-only after application, like the existing Frames controls;
unapplied choices survive reloads. No visibility binding opens or closes Edit Mode.

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
- The minimize button in the panel's close-button corner hides it and shows a small restore button
  (also ours, on UIParent) under the main Edit Mode window; clicking that brings the panel back.
  The state is saved account-wide with the collapsed sections (key `"panel:minimized"`).
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
  explicit ButtonSection declarations below, under a divider, outside the scrolling list.
  No footer buttons are inferred from the frame registration or legacy library buttons. Fixed width (370), the list scrolls past 400 pixels or 60%
  of the screen height, grows downward only and keeps its scroll offset across refreshes.
- Supported kinds: Checkbox, Dropdown (`values`, `height` scrolls the menu), Slider (`minValue`,
  `maxValue`, `valueStep`, `formatter`), `lib.SettingType.Header`, `lib.SettingType.Button`,
  `lib.SettingType.Position` and `lib.SettingType.ButtonSection`.
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
  UIParent excluded). Revert is declared in the footer, below. Only changed fields reach
  `spec.set`. `options` are LibEditMode settings shown at the top of the section (Reset To Default
  resets them, never the position); settings after it go below without a header. Collapse key
  `core:GetEditModePositionSectionKey()`, shared by every Position header.
- Every frame's `src/options/<frame>.lua` explicitly sets
  `config.buttonSection = core:GetEditModeButtonSection({ ... })`, an ordered array of arbitrary
  button declarations (`name`, `click(frame)`, optional `desc`, `hidden`, `disabled`). Standard
  actions are individual optional entries from `GetEditModePositionButton("revert")` and
  `GetEditModePositionButton("resetPosition")`; custom button tables use the same list.
  Frame registration passes that config field to `AddFrameSettings`; it must never manufacture
  a footer or substitute default actions when the field is absent. Native frame pages also
  declare `config.editModeFrame`; Core looks up their explicit section with
  `GetEditModeFrameButtonSection(frame)`. The attached window receives `buttonSection` and a
  `buttonBinding` (canEdit, hasChanges, revert, isDefault, reset), so both native and suite frames
  draw their declared footer outside the scroll. The helper returns a `lib.SettingType.ButtonSection`
  with the declared Button settings in order; it never chooses or appends actions. Revert
  restores the frame's custom setting values (including scale) and its position snapshot at first
  selection in the Edit Mode session. Baselines survive selection changes and clear on a new
  session, layout or profile. Dirty state compares current values, including external changes;
  returning to the baseline disables Revert. Native bindings also compare and restore the whole
  saved Blizzard system, independently of native dirty flags. Reset Position uses its registered
  default and movement callback. Native bindings restore the saved layout baseline or preset
  anchor through the native position service. Omit actions or the whole section to omit buttons.
  Empty sections draw nothing. The Position section never inserts Revert into its controls.
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
  automatic frame buttons or dragging, and polls `RefreshEditModeSections` every 0.15 s.
  It draws a footer only when `spec.buttonSection` is explicitly supplied. Call it again to
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
`default`, `hidden`, `disabled`):

- `toggle`, `select` and `range`: the row schema of `RegisterEditModeSystemOptions`, on
  LibEditMode's templates. `select` also takes `values` as a function, entries with `disabled`,
  `scroll` (menu height) and `text(value)` for the shown text. `range` also takes `min`/`max`/`step`
  as functions. Every `range` has a click-to-type value (Enter commits, Escape discards): a typed
  number is clamped to the range and snapped to the step, or with `editable = true` the typed text
  goes to `set` unchanged for the option to validate.
- `button`: `click()`, half the row's width on the native dialog button template.
- `text`: a wrapped message from `get()`, as tall as its text.

Tooltips match the config window's: name, `desc`, then for `toggle`, `select` and `range` the
localized `\n(Default: |cff8080ff%s|r)` line from `default` (a value or a function; booleans as
Enabled/Disabled, choices by label, numbers through `format`, nil as Not applicable). Buttons
show one only with a `desc`. The tooltip never follows the cursor: like the config window's, its
bottom-left corner sits on the top-right of the row's name (a button row's button), padded 12
pixels right and 8 up. Setting rows light up as a whole, like the config rows, while the cursor
is over the row or any of its controls (also disabled ones). LibEditMode settings pass their `default`;
Position rows take theirs from the binding's optional `default(key)` (Reset Position's target for
suite frames, the preset layout for Blizzard frames).

Headers and rows are created once per parent and reused by section `id` and row `key`; only what a
pass leaves out is hidden, so a click or drag in progress survives a redraw. `changed` runs after
every click; redraw there. `core:RefreshEditModeSections(parent)` refreshes the last pass's rows in
place for polling and returns true when the layout itself must run again. Add new row types here,
never a second renderer.

## Position section (`editmodeposition.lua`)

`core:CreateEditModePositionSection(id, binding)` returns a section for the renderer: Scale,
Anchor, AnchorParent, AnchorFrame, X, Y (editable, screen-sized ranges that grow with the value),
"Quick anchor to frame" and the last refusal message. Revert is an available action on the
section (`revertButton`), drawn only by an explicit button section. The binding
(`SeamlessCore.EditModePositionBinding`) reads, validates and applies; the section only builds rows
and drops changes once `isCurrent()` is false. Build one per selected frame. SeamlessUI uses it for
Blizzard frames; Seamless frames get it through `GetEditModePositionSetting`.

## Settings for Blizzard systems (`systemoptions.lua`)

`core:RegisterEditModeSystemOptions(id, spec)` adds a section to a Blizzard Edit Mode system's
settings: `system` (`Enum.EditModeSystem`), optional `systemIndex`, `name` (collapsible header),
optional `key` (collapse key `"settings:" .. (key or name)`), `order`, `enabled` and `options`
(rows with `key`, `type` = `toggle`, `select` with `values = { { text, value } }` or `range` with
`min`, `max`, `step`, optional `format`; select `values` may also be a function returning the
entries for the current state. Rows use `name`, optional `desc`, `get()`, `set(value)`, `hidden`,
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

`GetEditModeHistorySources()` returns frame/key/name/get/set/disabled descriptors for the
optional UI history consumer. The bridge in `editmodelib.lua` owns access to library settings
and position callbacks; native extensions come from the public system-options/scale registries.
Bindings resolve the current profile/layout when called. History itself belongs to SeamlessUI.
