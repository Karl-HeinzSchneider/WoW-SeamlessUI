"""Generate the changed 70374 unit-frame atlas entries; optionally copy approved art.

Usage: python src/generate-legacy-unitframe-atlas.py [--art-dir PATH]
The source directory is read-only. BLP dimensions must match the old DB2 data.
"""

import argparse
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "SeamlessUnitframes/src/layout/atlas.lua"
ASSETS = ROOT / "SeamlessUnitframes/assets/legacy"


def bar_asset(name):
    if "-bar-" in name and not name.endswith("-mask"):
        return "bars/" + name.removeprefix("ui-hud-unitframe-") + ".blp"
    return None


def extract_bar(row):
    """Copy old BGRA samples into a standalone power-of-two BLP2 fill.

    A status bar redraws UVs internally. It cannot safely use an arbitrary atlas
    rectangle supplied with Texture:SetTexCoord, especially with secret values.
    No new art is drawn: nearest resampling uses only the source region's pixels.
    """
    source = (ASSETS / Path(row["textureFilename"]).name).read_bytes()
    magic, version, encoding, alpha, alpha_encoding, mipmaps, width, height = struct.unpack_from("<4sI4BII", source)
    if (magic, version, encoding, alpha, alpha_encoding) != (b"BLP2", 1, 3, 8, 8):
        raise ValueError("Bar extraction requires the exported uncompressed BGRA BLP2 sheet")
    offset = struct.unpack_from("<I", source, 20)[0]
    size = struct.unpack_from("<I", source, 84)[0]
    if size != width * height * 4 or offset + size > len(source):
        raise ValueError("Invalid BLP2 source pixel payload")
    member = row["member"]
    left, top = member["CommittedLeft"], member["CommittedTop"]
    crop_width, crop_height = row["regionWidth"], row["regionHeight"]
    if not (0 <= left < left + crop_width <= width and 0 <= top < top + crop_height <= height):
        raise ValueError("Bar region lies outside its old sheet")
    out_width = 1 << (crop_width - 1).bit_length()
    out_height = 1 << (crop_height - 1).bit_length()
    pixels = bytearray()
    for y in range(out_height):
        sy = top + min(crop_height - 1, (2 * y + 1) * crop_height // (2 * out_height))
        for x in range(out_width):
            sx = left + min(crop_width - 1, (2 * x + 1) * crop_width // (2 * out_width))
            start = offset + (sy * width + sx) * 4
            pixels.extend(source[start:start + 4])
    header_size = 148 + 1024
    header = struct.pack("<4sI4BII16I16I", b"BLP2", 1, 3, 8, 8, 0, out_width, out_height,
                         header_size, *([0] * 15), len(pixels), *([0] * 15))
    return header + bytes(1024) + pixels


# Mask UV reflection is not reliable in the client. Reflect the existing pixels
# offline instead, preserving the original canvas and BGRA values without drawing.
MIRRORED_MASKS = ("uiunitframetargethealthmask.blp", "uiunitframetargetmanamask.blp")


def mirror_mask(source):
    magic, version, encoding, alpha, alpha_encoding, mipmaps, width, height = struct.unpack_from("<4sI4BII", source)
    if (magic, version, encoding, alpha, alpha_encoding, mipmaps) != (b"BLP2", 1, 3, 8, 8, 0):
        raise ValueError("Mask reflection requires the exported single-level BGRA BLP2 mask")
    offset = struct.unpack_from("<I", source, 20)[0]
    size = struct.unpack_from("<I", source, 84)[0]
    if size != width * height * 4 or offset + size != len(source):
        raise ValueError("Invalid BLP2 mask pixel payload")
    output = bytearray(source)
    for y in range(height):
        for x in range(width):
            src = offset + (y * width + width - 1 - x) * 4
            dst = offset + (y * width + x) * 4
            output[dst:dst + 4] = source[src:src + 4]
    return bytes(output)


def preferred(variants):
    return min(variants, key=lambda row: (-row["atlas"]["UiTextureAtlasSetID"], row["atlas"]["UiCanvasID"]))


def signature(row):
    return tuple(row[key] for key in (
        "textureFileDataID", "textureWidth", "textureHeight", "regionWidth", "regionHeight",
        "leftTexCoord", "rightTexCoord", "topTexCoord", "bottomTexCoord",
    ))


def entries():
    old, new = [json.loads((ROOT / f"docs/atlas/AtlasInfo.1.60.1.{build}.json").read_text())["byName"]
                for build in (70374, 70425)]
    result = {}
    for name, variants in old.items():
        if "unitframe" not in name.lower() or not variants or not new.get(name):
            continue
        # The supplied complete art export contains the shared sheets. Atlas-set
        # records alone do not establish which alternate variants were shipped.
        shared = [row for row in variants if row["atlas"]["UiTextureAtlasSetID"] == 0]
        if not shared:
            continue
        before, after = preferred(shared), preferred(new[name])
        if signature(before) != signature(after):
            result[name.lower()] = before
    return result


def generate(art_dir=None):
    rows = entries()
    sheets = {row["textureFilename"]: row for row in rows.values()}
    if art_dir:
        # Validate the complete input before copying anything. A current build export
        # has the same filenames but incompatible canvas sizes.
        for filename, row in sheets.items():
            source = art_dir / filename
            with source.open("rb") as stream:
                magic, width, height = struct.unpack("<4s8xII", stream.read(20))
            if magic != b"BLP2" or (width, height) != (row["textureWidth"], row["textureHeight"]):
                raise ValueError(f"Not the 70374 sheet: {source} ({width} x {height})")
        ASSETS.mkdir(parents=True, exist_ok=True)
        for filename in sorted(sheets):
            shutil.copyfile(art_dir / filename, ASSETS / Path(filename).name)

    masks = ASSETS / "masks"
    masks.mkdir(parents=True, exist_ok=True)
    for filename in MIRRORED_MASKS:
        (masks / filename).write_bytes(mirror_mask((ASSETS / filename).read_bytes()))

    lines = [
        "-- Generated by src/generate-legacy-unitframe-atlas.py from the 70374/70425 lookups.",
        "-- Exported shared sheets; atlas-set records do not prove runtime selection.",
        "---@type string, SeamlessUnitframes", "local _, app = ...", "", "app.legacyAtlases = {",
    ]
    for name, row in sorted(rows.items()):
        member = row["member"]
        scale = row["atlas"]["UiCanvasID"]
        values = [member["OverrideWidth"] or member["Width"] / scale, member["OverrideHeight"] or member["Height"] / scale,
                  row["leftTexCoord"], row["rightTexCoord"], row["topTexCoord"], row["bottomTexCoord"]]
        path = "Interface/AddOns/SeamlessUnitframes/assets/legacy/" + Path(row["textureFilename"]).name
        lines.extend([f'    ["{name}"] = {{', f'        "{path}",'])
        lines.extend(f"        {value}," for value in values)
        bar = bar_asset(name)
        if bar:
            destination = ASSETS / bar
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(extract_bar(row))
            lines.append(f'        "Interface/AddOns/SeamlessUnitframes/assets/legacy/{bar}",')
        lines.append("    },")
    lines.append("}\n")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"Generated {len(rows)} atlas entries using {len(sheets)} old sheets")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--art-dir", type=Path)
    generate(parser.parse_args().art_dir)
