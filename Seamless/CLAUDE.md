# Seamless (core)

Required entry point for the Seamless suite. It works with no feature addons enabled.

## Ownership and load order

- `locales/enUS.lua` loads after shared libraries and before runtime code. It owns the suite's
  shared `Seamless` AceLocale catalogue. The TOC then loads only `locales/[TextLocale]/strings.lua`.
  Every feature addon obtains this same object with `LibStub("AceLocale-3.0"):GetLocale("Seamless")`.
  Run `npm run locales:sync` to keep guarded translation files aligned with English.

- `embeds.xml` loads all shared vendored libraries from `lib/`, including AceGUI, AceConfig,
  AceDBOptions, LibSharedMedia, LibEditModeOverride and LibEditMode. LibEditMode loads
  `namespaced.lua` before `embed.xml` into Core's private table; never register it with LibStub.
  Feature addons obtain that instance through `core:GetEditModeLibrary()`. Never patch vendored code.
- `src/core/logger.lua`: shared suite logger.
- `db.lua`: defaults for `SeamlessDB` (logging, minimap settings and tweaks).
- `ace.lua`: AceAddon lifecycle, core profiles, `/seamless` command, public integration API.
- `editmodelib.lua`: suite-only additions to the namespaced LibEditMode, loaded before any
  Edit Mode user. Adds `lib.SettingType.Header`: a collapsible section header remade in our code to
  look like the character frame's reputation headers (`common-button-list-collapseExpand` bar,
  gold `GameFontNormalLeft` name, +/- state icon on the right; supports `name`, optional `key`
  and `hidden`), via `app.CreateEditModeHeader`. Clicking it
  hides every row up to the next header; collapsed sections are saved account-wide in
  `SeamlessDB.global.editModeCollapsed`. It also puts the selected frame's settings list in a
  scroll frame built like Blizzard's settings container (`ResizeLayoutFrame, ScrollFrameTemplate`),
  scrolling past 400 pixels or 60% of the screen height, whichever is smaller. Each layout sizes
  the scroll frame from the list's own height (`fixedHeight`), so collapsing always shrinks it. Each layout
  first pins the dialog's top edge, so it grows and shrinks downward only. A new selection opens the
  dialog 16 pixels beside its frame (the side with more room, top edges aligned, kept on screen)
  instead of the library's fixed bottom-right spot; it does not follow the frame afterwards. LayoutFrame ignores
  `maximumHeight` without a `minimumHeight`, so the scroll frame sets both. The list keeps its
  fully expanded width while sections collapse, and the scroll bar sits outside the window's right
  edge, so the window never changes width. This is the
  only file allowed to use `lib.internal`; it also gives feature addons `core:CreateEditModeHeader`,
  `core:Is/SetEditModeSectionCollapsed` and `core:GetEditModePositionSettings(spec)` (a Position
  header plus Anchor, AnchorParent, AnchorFrame, X and Y; collapse key
  `core:GetEditModePositionSectionKey()`, shared by every Position header). This is the it asserts on what it relies on, so recheck it and run
  `lua src/tests/editmode-dialog.lua` whenever LibEditMode is updated. Vendored files stay unpatched.
- `editmode.lua`: shared "SeamlessUI" Edit Mode extension panel. It uses the native translucent
  dialog border, sits eight pixels below the Edit Mode window, matches its width, and sizes
  to visible groups/rows. It owns its UIParent frame; never modify native layout containers.
- `systemoptions.lua`: registry for settings feature addons add to a Blizzard Edit Mode system.
  `core:RegisterEditModeSystemOptions(id, spec)` takes `system` (an `Enum.EditModeSystem` value),
  optional `systemIndex`, `name` (the section's collapsible header), optional `key` (collapse
  key `"settings:" .. (key or name)`), `order`, `enabled` and `options`: rows with `key`, `type`
  (`toggle`, `select` with `values = { { text, value } }`, or `range` with `min`, `max`, `step`
  and optional `format`), `name`, optional `desc` (tooltip), `get()`, `set(value)`, `hidden` and
  `disabled`. SeamlessUI draws the sections in its extended window below the selected frame's
  native settings; Core only keeps the registry, so no feature addon depends on SeamlessUI.
  Call `core:RefreshEditModeSystemOptions()` after a change made elsewhere; it sends the message
  `core:GetEditModeSystemOptionsMessage()`. `core:GetEditModeSystemOptions(system)` returns the
  enabled sections for a system frame, in order.
