# SeamlessDarkmode

Optional UI decoration tinting addon requiring Seamless. Internal until verified in game.
Enable its folder beside Core and open `/seamlessdarkmode` or Seamless > Darkmode.

- `src/core.lua`: AceAddon/AceDB lifecycle, category/root registry, timer/events and independent
  `SeamlessDarkmodeDB` profiles. All categories default on with a shared dark gray tint.
- `src/theme.lua`: bounded traversal of client frames, selective decorative texture and backdrop
  border tinting, reversible color hooks, and neutral aura borders using existing client art.
- `src/options.lua`: shared color picker, master switch, five category toggles (unit frames, action bars, minimap, buffs/debuffs and bags/bank) and Profiles.
- `src/types.lua`: annotations only; not loaded. Update it when adding private app members.

Read profile settings at use time. Color hooks retain the latest client-requested color and
alpha; disable restores them. Permanent secure hooks are inert while disabled. Do not tint
portraits, icon contents, bar fills, text or status/quality indicators. Aura surrounds are
separate from debuff/dispel borders. Never replace game functions or protected frame scripts.
Scans run once per second and on addon loading/world entry; combat defers traversal, creation
and options refresh until PLAYER_REGEN_ENABLED. Chat, tooltips and general windows/menus
are outside this addon's scope. Arbitrary custom artwork is not automatically skinned.

Manual validation: toggle every category and the master switch; change/reset/copy/switch
profiles; open late-loaded bags/bank; gain/lose buffs and weapon enchants; open separate and
combined bags; inspect target/party/raid borders and action states; change settings in combat
and verify application after combat. Check restoration and taint.
