# SeamlessCore

Required entry point for the Seamless suite. It works with no feature addons enabled.

## Ownership and load order

- `embeds.xml` loads all shared vendored libraries from `lib/`, including LibSharedMedia and LibEditModeOverride. Never patch vendored code.
- `src/core/logger.lua`: shared suite logger.
- `db.lua`: defaults for `SeamlessCoreDB` (logging, minimap settings and tweaks).
- `tweaks.lua`: profile-aware optional conveniences; `/rl` reloads the UI (enabled by default).
  Shows the framerate once on startup by default; its toggle applies on next login/reload and leaves Ctrl+R in control afterward.
- `ace.lua`: AceAddon lifecycle, core profiles, `/seamless` command, public integration API.
- `settings.lua`: native Settings panel helpers (namespaced proxy settings, search tags, controls and refresh).
- `settings-actions.lua`: native input and details dialogs, input validation and confirmed actions.
- `settings-options.lua`: adapter for declarative feature options, including typed selects, sliders
  and RGB/opacity controls backed by existing SavedVariables.
- `profiles.lua`: shared native profile controls backed by AceDB, with confirmation dialogs.
- `options.lua`: the native Seamless parent category, core controls and feature subcategory registration.
  Core tweaks live in the `SeamlessCore.Tweaks` child category alongside feature addons; they use the Core profile.
- `minimapbutton.lua`: the suite's single launcher.
- `src/types.lua`: annotations only, not loaded by the TOC.

## Feature integration

Declare `## Dependencies: SeamlessCore` in every feature TOC. At file load, obtain the
core through `LibStub("AceAddon-3.0"):GetAddon("SeamlessCore")`; no new global is needed.

- `core.logger`: shared logger; its threshold follows the core profile.
- `core:RegisterOptions(addonName, title, build)`: create a native vertical-layout child category
  and call `build(panel)` during the feature options module's `OnInitialize`, after its database exists.
- `core:OpenOptions(addonName)`: open the native Settings window to a feature; omit the name for Seamless.
- `core:RefreshOptions(addonName)`: notify the panel's settings after external changes; omit for Core.

The panel exposes `Checkbox(spec)`, `Dropdown(spec)`, `Button(name, buttonText, callback, tooltip)`,
`Slider(spec)`, `Color(spec)`, `Input(spec)`, `Description(name, text)`, `Action(spec, callback, confirmation)`, `Header(name)`, and `Profiles(db)`. Checkbox/dropdown specs include `id`, `name`, `default`, `get`,
`set`, optional `tooltip`, `shown` and `tags`. Dropdowns also take an ordered `options` list of
`{ value, label, tooltip? }` entries, or a function returning that list. Dropdown values are strings
unless `variableType` is specified. IDs are unique within the panel and prefixed with the addon name.
Helpers return native initializers for additional predicates or control customization.

```lua
core:RegisterOptions(addonName, "My Feature", function(panel)
    panel:Checkbox({
        id = "enabled",
        name = "Enable feature behavior",
        default = true,
        get = function() return app.db.profile.enabled end,
        set = function(value)
            app.db.profile.enabled = value
            app.feature:Refresh()
        end,
    })
    panel:Profiles(app.db)
end)
```

Always read `app.db.profile` inside accessors; caching that table breaks profile switching.
Use explicit defaults from the addon defaults, not the current saved value. A nil default excludes
an action selector (e.g. active profile) from native Defaults. Profile helpers subscribe to AceDB
callbacks and refresh the panel automatically. Other external changes, such as CVars, need an event
handler that calls `RefreshOptions(addonName)`.

The native search indexes setting labels; helpers also tag controls with Seamless and the panel title.
Keep labels specific enough to distinguish search results (e.g. "Target health bar color").
AceConfig, AceGUI and AceDBOptions remain vendored but are no longer loaded in `embeds.xml`.

Features own their AceAddon lifecycle, SavedVariables and profiles. Core never references a
feature by name or loads disabled features. A disabled addon contributes no options or hooks.
Core profiles affect only shared settings; each feature exposes its own profiles in its category.
New shared API members must be annotated in `src/types.lua` or on their definitions.

`/seamless [options]`, `/seamless loglevel <level>`, `/seamless reset` operate on core settings.

## Declarative feature options

`panel:Options(group)` binds a collection of toggle/select/range/color definitions to profile values.
The group supplies `id` (prefix), `name` (searchable label prefix), `options`, `defaults`, `get`
(return current settings table), `changed` (apply feature settings), and optional `enabled`,
`dependencies` (panel-local setting IDs) and `tags`. See Tooltip's `features.lua` for an example.
This adapter supports the migrated option metadata without loading AceConfig. Unsupported types fail
explicitly; custom get/set callbacks receive an info table with the option key and definition. Color callbacks
use r/g/b/a arguments, preserving the migrated feature definitions.

Primitive specs may use `enabled` plus `dependencies` for dependent controls. Sliders take min/max/step
and an optional format function. Color specs use native ARGB hex strings. The declarative adapter
preserves RGBA tables, converts only RGB for the stock swatch, and adds an opacity slider: this client's
native color picker does not edit alpha. Late media providers are evaluated when menus open.

The adapter also supports `input`, `execute`, `description` and `header`. Inputs use a prefilled
native dialog (empty strings allowed), optional validation, and explicit `default` overrides for
nested settings. Supply defaults from the schema, never the current saved value. Hidden predicates
become disabled native controls so changing a sibling value does not require rebuilding the layout.
Descriptions are evaluated on hover or opening Details; this avoids reading another module's state
before initialization. Execute options honor `confirm` and `confirmText`. Input/action contexts guard
against applying an old dialog to a newly selected profile. No AceConfig runtime is loaded.