- `quests.lua`: shared quest-log summary, exposed as `core:GetQuestLogSummary()`.
- `questlog.lua`: displays completed quest count and XP in the quest log/world map header,
  left of its minimize button; refreshes when shown and when quest data or player level changes.
- `xptooltip.lua`: the `tweaks.enhancedXPTooltip` toggle (on by default) appends XP remaining and
  rested XP as a percentage of a level to the default player XP bar/rested tick tooltip; reads the
  current profile on each hover. SeamlessUI's XP bar tooltip replaces that builder while enabled
  (its completed-quests lines were Core's former `tweaks.questXPTooltip`). Time to cap is an inn/city estimate without spending rested XP,
  using configurable `restedXPCap` (150%) and `restedXPRate` (5% per eight hours); adjust these
  assumptions for perks because the client does not expose the actual cap or accrual rate.
- `tweaks.lua`: profile-aware optional conveniences; `/rl` reloads the UI (enabled by default).
  Can show the framerate once on startup (off by default); its toggle lives in the FPS display settings in
  the shared Edit Mode menu, applies on next login/reload and leaves Ctrl+R in control afterward.
  SeamlessUI owns the temporary FPS preview in Edit Mode.
- `options.lua`: the shared options layout (`Register`, `FeatureGroup`) and Core's own panel,
  "Seamless": General (minimap button, log level, a button per enabled feature addon), Profiles.
  Core tweaks have their own "Tweaks" child category (General, Profiles), using the Core database.
- `minimapbutton.lua`: the suite's single launcher, shared by the minimap button and optional
  Blizzard addon compartment entry. Their visibility toggles are independent and profile-aware;
  the compartment entry defaults off and its toggle is disabled when the client lacks support.
  Only the minimap button shows a hover tooltip; the compartment entry does not.
- `src/types.lua`: annotations only, not loaded by the TOC.

## Shared Edit Mode panel

Core owns the extension window and all built-in controls. Feature addons register once with
`core:RegisterEditModeOptions(id, spec)`, then call `core:RefreshEditModeOptions()` when their
profile, enabled state, or other external values change. Core refreshes on Edit Mode enter,
exit, layout changes and combat transitions. The panel hides outside Edit Mode or when it has
no visible rows. Registration IDs must be unique; row keys must be unique within a group.

```lua
core:RegisterEditModeOptions("MyAddon", {
    section = "frames",
    order = 100,
    name = "My frames", -- optional group heading
    enabled = function() return addon:IsEnabled() end,
    options = {
        {
            key = "preview",
            type = "toggle",
            name = "Show my frames",
            get = function() return showFrames end,
            set = function(value)
                showFrames = value
                RefreshMyFrames()
            end,
        },
        {
            key = "reset",
            type = "button",
            name = "Reset my frames",
            click = ResetMyFrames,
        },
    },
})
```

Register frame preview/movability checkboxes with `section = "frames"`. This is the
correct place for every custom frame's Edit Mode checkbox, including Damage Meter and
future frames. Core adds one shared gold **Frames** heading, hidden when no frame rows
are visible. The checkbox controls the feature's preview/selection state; register the actual
movable frame through `core:GetEditModeLibrary()` as before.

Custom options belong above Frames, inside the same window. Use the same simple API,
`core:RegisterEditModeOptions(id, { section = "options", options = { ... } })`;
`section` defaults to `"options"`. Toggle, button and custom rows all work there with the
callbacks shown here. Use separate registration IDs when an addon contributes to both areas.
The options area takes only the space its visible controls need.

Sections always place options before frames, regardless of group order.
Within each section, groups sort by `order` (default 100), then registration ID. Rows sort by `order`, defaulting
to array position. `hidden` and `disabled` accept booleans or zero-argument functions. Built-in
controls refresh after clicks and guard combat, disabled/hidden features and stale callbacks
outside Edit Mode. Getters always read current state; Core does not persist feature settings.
Labels wrap automatically, hidden rows reserve no space, and refreshes reuse existing frames.
First show and size changes queue a coalesced one-frame refresh on the addon-owned panel;
never discard layout invalidations during measurement or depend on a second Edit Mode entry.
Unresolved panel width uses the native window width until anchors settle.

Use `type = "header"` with a `name` for a collapsible section title inside a group; clicking it
hides the group's rows up to its next header, saved like the settings window's headers. Rows sit in a scroll child: when the panel would pass the screen bottom, its height
is capped and the rows scroll.

For another widget or a compound group of frames, register a `type = "custom"` row with
`create(parent)` returning an addon-owned frame directly parented to the supplied parent (the scroll child).
Set its height; Core lays it out at full content width. An optional
`layout(frame, width, disabled)` callback can update contents/child anchors and return its
measured height (or leave the row's height in place). It must honor `disabled` for its own
controls. Later row height changes automatically resize the panel. Do not reposition the row
itself, reparent it, register it with Blizzard layout containers, or access library internals.
Use the namespaced LibEditMode instance for movable systems and their individual dialogs;
this registration API supplies the shared suite controls beside those systems.

Run `lua src/tests/editmode-panel.lua` for grouping, dimensions, wrapped labels, custom rows,
control callbacks, frame reuse, native-state isolation and visibility/combat guards.

## Options: one panel per addon, tabs inside

Every addon has one AceConfig panel in Settings > AddOns, rendered by AceConfigDialog into the
native Settings window. Core's "Seamless" panel is the parent; each feature addon's panel is its
child. A panel is a tab group, always in this order:

1. **General** — the addon's main settings.
2. The addon's own tabs (`order` 1–999). Few and broad; a tab should hold enough to be worth a
   click, but never so much that it feels cramped. Group related controls into inline groups.
3. **Profiles** — AceDBOptions for the addon's database, added by Core.

Declare `## Dependencies: Seamless` in every feature TOC. At file load, obtain the
core through `LibStub("AceAddon-3.0"):GetAddon("Seamless")`; no new global is needed.

- `core:GetEditModeLibrary()`: the suite-owned namespaced LibEditMode instance.
- `core.logger`: shared logger; its threshold follows the core profile.
- `core:GetQuestLogSummary()`: a fresh table with `totalQuests`, `completedQuests` (ready to
  turn in), and `completedQuestXP` (the sum of client-reported XP rewards for those completed
  quests). Counts all non-header log entries, including quests under collapsed headers, without
  changing the selected quest or header states. Call again on `QUEST_LOG_UPDATE` to refresh.
- `core:RegisterOptions(addonName, spec)`: register the addon's panel, from the options module's
  `OnInitialize` (after its database exists). `spec`: `title` (panel name), `general` (AceConfig
  args of the General tab), optional `tabs` (AceConfig groups by key, each with `order` and `name`;
  `type = "group"` is filled in) and `db` (adds the Profiles tab). `addonName` is the AceConfig app name.
- `core:OpenOptions(addonName, tab)`: open the Settings window on the addon's panel, optionally on
  a tab key; omit the name for Seamless.
- `core:RefreshOptions(addonName)`: redraw the panel after a change made elsewhere (a CVar, a
  slash command); omit for Core. Profile changes redraw automatically.
- `core.FeatureGroup(spec)`: an inline group for one switchable feature: an Enable toggle with the
  description under it, then the feature's options. Options without their own `get`/`set` read and
  write `spec.settings()[key]` (colors as `{ r, g, b, a }`), and are disabled while the feature is
  off unless they define `disabled`. `spec.toggled` runs after the switch, `spec.changed` after any
  other setting. Tooltip and Chat build their feature tabs from it.

```lua
app.core:RegisterOptions(appName, {
    title = "My Feature",
    general = {
        main = {
            type = "group",
            inline = true,
            order = 10,
            name = "Main",
            args = {
                enabled = {
                    type = "toggle",
                    order = 10,
                    name = "Enable",
                    get = function() return app.db.profile.enabled end,
                    set = function(_, value)
                        app.db.profile.enabled = value
                        app.feature:Refresh()
                    end,
                },
            },
        },
    },
    tabs = { advanced = { order = 10, name = "Advanced", args = { ... } } },
    db = app.db,
})
```

Always read `app.db.profile` inside accessors; caching that table breaks profile switching. Put
shared `get`/`set` on a group (AceConfig inherits them; `info[#info]` is the option key) rather
than repeating them per control. AceConfigRegistry rejects unknown keys in option tables.
Use `width = "full"` and `descStyle = "inline"` for toggles whose description should be visible.

Features own their AceAddon lifecycle, SavedVariables and profiles. Core never references a
feature by name or loads disabled features. A disabled addon contributes no options or hooks.
Core profiles affect only shared settings; each feature exposes its own profiles in its panel.
New shared API members must be annotated in `src/types.lua` or on their definitions.

`/seamless [options]`, `/seamless loglevel <level>`, `/seamless reset` operate on core settings.
