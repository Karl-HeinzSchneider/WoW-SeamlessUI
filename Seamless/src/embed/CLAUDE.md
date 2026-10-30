# Embedded addons

This folder is optional. `src/embed/embed.xml` is its only entry in Seamless.toc;
removing that entry removes the module, its settings page and future embedded code.
Keep runtime code and adapters here. Do not add calls into this folder from Core.
The page intentionally lives in embed.lua instead of src/options/ so it disappears
with this single loader entry. `src/types.lua` only declares the app.embed annotation.

`embed.lua` owns the Embed page, opt-in booleans in the current suite profile
(`profile.embed[id]`), and a small AceModule registry. Do not add placeholders or
example checkboxes to the shipped page.

## Registered addons

- `grouploot.lua` (`groupLoot`, on by default): BetterGroupLoot-1.0 roll frames. The library is vendored
  unmodified in `Seamless/lib/BetterGroupLoot-1.0/` (update it by copying the folder from
  the WoW-BetterGroupLoot repository, never by editing it) and included by embed.xml.
  Enable calls `Start` with the `SeamlessGroupLoot` frame prefix and the AceDB namespace
  `GroupLoot` (created on first enable, defaults `BGL.defaults`); disable calls `Stop`.
  Only the first host to start the library in a UI session owns the frames: when the
  standalone BetterGroupLoot started first, enable only logs at debug level. Ownership stays
  reserved until reload. Edit Mode registers once per session with Core's LibEditMode,
  the library's own Scale/Spacing/Stack/Undecided rows and an explicit Revert/Reset
  Position footer; in combat it waits for `PLAYER_REGEN_ENABLED`. Position stays the
  library's bottom-center offset on UIParent in the namespace profile. It registers with
  `managePreviews = false` and adds a "Group loot" row to the Edit Mode window's Frames
  list (session-only, on by default). Turning it off hides the previews and the
  selection but never the anchor, because the anchor also parents real rolls.

To add an addon later:

1. Put its reusable code under a subfolder here, and read any nested CLAUDE.md.
2. Include its embedded XML after embed.lua in embed.xml, then load a local adapter.
3. At file load the adapter calls `app.embed:Register(id, spec)` with a stable ID,
   localized `name`, optional `order`, optional `default` (true starts it enabled;
   false when omitted), required `enable`/`disable` callbacks, and optional `refresh`
   for profile changes while already enabled. Registration adds its checkbox and its
   default before Core combines page defaults.
4. Pass the library's text in from the adapter as `L[...]` strings. Put those keys, and its
   checkbox name, in a new `-- Embed: <Library>` section at the end of
   `Seamless/locales/enUS.lua`, reusing shared keys (such as `Scale`), then run
   `npm run locales:sync`.

The callbacks own the addon's integration, ownership checks, database namespace,
Edit Mode registration and cleanup. Loading Lua/XML makes definitions available;
the adapter must defer runtime startup, hooks and event registration until enable.
Do not modify standalone owners or vendor libraries. Disable must stop only the
runtime started by this adapter. Resolve profile settings at use time. The registry
starts/stops on checkbox changes, suite profile changes and Core module lifecycle.

Run `lua src/tests/embed.lua`, `lua src/tests/embed-grouploot.lua` and
`lua src/tests/config-options.lua`. In game, check
the Embed page's checkboxes, and that removing its TOC entry removes that page without
breaking other settings.
