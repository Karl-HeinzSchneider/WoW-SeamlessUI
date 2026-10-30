# BetterGroupLoot integration

This is an opt-in Core component under the shared embed loader, not a separate
addon. `embed.xml` loads bootstrap, the pinned vendor XML, adapter and options.
Removing Core's one src/embed/embed.xml TOC entry removes everything here.

- `bootstrap.lua` creates Core's private `app.groupLoot` table and localized logger
  and tooltip text. Upstream never shares Core's API/controller fields.
- `vendor/` is generated from the commit in vendor/source.json. Every imported Lua
  file wraps the exact upstream source in a function invoked with app.groupLoot.
  This changes only the script's private-table binding. Do not hand-edit vendor
  code. No standalone database, settings bootstrap or library is imported.
- `adapter.lua` registers the embed checkbox, lifecycle, shared Frames checkbox,
  visibility binding and position service. `options.lua` owns defaults and the
  frame's page/footer. Upstream's settings rows supply both Style surfaces.

To update the pinned source, fetch the upstream repository and run from the root:
`npm run embed:group-loot -- <local BetterGroupLoot repository> <commit-or-ref>`.
The tool reads committed files using git show; it does not modify that repository.
Review upstream load-graph changes and run the integration tests after updates.

The checkbox is `profile.embed.BetterGroupLoot`; runtime settings are Core's
`profile.groupLoot`, read at use time. The runtime is named SeamlessGroupLoot and
uses Core's private Edit Mode library, shared Position/scale controls and explicit
Revert/Reset footer. Moving detaches to UIParent; reference-frame choices are
validated by Core's position service. Visibility is session-only and shared by the
Frames checkbox and page header. No GLOBAL Edit Mode option is registered.

Startup is deferred in combat. Disabling cancels pending startup and stops only
this adapter's controller. The upstream ownership protocol is first-started wins:
if standalone owns it, show the localized status without creating frames/hooks.
Ownership stays reserved until reload even after stopping, as upstream specifies.
The local adapter uses the client's public roll refresh to hide existing native
rolls on enable and restore active roll buttons after Stop; gamepad UI is untouched.

Run `lua src/tests/embed-group-loot.lua`, `lua src/tests/embed.lua`, and
`lua src/tests/config-options.lua` with and without the `without-embed` argument.
The integration harness imports the real vendor XML and tests both ownership
orders, actual rolls/previews, settings/profile changes, dragging, and combat.
Manual game testing must cover selection, dragging/nudges, quick anchoring,
Revert/Reset, preview toggles, and coexistence with standalone BetterGroupLoot.
