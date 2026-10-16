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


if __name__ == "__main__":
    unittest.main()
