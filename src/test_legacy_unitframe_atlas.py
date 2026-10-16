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
