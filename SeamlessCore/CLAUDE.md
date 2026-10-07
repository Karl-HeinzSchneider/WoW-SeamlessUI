# SeamlessCore

Required entry point for the Seamless suite. It works with no feature addons enabled.

## Ownership and load order

- `embeds.xml` loads all shared vendored libraries from `lib/`. Never patch vendored code.
- `src/core/logger.lua`: shared suite logger.
- `db.lua`: defaults for `SeamlessCoreDB` (logging and minimap settings).
- `ace.lua`: AceAddon lifecycle, core profiles, `/seamless` command, public integration API.
- `settings.lua`: native Settings panel helpers (namespaced proxy settings, search tags, controls and refresh).
- `profiles.lua`: shared native profile controls backed by AceDB, with confirmation dialogs.
- `options.lua`: the native Seamless parent category, core controls and feature subcategory registration.
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
`Header(name)`, and `Profiles(db)`. Checkbox/dropdown specs include `id`, `name`, `default`, `get`,
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
