"""CLI: python -m tools.ui_restore <validate|slice|build-godot|compare>."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops

def read_spec(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def validate(spec, base):
    assert spec["schema_version"] == 1, "Unsupported schema"
    assert len(spec["design_size"]) == 2 and all(x > 0 for x in spec["design_size"])
    seen = set()
    source = Image.open(base / spec["source_image"]).convert("RGBA")
    assert list(source.size) == spec["design_size"], "Reference dimensions differ"
    for asset in spec["assets"]:
        assert asset["id"] not in seen, "Duplicate asset id"
        seen.add(asset["id"])
        x,y,w,h = asset["source_rect"]
        assert all(isinstance(v,int) for v in (x,y,w,h))
        assert x>=0 and y>=0 and w>0 and h>0 and x+w<=source.width and y+h<=source.height
        if asset["type"]=="nine_slice":
            s=asset["nine_slice"]
            assert min(s[k] for k in ("left","top","right","bottom"))>=0
            assert s["left"]+s["right"]<w and s["top"]+s["bottom"]<h
    return source

def slice_assets(spec, base, output):
    source=validate(spec,base)
    output.mkdir(parents=True,exist_ok=True)
    manifest={"schema_version":1,"assets":[]}
    for a in spec["assets"]:
        x,y,w,h=a["source_rect"]
        cropped=source.crop((x,y,x+w,y+h))
        # A flattened screenshot cannot recover alpha or occluded pixels.
        if a.get("requires_source_layer",False):
            raise ValueError("Source layer required for "+a["id"])
        dest=output / a["file"]
        assert dest.resolve().is_relative_to(output.resolve()),"Invalid output path"
        cropped.save(dest)
        manifest["assets"].append({"id":a["id"],"file":a["file"],"sha256":hashlib.sha256(dest.read_bytes()).hexdigest(),"size":[w,h]})
    (output/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    return manifest

def build_godot(spec, output, resource_prefix="res://ui_restore/assets"):
    validate_nine = [a for a in spec["assets"] if a["type"]=="nine_slice"]
    output.mkdir(parents=True,exist_ok=True)
    for a in validate_nine:
        s=a["nine_slice"]
        margin=a.get("content_margin",{"left":16,"top":14,"right":16,"bottom":14})
        lines=['[gd_resource type="StyleBoxTexture" load_steps=2 format=3]',
               '[ext_resource type="Texture2D" path="'+resource_prefix.rstrip("/")+'/'+a["file"]+'" id="1"]',
               '[resource]','texture = ExtResource("1")']
        for side in ("left","top","right","bottom"):
            lines.append("texture_margin_"+side+" = "+str(s[side])+".0")
            lines.append("content_margin_"+side+" = "+str(margin[side])+".0")
        lines.append("draw_center = "+str(s.get("center_draw",True)).lower())
        (output/(a["id"]+".tres")).write_text("\n".join(lines)+"\n",encoding="utf-8")

def compare(reference, actual, roi, output, threshold=8):
    ref=Image.open(reference).convert("RGBA")
    got=Image.open(actual).convert("RGBA")
    if ref.size!=got.size: raise ValueError("Canvas sizes differ")
    x,y,w,h=roi
    if x<0 or y<0 or w<=0 or h<=0 or x+w>ref.width or y+h>ref.height: raise ValueError("Invalid ROI")
    r=ref.crop((x,y,x+w,y+h)).convert("RGB")
    g=got.crop((x,y,x+w,y+h)).convert("RGB")
    dif=ImageChops.difference(r,g)
    values=list(dif.getdata())
    mae=sum(sum(p) for p in values)/(3*len(values))
    ratio=sum(max(p)>threshold for p in values)/len(values)
    output.mkdir(parents=True,exist_ok=True)
    dif.save(output/"diff.png")
    report={"roi":roi,"mae":round(mae,4),"diff_ratio":round(ratio,6),
            "threshold":threshold,"status":"pass" if mae<=3 and ratio<=0.01 else "fail"}
    (output/"metrics.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    return report

def main():
    p=argparse.ArgumentParser()
    sub=p.add_subparsers(dest="command",required=True)
    for name in ("validate","slice","build-godot"):
        sp=sub.add_parser(name);sp.add_argument("spec");sp.add_argument("--base",default=".")
        sp.add_argument("--out",default="build/ui-restore")
    cp=sub.add_parser("compare");cp.add_argument("reference");cp.add_argument("actual")
    cp.add_argument("--roi",type=int,nargs=4,required=True);cp.add_argument("--out",default="build/ui-restore")
    args=p.parse_args()
    if args.command=="compare":
        result=compare(args.reference,args.actual,args.roi,Path(args.out))
        print(json.dumps(result));raise SystemExit(0 if result["status"]=="pass" else 1)
    spec=read_spec(args.spec)
    base=Path(args.base);out=Path(args.out)
    if args.command=="validate":validate(spec,base);print("valid")
    elif args.command=="slice":print(json.dumps(slice_assets(spec,base,out)))
    elif args.command=="build-godot":build_godot(spec,out);print("generated")

if __name__=="__main__":main()
