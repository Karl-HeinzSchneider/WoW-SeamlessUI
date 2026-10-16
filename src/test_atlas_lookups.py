"""Regression checks for nontrivial join and coordinate semantics."""

import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "atlas", Path(__file__).with_name("generate-atlas-lookups.py")
)
atlas = importlib.util.module_from_spec(spec)
spec.loader.exec_module(atlas)


class JoinTests(unittest.TestCase):
    def setUp(self):
        self.sheets = [dict(ID=10, FileDataID=123, AtlasWidth=256, AtlasHeight=128)]
        self.elements = [dict(ID=20, Name="Example"), dict(ID=21, Name="Unused")]
        self.member = dict(
            ID=30, UiTextureAtlasID=10, UiTextureAtlasElementID=20,
            CommittedName="example", CommittedLeft=32, CommittedRight=96,
            CommittedTop=16, CommittedBottom=48, Width=64, Height=32,
            OverrideWidth=100, OverrideHeight=0, CommittedFlags=6, UiCanvasID=0,
        )

    def test_variants_orphans_coordinates_and_overrides(self):
        second = dict(self.member, ID=31, CommittedFlags=30)
        joined = atlas.join(self.sheets, self.elements, [self.member, second], {123: "test.blp"})
        self.assertEqual(joined["Unused"], [])
        self.assertEqual(len(joined["Example"]), 2)
        first, second = joined["Example"]
        self.assertEqual(first["textureFilename"], "test.blp")
        self.assertEqual([first[k] for k in (
            "leftTexCoord", "rightTexCoord", "topTexCoord", "bottomTexCoord"
        )], [0.125, 0.375, 0.125, 0.375])
        self.assertEqual(first["regionWidth"], 64)
        self.assertEqual(first["member"]["OverrideWidth"], 100)
        self.assertTrue(first["tilesHorizontally"])
        self.assertTrue(first["tilesVertically"])
        self.assertFalse(second["tilesHorizontally"])
        self.assertFalse(second["tilesVertically"])
        self.assertEqual(second["uninterpretedFlags"], 8)
        self.assertEqual(first["issues"], [])

    def test_anomalies_are_preserved_and_broken_joins_fail(self):
        member = dict(self.member, CommittedRight=300, Width=63)
        result = atlas.join(self.sheets, self.elements, [member], {})["Example"][0]
        self.assertIsNone(result["textureFilename"])
        self.assertGreater(result["rightTexCoord"], 1)
        self.assertIn("invalid_or_out_of_bounds_rectangle", result["issues"])
        self.assertIn("source_size_differs_from_rectangle", result["issues"])
        with self.assertRaises(KeyError):
            atlas.join(self.sheets, self.elements, [dict(member, UiTextureAtlasID=999)], {})
        with self.assertRaises(ValueError):
            atlas.join(self.sheets, self.elements, [member, member], {})


if __name__ == "__main__":
    unittest.main()
