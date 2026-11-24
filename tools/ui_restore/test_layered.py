"""Round-trip tests for positioned RGBA raster layers."""

import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image

from tools.ui_restore.layered import export_layers


class LayeredExportTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.output = Path(temp.name)
        self.size = (19, 21)
        bottom = Image.new("RGBA", (7, 5), (180, 24, 6, 255))
        top = Image.new("RGBA", (5, 7), (16, 48, 204, 128))
        top.putpixel((1, 0), (9, 87, 65, 0))
        self.layers = [
            ("Bottom", (3, 7), bottom),
            ("Top 星🚀 &", (5, 9), top),
        ]

    def test_ora_layer_order_and_pixel_coordinates(self):
        path = self.output / "layers.ora"
        export_layers(self.size, self.layers, path)
        with zipfile.ZipFile(path) as archive:
            first = archive.infolist()[0]
            self.assertEqual((first.filename, first.compress_type), ("mimetype", zipfile.ZIP_STORED))
            self.assertEqual(archive.read("mimetype"), b"image/openraster")
            root = ET.fromstring(archive.read("stack.xml"))
            self.assertEqual((root.get("w"), root.get("h")), ("19", "21"))
            nodes = root.findall("./stack/layer")
            self.assertEqual(len(nodes), 2)
            for node, (name, offset, image) in zip(nodes, reversed(self.layers), strict=True):
                self.assertEqual(node.get("name"), name)
                self.assertEqual((int(node.get("x")), int(node.get("y"))), offset)
                with Image.open(io.BytesIO(archive.read(node.get("src")))) as decoded:
                    self.assertEqual((decoded.mode, decoded.size), ("RGBA", image.size))
                    self.assertEqual(decoded.tobytes(), image.tobytes())
            with Image.open(io.BytesIO(archive.read("mergedimage.png"))) as merged:
                self.assertEqual(merged.getpixel((5, 9)), (98, 36, 105, 255))
                self.assertEqual(merged.getpixel((6, 9)), (180, 24, 6, 255))
                self.assertEqual(merged.getpixel((9, 13)), (16, 48, 204, 128))
                self.assertEqual(merged.getpixel((0, 0)), (0, 0, 0, 0))
            self.assertIn("Thumbnails/thumbnail.png", archive.namelist())

    def test_psd_raw_editable_layers(self):
        path = self.output / "layers.psd"
        export_layers(self.size, self.layers, path)
        fp = io.BytesIO(path.read_bytes())

        def read(fmt):
            fmt = ">" + fmt
            return struct.unpack(fmt, fp.read(struct.calcsize(fmt)))

        self.assertEqual(read("4sH6xHIIHH"), (b"8BPS", 1, 4, 21, 19, 8, 3))
        for _ in range(2):  # Color-mode and image-resource sections.
            length, = read("I")
            fp.seek(length, io.SEEK_CUR)
        mask_length, info_length, layer_count = read("IIh")
        layer_end = fp.tell() - 2 + info_length
        self.assertEqual(mask_length, info_length + 8)
        self.assertEqual(layer_count, -2)
        headers = []
        for name, (x, y), image in self.layers:
            self.assertEqual(read("iiiiH"), (y, x, y + image.height, x + image.width, 4))
            headers.append([read("hI") for _ in range(4)])
            self.assertEqual(read("4s4sBBBB"), (b"8BIM", b"norm", 255, 0, 0, 0))
            extra_length, = read("I")
            extra = fp.read(extra_length)
            idx = extra.index(b"8BIMluni") + 8
            unicode_size, chars = struct.unpack_from(">II", extra, idx)
            self.assertEqual(unicode_size, chars * 2 + 4)
            self.assertEqual(extra[idx + 8:].decode("utf-16-be"), name)
        for (_, _, image), channels in zip(self.layers, headers, strict=True):
            self.assertEqual({channel_id for channel_id, _ in channels}, {-1, 0, 1, 2})
            for channel_id, length in channels:
                self.assertEqual(read("H"), (0,))
                self.assertEqual(fp.read(length - 2), image.getchannel(channel_id % 4).tobytes())
        fp.seek(layer_end)
        self.assertEqual(read("I"), (0,))
        self.assertEqual(read("H"), (0,))
        planes = [fp.read(19 * 21) for _ in range(4)]
        self.assertEqual(planes[3][0], 0)
        self.assertEqual(planes[3][9 * 19 + 5], 255)
        self.assertEqual(planes[3][13 * 19 + 9], 128)
        self.assertEqual(fp.read(), b"")

    @unittest.skipUnless(importlib.util.find_spec("psd_tools"), "optional independent PSD reader")
    def test_psd_roundtrip_through_independent_reader(self):
        from psd_tools import PSDImage

        path = self.output / "layers.psd"
        export_layers(self.size, self.layers, path)
        doc = PSDImage.open(path)
        self.assertEqual(doc.size, self.size)
        self.assertEqual(len(doc), 2)
        for decoded, (name, (x, y), image) in zip(doc, self.layers, strict=True):
            self.assertEqual(decoded.name, name)
            self.assertEqual(decoded.bbox, (x, y, x + image.width, y + image.height))
            opened = decoded.topil(apply_icc=False)
            self.assertEqual(opened.mode, "RGBA")
            self.assertEqual(opened.tobytes(), image.tobytes())
        flattened = doc.topil(apply_icc=False)
        self.assertEqual(flattened.getpixel((0, 0))[3], 0)
        self.assertEqual(flattened.getpixel((5, 9)), (98, 36, 105, 255))
        self.assertEqual(flattened.getpixel((9, 13))[3], 128)

    def test_deterministic_and_invalid_offsets(self):
        for ext in (".ora", ".psd"):
            first, second = (self.output / (name + ext) for name in ("first", "second"))
            export_layers(self.size, self.layers, first)
            export_layers(self.size, self.layers, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with self.assertRaisesRegex(ValueError, "fit the canvas"):
                export_layers((7, 9), self.layers, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())


if __name__ == "__main__":
    unittest.main()
