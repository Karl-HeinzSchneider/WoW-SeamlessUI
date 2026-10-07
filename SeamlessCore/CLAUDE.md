# SeamlessCore

Required entry point for the Seamless suite. It works with no feature addons enabled.

## Ownership and load order

- `embeds.xml` loads all shared vendored libraries from `lib/`. Never patch vendored code.
- `src/core/logger.lua`: shared suite logger.
- `db.lua`: defaults for `SeamlessCoreDB` (logging and minimap settings).
- `ace.lua`: AceAddon lifecycle, core profiles, `/seamless` command, public integration API.
- `options.lua`: one suite options window and Settings entry, core controls and registered feature groups.
- `minimapbutton.lua`: the suite's single launcher.
- `src/types.lua`: annotations only, not loaded by the TOC.

## Feature integration

Declare `## Dependencies: SeamlessCore` in every feature TOC. At file load, obtain the
core through `LibStub("AceAddon-3.0"):GetAddon("SeamlessCore")`; no new global is needed.

- `core.logger`: shared logger; its threshold follows the core profile.
- `core:RegisterOptions(addonName, optionsGroup)`: register one AceConfig group during the
  feature options module's `OnInitialize`, after its own database exists. Names must be unique.
- `core:OpenOptions(addonName)`: open and select a feature group; omit the name to toggle the window.
- `core:RefreshOptions()`: notify AceConfig after settings change.

Features own their AceAddon lifecycle, SavedVariables and profiles. Core never references a
feature by name or loads disabled features. A disabled addon contributes no options or hooks.
Core profiles affect only shared settings; each feature exposes its own profiles in its group.
New shared API members must be annotated in `src/types.lua` or on their definitions.

`/seamless [options]`, `/seamless loglevel <level>`, `/seamless reset` operate on core settings.
