"""Join build-specific DB2 CSV exports without dropping variants or unknown data.

Usage: python src/generate-atlas-lookups.py [--listfile path/to/community-listfile.csv]
Only the required listfile entries are saved, making subsequent runs offline.
"""

import argparse
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs" / "atlas"
BUILDS = ("1.60.1.70374", "1.60.1.70425")


def source_hash(path):
    # Git checkouts may translate line endings on Windows.
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def read_table(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    return [
        {key: value if key in ("Name", "CommittedName") else int(value)
         for key, value in row.items()}
        for row in rows
    ]


def keyed(rows):
    result = {row["ID"]: row for row in rows}
    if len(result) != len(rows):
        raise ValueError("Duplicate source IDs")
    return result


def join(atlases, elements, members, filenames):
    sheets = keyed(atlases)
    names = keyed(elements)
    keyed(members)
    lookup = {row["Name"]: [] for row in elements}
    if len(lookup) != len(elements):
        raise ValueError("Duplicate element names")
    for member in sorted(members, key=lambda row: row["ID"]):
        sheet = sheets[member["UiTextureAtlasID"]]
        element = names[member["UiTextureAtlasElementID"]]
        width, height = sheet["AtlasWidth"], sheet["AtlasHeight"]
        if width <= 0 or height <= 0:
            raise ValueError(f"Invalid sheet dimensions: {sheet['ID']}")
        left, right = member["CommittedLeft"], member["CommittedRight"]
        top, bottom = member["CommittedTop"], member["CommittedBottom"]
        flags = member["CommittedFlags"]
        issues = []
        if not (0 <= left < right <= width and 0 <= top < bottom <= height):
            issues.append("invalid_or_out_of_bounds_rectangle")
        if member["CommittedName"] and member["CommittedName"].casefold() != element["Name"].casefold():
            issues.append("committed_name_differs")
        if (member["Width"], member["Height"]) != (right - left, bottom - top):
            issues.append("source_size_differs_from_rectangle")
        lookup[element["Name"]].append({
            "member": member,
            "atlas": sheet,
            "textureFileDataID": sheet["FileDataID"],
            "textureFilename": filenames.get(sheet["FileDataID"]),
            "textureWidth": width,
            "textureHeight": height,
            "regionWidth": right - left,
            "regionHeight": bottom - top,
            "leftTexCoord": left / width,
            "rightTexCoord": right / width,
            "topTexCoord": top / height,
            "bottomTexCoord": bottom / height,
            "tilesHorizontally": bool(flags & 4) and not bool(flags & 16),
            "tilesVertically": bool(flags & 2) and not bool(flags & 16),
            "uninterpretedFlags": flags & ~(2 | 4 | 16),
            "issues": issues,
        })
    return dict(sorted(lookup.items()))


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def generate(build, filenames):
    paths = {table: DATA / "sources" / f"{table}.{build}.csv" for table in (
        "UiTextureAtlas", "UiTextureAtlasElement", "UiTextureAtlasMember"
    )}
    atlases, elements, members = (read_table(path) for path in paths.values())
    lookup = join(atlases, elements, members, filenames)
    element_ids = {row["Name"]: row["ID"] for row in elements}
    counts = Counter(issue for variants in lookup.values()
                     for variant in variants for issue in variant["issues"])
    metadata = {
        "build": build,
        "schemaVersion": 1,
        "sources": {path.name: source_hash(path)
                    for path in paths.values()},
        "filenameSource": "sources/texture-filenames.csv (community names, not build-verified)",
        "filenameSourceSHA256": source_hash(DATA / "sources" / "texture-filenames.csv"),
        "summary": {
            "textureSheets": len(atlases), "elements": len(elements), "members": len(members),
            "elementsWithoutMembers": sum(not variants for variants in lookup.values()),
            "elementsWithMultipleMembers": sum(len(variants) > 1 for variants in lookup.values()),
            "sheetsWithoutFilenames": sum(row["FileDataID"] not in filenames for row in atlases),
            "issues": dict(sorted(counts.items())),
        },
        "textureSheets": {str(row["ID"]): {**row, "textureFilename": filenames.get(row["FileDataID"])}
                          for row in atlases},
        "elements": {str(row["ID"]): row["Name"] for row in elements},
    }
    # One name per line keeps the generated lookup searchable and diffs manageable.
    text = json.dumps(metadata, ensure_ascii=False, indent=2)[:-2] + ',\n  "byName": {\n'
    text += ",\n".join("    " + json.dumps(name, ensure_ascii=False) + ": " +
                       json.dumps(variants, ensure_ascii=False) for name, variants in lookup.items())
    (DATA / f"AtlasInfo.{build}.json").write_text(text + "\n  }\n}\n", encoding="utf-8")
    sheets = keyed(atlases)
    rows = []
    for name, variants in lookup.items():
        for variant in variants or [None]:
            member = variant["member"] if variant else {key: None for key in members[0]}
            sheet = sheets[member["UiTextureAtlasID"]] if variant else {key: None for key in atlases[0]}
            row = {"Name": name, "ElementID": element_ids[name],
                   "Status": "member" if variant else "no_member"}
            row.update({f"Member_{key}": value for key, value in member.items()})
            row.update({f"Atlas_{key}": value for key, value in sheet.items()})
            for key in next(iter(v for vs in lookup.values() for v in vs)):
                if key not in ("member", "atlas"):
                    value = variant[key] if variant else None
                    row[key] = ";".join(value) if isinstance(value, list) else value
            rows.append(row)
    write_csv(DATA / f"AtlasInfo.{build}.csv", rows)
    print(build, json.dumps(metadata["summary"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listfile", type=Path)
    args = parser.parse_args()
    filename_path = DATA / "sources" / "texture-filenames.csv"
    if args.listfile:
        needed = {row["FileDataID"] for build in BUILDS for row in
                  read_table(DATA / "sources" / f"UiTextureAtlas.{build}.csv")}
        filenames = {}
        with args.listfile.open(encoding="utf-8-sig", newline="") as stream:
            for row in csv.reader(stream, delimiter=";"):
                if len(row) == 2 and row[0].isdigit() and int(row[0]) in needed:
                    filenames[int(row[0])] = row[1]
        write_csv(filename_path, [{"FileDataID": key, "Filename": value}
                                  for key, value in sorted(filenames.items())])
    with filename_path.open(encoding="utf-8", newline="") as stream:
        filenames = {int(row["FileDataID"]): row["Filename"] for row in csv.DictReader(stream)}
    for build in BUILDS:
        generate(build, filenames)


if __name__ == "__main__":
    main()
