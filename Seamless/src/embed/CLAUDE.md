# Embedded addons

This folder is optional. `src/embed/embed.xml` is its only entry in Seamless.toc;
removing that entry removes the module, its settings page and future embedded code.
Keep runtime code and adapters here. Do not add calls into this folder from Core.
The page intentionally lives in embed.lua instead of src/options/ so it disappears
with this single loader entry. `src/types.lua` only declares the app.embed annotation.

`embed.lua` owns the empty Embed page, opt-in booleans in the current suite profile
(`profile.embed[id]`), and a small AceModule registry. No addons are registered yet.
Do not add placeholders or example checkboxes to the shipped page.

To add an addon later:

1. Put its reusable code under a subfolder here, and read any nested CLAUDE.md.
2. Include its embedded XML after embed.lua in embed.xml, then load a local adapter.
3. At file load the adapter calls `app.embed:Register(id, spec)` with a stable ID,
   localized `name`, optional `order`, required `enable`/`disable` callbacks, and
   optional `refresh` for profile changes while already enabled. Registration adds
   its checkbox and a false default before Core combines page defaults.

The callbacks own the addon's integration, ownership checks, database namespace,
Edit Mode registration and cleanup. Loading Lua/XML makes definitions available;
the adapter must defer runtime startup, hooks and event registration until enable.
Do not modify standalone owners or vendor libraries. Disable must stop only the
runtime started by this adapter. Resolve profile settings at use time. The registry
starts/stops on checkbox changes, suite profile changes and Core module lifecycle.

Run `lua src/tests/embed.lua` and `lua src/tests/config-options.lua`. In game, check
that Embed is an empty page under Seamless and that removing its TOC entry removes
that page without breaking other settings.
