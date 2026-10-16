# Unit-frame layout switch

Settings → AddOns → Seamless → Unit Frames → General → **Unit frame layout**.
**Current (70425)** is the default. This layout module installs no frame hooks and
changes no frames until Legacy has been selected. Existing health-color settings
remain independent.

**Legacy (before 70425)** uses the old exported artwork and pre-update geometry.
Switching back applies explicit 70425 sizes, anchors, justification, layering and
atlas definitions. It never restores snapshots of live rendering state.
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
Status-bar fills are extracted from those sheets into 43 standalone uncompressed
BLP files. Their canvases use power-of-two dimensions with nearest resampling of
the original region's BGRA pixels; no new artwork is drawn. The owning status bar
receives the standalone file through `SetStatusBarTexture` and owns its fill UVs.
This prevents native value updates from sampling unrelated atlas-sheet artwork
and requires no Lua arithmetic on health/power values, including secret values.
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
continues to use the client. Health colors resolve atlas names from fixed frame
families; they never read live texture atlas names. Default, class, reaction and
combined modes use the same bar setter in either layout. The existing target and
minus-target white fills are unchanged across the atlas lookups and remain native.
The party vehicle fill has no white variant and keeps its native color.

## Combat and secret-value boundary

The layout defines both builds explicitly in `geometry.lua`, using the source
references above. It visits only named player, target/focus, boss, pet/ToT and
party components (including named party pets). No recursive child/region discovery,
render snapshots, atlas-size inference or anchor enumeration remains. It does not
call `GetAtlas`, dimension getters, `GetPoint`, `GetNumPoints`, `GetTexCoord` or
`GetFrameLevel`. Builder/spender and resource feedback descendants are untouched.
`GetStatusBarTexture` retrieves only the fill object of an explicitly named bar.
Visibility reads for the extra PvP background are access-checked before branching.

Only secure post-hooks observe client update functions and known instance methods.
No Blizzard function, mixin, script or protected frame state field is replaced.
Native hook arguments are ignored. All bookkeeping uses private addon tables.
Gameplay classification, art-state fields and power tokens are access-checked
before comparison or indexing. Unavailable components and unsupported/inaccessible
power/classification data are skipped with deduplicated logger warnings.

Geometry, layering and layout selection changes wait until combat ends. The final
profile selection is applied after `PLAYER_REGEN_ENABLED`. Health tint and fill
updates use constant atlas/file arguments through the native status-bar setter;
they do not perform geometry work or arithmetic on health/power values. Native
updates during combat can temporarily restore current geometry/art; the addon
reapplies Legacy after lockdown. This implementation does not claim uninterrupted
legacy geometry during combat.

Switching to Current retires each known artwork override, resets static atlas UVs,
and applies the fixed current definitions. Root positions, scales, gameplay state
and visibility remain client-owned. Other addons' custom geometry is not captured
or replayed. The live player health fill uses BACKGROUND sublevel 1 in Legacy so
the native red loss fill stays behind it; Current restores sublevel 0.

The offline Lua fixture makes all rendering/discovery getters and `HookScript`
throw. It exercises initial Current inactivity, repeated switching, fixed current
restoration, class/reaction color modes, minus targets, party/vehicle/resource
styles, missing components, secret inputs and combat deferral. Python tests check
BLP dimensions, deterministic generation and source pixels. These checks cannot
prove live-client visual correctness or taint safety.

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
