# SeamlessCore

Required entry point for the Seamless suite. It works with no feature addons enabled.

## Ownership and load order

- `embeds.xml` loads all shared vendored libraries from `lib/`, including AceGUI, AceConfig,
  AceDBOptions, LibSharedMedia and LibEditModeOverride. Never patch vendored code.
- `src/core/logger.lua`: shared suite logger.
- `db.lua`: defaults for `SeamlessCoreDB` (logging, minimap settings and tweaks).
- `ace.lua`: AceAddon lifecycle, core profiles, `/seamless` command, public integration API.
- `tweaks.lua`: profile-aware optional conveniences; `/rl` reloads the UI (enabled by default).
  Shows the framerate once on startup by default; its toggle applies on next login/reload and leaves Ctrl+R in control afterward.
- `options.lua`: the shared options layout (`Register`, `FeatureGroup`) and Core's own panel,
  "Seamless": General (minimap button, log level, a button per enabled feature addon), Tweaks, Profiles.
- `minimapbutton.lua`: the suite's single launcher.
- `src/types.lua`: annotations only, not loaded by the TOC.

## Options: one panel per addon, tabs inside

Every addon has one AceConfig panel in Settings > AddOns, rendered by AceConfigDialog into the
native Settings window. Core's "Seamless" panel is the parent; each feature addon's panel is its
child. A panel is a tab group, always in this order:

1. **General** — the addon's main settings.
2. The addon's own tabs (`order` 1–999). Few and broad; a tab should hold enough to be worth a
   click, but never so much that it feels cramped. Group related controls into inline groups.
3. **Profiles** — AceDBOptions for the addon's database, added by Core.

Declare `## Dependencies: SeamlessCore` in every feature TOC. At file load, obtain the
core through `LibStub("AceAddon-3.0"):GetAddon("SeamlessCore")`; no new global is needed.

- `core.logger`: shared logger; its threshold follows the core profile.
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
