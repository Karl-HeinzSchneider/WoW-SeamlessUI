# Unit-frame layout switch

Settings → AddOns → Seamless → Unit Frames → General → **Unit frame layout**.
**Current (70425)** is the default. This layout module installs no frame hooks and
changes no frames until Legacy has been selected. Existing health-color settings
remain independent.

**Legacy (before 70425)** uses the old exported artwork and pre-update geometry.
Switching back restores the latest sizes, anchors, justification, layering and
atlases requested by the client, including updates received while Legacy was active.
The selection belongs to the Unit Frames appearance profile and follows profile
copy/reset/switch operations.

## Source references

Layout comparison:
[70374](https://github.com/Gethe/wow-ui-source/tree/735496de78ebd30ce816a0637982c556987f258c/Interface/AddOns/Blizzard_UnitFrame)
and
[70425](https://github.com/Gethe/wow-ui-source/tree/b401e0332adfbf0460d319b06d8ea29279a941f1/Interface/AddOns/Blizzard_UnitFrame).
Forever's TOC loads both Mainline base code and Camelot overrides. Runtime
geometry follows the old base code where the new Camelot overrides changed it.
Gameplay behavior, combat status priority and unit attributes remain client-owned.

The approved art source is the user's complete local pre-update export at
`D:/Spiele/World of Warcraft/_classic_beta_/BlizzardInterfaceArt`.
Ten original BLP sheets are copied without conversion into the addon. The atlas
generator validates their BLP dimensions against the 70374 lookup before copying.
It selects the exported shared atlas sheets, not the unverified alternate atlas-set
variants also present in the DB2 reference. The export does not contain the
`c60` unit/party sheets. PvP faction icons therefore retain their client atlas;
their old anchors and separate background circles are restored.

Regenerate the runtime lookup (offline), then optionally validate/copy the art:

```powershell
python src/generate-legacy-unitframe-atlas.py
python src/generate-legacy-unitframe-atlas.py --art-dir 'D:/Spiele/World of Warcraft/_classic_beta_/BlizzardInterfaceArt'
lua src/test-legacy-layout.lua
```

The generated table contains only changed effective atlas entries. Unchanged art
continues to use the client. Health colors use the layout module's logical atlas
name when its texture is backed by bundled artwork, preserving white health fills
and restoring the current client atlas when Legacy is deselected.

## Combat and taint boundary

Only secure post-hooks observe client changes. No Blizzard global function or
mixin is replaced. Snapshot and override state lives in private tables, not on
protected frames. The module never changes unit attributes, event registrations
or scripts on the game's unit buttons. Root visibility changes are observed through
`hooksecurefunc` on `Show` and `SetShown`; no descendant script handlers are hooked.

All layout writes, including restoration and late frame discovery, are deferred
while `InCombatLockdown()` is true. The last profile selection is applied after
`PLAYER_REGEN_ENABLED`. A native layout refresh during combat can temporarily
restore current geometry/art until combat ends; the addon deliberately does not
fight protected frame updates during lockdown. This is a limitation of this
implementation, not a claim of uninterrupted legacy geometry during combat.
Offline tests assert that no layout mutation happens during lockdown; they cannot
prove live-client taint behavior.

Texture dimensions can also be secret outside combat. Atlas-size inference checks
access before comparing them. Secret dimensions remain client-owned: the module
does not resize them or replay them through size setters during restoration.

Callbacks use AceAddon's returned module instance, whose prototype is a separate
table. Geometry validates nested frame paths before using them. Missing methods,
incomplete layouts and forbidden regions produce a warning naming the failed
operation/path, once per distinct issue per session; later refreshes retry frames
that finish initializing.

## In-game validation still required

- Login/reload with Current and with Legacy saved; repeatedly toggle both ways.
- Enter combat, change profiles or layout, target different classifications, and
  leave combat. Confirm the final selection applies without blocked actions.
- Target/focus normal, elite, rare, boss and minus units, including no target.
- Join/leave a party; change party art styles and enter/leave vehicles.
- Test pets, target-of-target, focus target and their visibility CVars.
- Test druid forms, mana/energy/rage, alternate resources, death and disconnection.
- Check health/absorb/heal prediction, class/reaction colors, threat, PvP flags
  and timers, combo points, name truncation and Chinese locales.
- Move/scale frames in Edit Mode; check restoration and unrelated addon skins.
- Enable taint logging and check for blocked actions and Lua errors.
