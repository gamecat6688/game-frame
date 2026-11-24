"""Unit and CLI integration tests for the reusable restore pipeline."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image

from tools.ui_restore.__main__ import compare, export
from tools.ui_restore.assets import read_spec, slice_assets, validate
from tools.ui_restore.godot import build_godot


ROOT = Path(__file__).resolve().parents[2]


class RestoreTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.source = Image.new("RGBA", (32, 24), (100, 50, 20, 128))
        self.source.putpixel((2, 3), (11, 22, 33, 0))
        self.source.putpixel((21, 18), (66, 77, 88, 255))
        self.source.save(self.root / "ref.png")
        self.asset = {
            "id": "panel", "file": "nested/panel.png", "type": "nine_slice",
            "source_rect": [2, 3, 20, 16], "requires_transparency": True,
            "requires_source_layer": True, "pixel_size": [20, 16], "trimmed": False,
            "nine_slice": {"left": 4, "top": 4, "right": 4, "bottom": 4, "stretch_x": "tile_fit"},
            "content_margin": {"left": 5, "top": 4, "right": 5, "bottom": 4},
        }
        self.spec = {"schema_version": 1, "design_size": [32, 24], "source_image": "ref.png",
                     "source_kind": "isolated", "assets": [self.asset]}
        self.layout = {"schema_version": 1, "scene_name": "PanelPreview", "design_size": [32, 24],
                       "root": {"id": "panel", "name": "Panel", "node_type": "PanelContainer",
                                "layout_policy": "container", "rect": [2, 3, 20, 16], "background": "panel",
                                "children": [{"id": "label", "name": "Score", "node_type": "Label",
                                              "layout_policy": "container", "text_key": "SCORE"}]}}
        self.spec_path = self.root / "spec.json"
        self.layout_path = self.root / "layout.json"
        self.project = self.root / "client"
        self.project.mkdir()
        (self.project / "project.godot").write_text("config_version=5\n", encoding="ascii")
        self.assets = self.project / "ui/assets"
        self.scene = self.project / "ui/generated"

    def cli(self, *args, optimized=False):
        return subprocess.run([sys.executable, *(["-O"] if optimized else []),
                               "-m", "tools.ui_restore", *map(str, args)],
                              cwd=ROOT, text=True, capture_output=True, check=False)

    def test_crop_preserves_coordinates_size_and_all_rgba(self):
        entry = slice_assets(self.spec, self.root, self.assets)["assets"][0]
        with Image.open(self.assets / "nested/panel.png") as image:
            self.assertEqual(image.mode, "RGBA")
            self.assertEqual(image.size, (20, 16))
            self.assertEqual(image.tobytes(), self.source.crop((2, 3, 22, 19)).tobytes())
        self.assertEqual(entry["source_rect"], [2, 3, 20, 16])
        self.assertEqual(entry["origin"], [2, 3])
        self.assertEqual(entry["alpha_range"], [0, 255])
        self.assertFalse(entry["trimmed"])

    def test_schema_rejects_bad_geometry_and_non_integer_fields(self):
        for key, value in (("source_rect", [2, 3, 31, 16]), ("source_rect", [False, 3, 20, 16]),
                           ("pixel_size", [20, 15]), ("content_rect", [1, 1, 18, 14]),
                           ("trimmed", True), ("alpha", "premultiplied")):
            with self.subTest(key=key, value=value):
                old = self.asset.get(key)
                self.asset[key] = value
                with self.assertRaises(ValueError):
                    validate(self.spec, self.root)
                if old is None:
                    del self.asset[key]
                else:
                    self.asset[key] = old
        self.asset["nine_slice"]["left"] = 16
        with self.assertRaisesRegex(ValueError, "nonempty center"):
            validate(self.spec, self.root)

    def test_rejects_flattened_and_opaque_inputs_including_optimized_cli(self):
        self.spec["source_kind"] = "flattened"
        self.spec_path.write_text(json.dumps(self.spec), encoding="utf-8")
        got = self.cli("validate", self.spec_path, "--base", self.root, optimized=True)
        self.assertEqual(got.returncode, 2, got.stderr)
        self.assertIn("isolated source layer required", got.stderr)
        self.spec["source_kind"] = "isolated"
        self.source.convert("RGB").save(self.root / "ref.png")
        with self.assertRaisesRegex(ValueError, "must carry alpha"):
            validate(self.spec, self.root)
        Image.new("RGBA", self.source.size, (100, 50, 20, 255)).save(self.root / "ref.png")
        with self.assertRaisesRegex(ValueError, "no transparency"):
            validate(self.spec, self.root)

    def test_requires_separate_images_for_overlapping_isolated_layers(self):
        second = dict(self.asset, id="overlay", file="overlay.png", source_rect=[3, 4, 20, 16])
        self.spec["assets"].append(second)
        with self.assertRaisesRegex(ValueError, "overlaps"):
            slice_assets(self.spec, self.root, self.assets)
        self.assertFalse(self.assets.exists(), "invalid second asset must not write first output")
        second["source_image"] = "second.png"
        self.source.save(self.root / "second.png")
        export(self.spec, self.root, self.root / "layers.ora")
        with zipfile.ZipFile(self.root / "layers.ora") as archive:
            stack = ET.fromstring(archive.read("stack.xml"))
        self.assertEqual([(l.attrib["name"], l.attrib["x"], l.attrib["y"])
                          for l in stack.findall("stack/layer")],
                         [("overlay", "3", "4"), ("panel", "2", "3")])

    def test_invalid_filenames_and_duplicate_outputs_fail_before_writing(self):
        for bad in ("../panel.png", "C:/panel.png", "bad\\panel.png", "CON.png"):
            old = self.asset["file"]
            self.asset["file"] = bad
            with self.assertRaises(ValueError):
                validate(self.spec, self.root)
            self.asset["file"] = old
        copied = dict(self.asset)
        self.spec["assets"].append(copied)
        with self.assertRaisesRegex(ValueError, "duplicate asset id"):
            validate(self.spec, self.root)
        copied.update(id="other", file="NESTED/PANEL.PNG")
        with self.assertRaisesRegex(ValueError, "conflicting output file"):
            validate(self.spec, self.root)

    def test_source_cannot_be_overwritten_by_slice(self):
        self.asset["file"] = "ref.png"
        original = (self.root / "ref.png").read_bytes()
        with self.assertRaisesRegex(ValueError, "overwrite a source"):
            slice_assets(self.spec, self.root, self.root)
        self.assertEqual((self.root / "ref.png").read_bytes(), original)

    def test_build_serializes_positions_resources_and_container_labels(self):
        slice_assets(self.spec, self.root, self.assets)
        scene = build_godot(self.spec, self.layout, self.scene,
                            project=self.project, assets_dir=self.assets)
        text = scene.read_text(encoding="utf-8")
        self.assertIn('path="res://ui/generated/panel.tres"', text)
        self.assertIn('offset_left = 2.0\noffset_top = 3.0\noffset_right = 22.0\noffset_bottom = 19.0', text)
        self.assertIn('[node name="Score" type="Label" parent="Panel"]\nlayout_mode = 2\ntext = "SCORE"', text)
        style = (self.scene / "panel.tres").read_text(encoding="utf-8")
        self.assertIn('path="res://ui/assets/nested/panel.png"', style)
        self.assertIn("texture_margin_left = 4.0", style)
        self.assertIn("content_margin_left = 5.0", style)
        self.assertIn("axis_stretch_horizontal = 2", style)

    def test_texture_rect_uses_bitmap_resource_and_absolute_native_rect(self):
        self.asset.update(type="bitmap")
        for key in ("nine_slice", "content_margin"):
            del self.asset[key]
        self.layout["root"] = {"id": "bitmap", "node_type": "TextureRect", "layout_policy": "fixed",
                               "rect": [2, 3, 20, 16], "texture": "panel"}
        slice_assets(self.spec, self.root, self.assets)
        scene = build_godot(self.spec, self.layout, self.scene,
                            project=self.project, assets_dir=self.assets)
        self.assertIn('path="res://ui/assets/nested/panel.png"', scene.read_text(encoding="utf-8"))
        self.assertFalse((self.scene / "panel.tres").exists())

    def test_build_rejects_stale_png_and_fixed_offsets_under_container(self):
        slice_assets(self.spec, self.root, self.assets)
        self.layout["root"]["children"][0]["rect"] = [0, 0, 5, 5]
        with self.assertRaisesRegex(ValueError, "container children cannot set fixed"):
            build_godot(self.spec, self.layout, self.scene, project=self.project, assets_dir=self.assets)
        self.assertFalse(self.scene.exists())
        del self.layout["root"]["children"][0]["rect"]
        Image.new("RGBA", (20, 16), "green").save(self.assets / "nested/panel.png")
        with self.assertRaisesRegex(ValueError, "PNG checksum changed"):
            build_godot(self.spec, self.layout, self.scene, project=self.project, assets_dir=self.assets)
        self.assertFalse(self.scene.exists())

    def test_compare_localizes_alpha_only_changes_and_writes_artifacts(self):
        roi = [2, 3, 20, 16]
        output = self.root / "diff"
        actual = self.source.copy()
        actual.putpixel((0, 0), (255, 255, 255, 255))  # Outside ROI.
        actual.save(self.root / "actual.png")
        self.assertEqual(compare(self.root / "ref.png", self.root / "actual.png", roi,
                                 output, limit_mae=0, limit_ratio=0)["status"], "pass")
        actual.putpixel((2, 3), (11, 22, 33, 255))
        actual.save(self.root / "actual.png")
        result = compare(self.root / "ref.png", self.root / "actual.png", roi,
                         output, limit_mae=0, limit_ratio=0)
        self.assertEqual(result["status"], "fail")
        self.assertEqual(result["changed_pixels"], 1)
        self.assertAlmostEqual(result["alpha_mae"], 255 / (20 * 16))
        self.assertEqual(read_spec(output / "metrics.json"), result)
        with Image.open(output / "diff.png") as diff:
            self.assertEqual(diff.size, (20, 16))
            self.assertEqual(diff.getpixel((0, 0)), (255, 0, 255))

    def test_currency_cli_reproduces_shipped_assets_and_exports_both_formats(self):
        specs = ROOT / "tools/ui_restore/specs"
        spec, layout = specs / "currencies.slices.json", specs / "currencies.layout.json"
        source = ROOT / "tools/ui_restore/sample"
        rel = Path("ui/components/currencies_restore")
        output = self.project / rel
        (self.project / "ui").mkdir()
        (self.project / "ui/theme.tres").write_bytes((ROOT / "client/ui/theme.tres").read_bytes())
        for args in (("validate", spec, "--base", source),
                     ("slice", spec, "--base", source, "--out", output),
                     ("build-godot", spec, "--layout", layout, "--project", self.project,
                      "--assets", output, "--out", output),
                     ("export-layers", spec, "--base", source, "--out", self.root / "panel.ora"),
                     ("export-layers", spec, "--base", source, "--out", self.root / "panel.psd")):
            got = self.cli(*args)
            self.assertEqual(got.returncode, 0, got.stderr)
        for name in ("panel_currency_bg.tres", "CurrenciesPreview.tscn"):
            expected = (ROOT / "client" / rel / name).read_text(encoding="utf-8")
            self.assertEqual((output / name).read_text(encoding="utf-8"), expected)
        # Pillow/zlib versions can alter PNG bytes while preserving all RGBA pixels.
        with Image.open(output / "panel_currency_bg.png") as actual, Image.open(
            ROOT / "client" / rel / "panel_currency_bg.png"
        ) as expected:
            self.assertEqual(actual.tobytes(), expected.tobytes())
        self.assertEqual((self.root / "panel.psd").read_bytes()[:4], b"8BPS")
        self.assertTrue(zipfile.is_zipfile(self.root / "panel.ora"))


if __name__ == "__main__":
    unittest.main()
