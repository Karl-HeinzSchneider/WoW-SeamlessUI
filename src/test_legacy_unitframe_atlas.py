"""Verify bundled BLPs and deterministic old atlas generation (standard library)."""

import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("legacy_atlas", ROOT / "src/generate-legacy-unitframe-atlas.py")
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


class LegacyAtlasTests(unittest.TestCase):
    def test_assets_match_old_atlas_canvases(self):
        rows = GENERATOR.entries()
        self.assertTrue(rows)
        expected = set()
        for name, row in rows.items():
            with self.subTest(atlas=name):
                path = GENERATOR.ASSETS / Path(row["textureFilename"]).name
                expected.add(path)
                magic, width, height = struct.unpack("<4s8xII", path.read_bytes()[:20])
                self.assertEqual(magic, b"BLP2")
                self.assertEqual((width, height), (row["textureWidth"], row["textureHeight"]))
                for key in ("leftTexCoord", "rightTexCoord", "topTexCoord", "bottomTexCoord"):
                    self.assertGreaterEqual(row[key], 0)
                    self.assertLessEqual(row[key], 1)
        self.assertEqual(set(GENERATOR.ASSETS.glob("*.blp")), expected)

    def test_mirrored_masks_preserve_every_reflected_pixel(self):
        for filename in GENERATOR.MIRRORED_MASKS:
            source = (GENERATOR.ASSETS / filename).read_bytes()
            output = (GENERATOR.ASSETS / "masks" / filename).read_bytes()
            width, height, offset = struct.unpack_from("<III", source, 12)
            self.assertEqual(source[:offset], output[:offset])
            self.assertEqual(len(source), len(output))
            for y in range(height):
                for x in range(width):
                    src = offset + (y * width + width - 1 - x) * 4
                    dst = offset + (y * width + x) * 4
                    self.assertEqual(source[src:src + 4], output[dst:dst + 4])
            self.assertEqual(GENERATOR.mirror_mask(output), source)

    def test_reflected_fills_match_source_pixels(self):
        originals = GENERATOR.ASSETS / "bars"
        reflected = originals / "mirrored"
        for path in reflected.glob("*.blp"):
            self.assertEqual(path.read_bytes(), GENERATOR.mirror_mask((originals / path.name).read_bytes()))
        self.assertTrue((reflected / "target-portraiton-bar-health-status.blp").exists())
        self.assertTrue((reflected / "target-portraiton-bar-mana.blp").exists())

    def test_fixed_power_fills_preserve_gradient_and_reflected_alpha(self):
        bars = GENERATOR.ASSETS / "bars"
        fixed = bars / "mirrored-fixed"
        self.assertEqual(len(list(fixed.glob("*.blp"))), 5)
        for power in GENERATOR.FIXED_POWER_TYPES:
            filename = f"target-portraiton-bar-{power}.blp"
            source = (bars / filename).read_bytes()
            output = (fixed / filename).read_bytes()
            reflected = (bars / "mirrored" / filename).read_bytes()
            width, height, offset = struct.unpack_from("<III", source, 12)
            self.assertEqual(output[:offset], source[:offset])
            self.assertEqual(output[offset + 3::4], reflected[offset + 3::4])
            for y in range(height):
                row = offset + y * width * 4
                original_colors = [source[i:i + 3] for i in range(row, row + width * 4, 4) if source[i + 3]]
                fixed_colors = [output[i:i + 3] for i in range(row, row + width * 4, 4) if output[i + 3]]
                self.assertEqual(fixed_colors, original_colors, (power, y))

    def test_generation_is_reproducible(self):
        original = GENERATOR.OUTPUT.read_bytes()
        try:
            GENERATOR.generate()
            self.assertEqual(GENERATOR.OUTPUT.read_bytes(), original)
        finally:
            GENERATOR.OUTPUT.write_bytes(original)

    def test_standalone_bars_contain_only_old_region_pixels(self):
        expected = set()
        for name, row in GENERATOR.entries().items():
            relative = GENERATOR.bar_asset(name)
            if not relative:
                continue
            path = GENERATOR.ASSETS / relative
            expected.add(path)
            source = (GENERATOR.ASSETS / Path(row["textureFilename"]).name).read_bytes()
            output = path.read_bytes()
            source_width = struct.unpack_from("<I", source, 12)[0]
            source_offset = struct.unpack_from("<I", source, 20)[0]
            width, height = struct.unpack_from("<II", output, 12)
            offset = struct.unpack_from("<I", output, 20)[0]
            self.assertEqual(width & (width - 1), 0)
            self.assertEqual(height & (height - 1), 0)
            self.assertEqual(len(output) - offset, width * height * 4)
            member = row["member"]
            pixels = set()
            for y in range(member["CommittedTop"], member["CommittedBottom"]):
                for x in range(member["CommittedLeft"], member["CommittedRight"]):
                    start = source_offset + (y * source_width + x) * 4
                    pixels.add(source[start:start + 4])
            rendered = {output[i:i + 4] for i in range(offset, len(output), 4)}
            self.assertTrue(rendered <= pixels, name)
        self.assertEqual(set((GENERATOR.ASSETS / "bars").glob("*.blp")), expected)


if __name__ == "__main__":
    unittest.main()
