import json
import tempfile
import unittest
from pathlib import Path
from PIL import Image
from tools.ui_restore.__main__ import validate, slice_assets, build_godot, compare

class RestoreTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        Image.new("RGBA",(32,24),(100,50,20,128)).save(self.root/"ref.png")
        self.spec={"schema_version":1,"design_size":[32,24],"source_image":"ref.png",
                   "assets":[{"id":"panel","file":"panel.png","type":"nine_slice",
                              "source_rect":[2,3,20,16],
                              "nine_slice":{"left":4,"top":4,"right":4,"bottom":4}}]}
    def test_crop_preserves_rgba(self):
        manifest=slice_assets(self.spec,self.root,self.root/"out")
        image=Image.open(self.root/"out/panel.png")
        self.assertEqual(image.mode,"RGBA")
        self.assertEqual(image.size,(20,16))
        self.assertEqual(image.getpixel((0,0)),(100,50,20,128))
        self.assertEqual(len(manifest["assets"]),1)
    def test_invalid_slice(self):
        self.spec["assets"][0]["nine_slice"]["left"]=30
        with self.assertRaises(AssertionError):validate(self.spec,self.root)
    def test_duplicate(self):
        self.spec["assets"].append(dict(self.spec["assets"][0]))
        with self.assertRaises(AssertionError):validate(self.spec,self.root)
    def test_stylebox(self):
        build_godot(self.spec,self.root/"styles")
        data=(self.root/"styles/panel.tres").read_text()
        self.assertIn("texture_margin_left = 4.0",data)
        self.assertIn("content_margin_left = 16.0",data)
    def test_compare(self):
        result=compare(self.root/"ref.png",self.root/"ref.png",[2,3,20,16],self.root/"diff")
        self.assertEqual(result["status"],"pass")
    def test_compare_failure(self):
        Image.new("RGBA",(32,24),(0,0,0,255)).save(self.root/"bad.png")
        result=compare(self.root/"ref.png",self.root/"bad.png",[2,3,20,16],self.root/"diff")
        self.assertEqual(result["status"],"fail")

if __name__=="__main__":unittest.main()
