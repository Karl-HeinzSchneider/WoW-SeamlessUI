# SeamlessUI

Optional addon for general UI improvements. Requires Seamless and remains internal until
features are ready for public release.

## Load order and ownership

1. `src/core/bootstrap.lua`: obtains Core and its shared logger.
2. `src/core/db.lua`: defaults for independent `SeamlessUIDB` profiles.
3. `src/core/ace.lua`: AceAddon/AceDB lifecycle, profile refresh callbacks and `/seamlessui`.
4. `src/core/options.lua`: UI child panel under Seamless, with General and Profiles tabs.
5. `src/features/framerate.lua`: the FPS counter. An optional addon-owned mover registered
   with Core's LibEditMode makes it movable in Edit Mode (position saved per profile, shown
   while editing). "FPS Display" in the shared Edit Mode panel (no group heading) and the UI
   options turns movement on; "Show on startup" exists only in the counter's own dialog. On
   initialize it migrates Core's former `tweaks.showFramerateOnStartup` from every Core profile
   into the same-named UI profile and clears it there. Turning movement off restores the
   client's default anchor (WorldFrame BOTTOMRIGHT -2, 2). Run `lua src/tests/ui-framerate.lua`.

`src/types.lua` contains annotations only and is not loaded by the TOC. Add a field there
whenever a runtime file adds a member to the private `app` table.

## Adding improvements

Put feature modules in `src/features/` and list runtime files in dependency order in the TOC.
Use the shared Core options API and logger. Register hooks/events in module `OnEnable`,
restore changes in `OnDisable`, and read `app.db.profile` at use time. Modules with
profile-dependent behavior implement `OnProfileRefresh` to reapply it after profile changes.
Keep general UI improvements here; tooltip, unit-frame and chat features belong to their
existing addons. Do not move existing Core tweaks or their settings without a migration.

`/seamlessui` opens the panel, `/seamlessui reset` resets this addon's current profile,
and `/seamlessui loglevel <level>` delegates to Core's shared logging setting.
