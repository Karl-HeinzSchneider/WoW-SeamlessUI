# UI texture atlas lookup

Joined reference data for WoW Forever builds **1.60.1.70374** and **1.60.1.70425**.
These files are development references, excluded from addon releases by the existing
`docs` packaging rule. No texture images are included.

For each build:

- `AtlasInfo.<build>.csv`: searchable flat lookup with one row per member variant;
  elements with no member have a `no_member` row with blank texture/coordinate fields.
- `AtlasInfo.<build>.json`: lookup by exact element name under `byName`. Each value
  is an array containing **all** member variants, or `[]` when the supplied data
  has no member. Each variant includes its original `member` and `atlas` records
  plus the resolved filename, pixel region dimensions, UV coordinates and flags.
  `textureSheets` also preserves unused sheets, and `elements` preserves every element ID.

For example, in build 70425, `byName["MainPet-PetFamilyFrame"]` includes texture
FileDataID **878877**, a **1024 × 1024** sheet, a **34 × 34** region with pixel bounds
`left=881, right=915, top=987, bottom=1021`. Its normalized coordinates are
`left=0.8603515625, right=0.8935546875, top=0.9638671875, bottom=0.9970703125`.
The resolved filename is `interface/petbattles/petbattlehudatlas.blp`.

## Field meanings

Joins use `member.UiTextureAtlasElementID = element.ID` and
`member.UiTextureAtlasID = atlas.ID`. Element names are the lookup keys;
`CommittedName` is preserved separately, including differences in casing or spelling.
Multiple records can share an element, including different canvases. No variant is
selected as the presumed runtime default.

| Field                                           | Meaning                                                                   |
| ----------------------------------------------- | ------------------------------------------------------------------------- |
| `textureFilename`                               | Community-listfile path, or JSON `null` / blank CSV when unresolved       |
| `textureFileDataID`                             | Numeric texture identifier; use this when the filename is unknown         |
| `textureWidth`, `textureHeight`                 | Full sheet dimensions in pixels from `AtlasWidth`, `AtlasHeight`          |
| `member.Width`, `member.Height`                 | Original source dimensions, preserved as supplied                         |
| `member.OverrideWidth`, `member.OverrideHeight` | Original dimension overrides, preserved as supplied                       |
| `regionWidth`, `regionHeight`                   | `CommittedRight - CommittedLeft`, `CommittedBottom - CommittedTop`        |
| `leftTexCoord`, `rightTexCoord`                 | Pixel left/right divided by full sheet width                              |
| `topTexCoord`, `bottomTexCoord`                 | Pixel top/bottom divided by full sheet height                             |
| `tilesHorizontally`, `tilesVertically`          | Flags `0x4`, `0x2`, suppressed when `0x10` is set                         |
| `uninterpretedFlags`                            | Other flag bits retained without assigning undocumented meanings          |
| `issues`                                        | Source anomalies, retained without clamping bounds or changing dimensions |

The original atlas set IDs, canvas IDs, all member fields and all element IDs are
retained. CSV prefixes `Member_` and `Atlas_` distinguish original table columns.
Dimensions and overrides are deliberately separate from the pixel region: this is
a DB2 lookup, not a verified dump of the client's `C_Texture.GetAtlasInfo` return values.
No slice data is invented because none is present in these exports.

The flag interpretation follows the
[WoWDBDefs definition](https://github.com/wowdev/WoWDBDefs/blob/master/definitions/UiTextureAtlasMember.dbd).
The layout is inspired by
[Townlong Yak AtlasInfo](https://www.townlong-yak.com/framexml/live/Helix/AtlasInfo.lua),
but preserves variants and source fields rather than collapsing to positional arrays.

## Provenance and regeneration

`sources/` contains the six user-supplied CSV exports and the subset of filename
mappings used by these builds. Each JSON includes SHA-256 hashes of its three
source exports, with CRLF normalized to LF for cross-platform reproducibility.
Filenames come from the
[wowdev community listfile](https://github.com/wowdev/wow-listfile), retrieved on
2026-10-16. Community names can be inferred or renamed and are **not build-verified**;
FileDataIDs and the supplied build data remain authoritative. Unknown paths are left blank.

Generate both builds offline with Python 3 (standard library only):

```powershell
python src/generate-atlas-lookups.py
python -m unittest discover -s src -p test_atlas_lookups.py
```

To refresh the filename subset from a downloaded semicolon-delimited community listfile:

```powershell
python src/generate-atlas-lookups.py --listfile C:/path/to/community-listfile.csv
```

Example PowerShell lookup (all variants):

```powershell
$atlas = Get-Content docs/atlas/AtlasInfo.1.60.1.70425.json -Raw | ConvertFrom-Json
$atlas.byName.'MainPet-PetFamilyFrame'
```

The generated JSON intentionally uses one line per name. Regeneration is deterministic;
the generator reports record counts, missing filename counts and source anomalies.
