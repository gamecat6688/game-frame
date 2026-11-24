"""Deterministic RGBA slicing, Godot layout compilation, and visual comparison."""

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageChops

from .assets import load_crops, read_spec, rect, require, slice_assets, validate, write_json
from .godot import build_godot
from .layered import export_layers


def export(spec, base, output):
    size, crops = load_crops(spec, base)
    require(all(meta["source_kind"] == "isolated" for _, _, meta in crops),
            "Layered export needs isolated PNG inputs; a flattened screenshot cannot supply editable layers")
    export_layers(size, [(a["id"], tuple(meta["origin"]), image) for a, image, meta in crops], Path(output))


def compare(reference, actual, roi, output, threshold=8, *, limit_mae=3, limit_ratio=0.01):
    require(type(threshold) is int and 0 <= threshold <= 255,
            "threshold must be an integer from 0 to 255")
    require(math.isfinite(limit_mae) and 0 <= limit_mae <= 255
            and math.isfinite(limit_ratio) and 0 <= limit_ratio <= 1,
            "limit-mae must be 0..255 and limit-ratio must be 0..1")
    with Image.open(reference) as ref_input, Image.open(actual) as actual_input:
        require(ref_input.size == actual_input.size,
                f"Canvas sizes differ: {ref_input.size} vs {actual_input.size}")
        size = ref_input.size
        x, y, w, h = rect(roi, size, "ROI")
        box = (x, y, x + w, y + h)
        delta = ImageChops.difference(ref_input.convert("RGBA").crop(box),
                                     actual_input.convert("RGBA").crop(box))
    channels = delta.split()
    pixel_max = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]),
                                  ImageChops.lighter(channels[2], channels[3]))
    n = w * h
    pixel_histogram = pixel_max.histogram()
    channel_mae = [sum(value * count for value, count in enumerate(c.histogram())) / n for c in channels]
    mae = sum(channel_mae) / 4
    pixels = sum(pixel_histogram[threshold + 1:])
    ratio = pixels / n
    # Put alpha error into red and blue so it remains visible in an opaque diff PNG.
    heat = Image.merge("RGB", (ImageChops.lighter(channels[0], channels[3]), channels[1],
                               ImageChops.lighter(channels[2], channels[3])))
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    heat.save(output / "diff.png", format="PNG")
    report = {
        "canvas_size": list(size), "roi": [x, y, w, h], "channels": "RGBA",
        "pixel_count": n, "changed_pixels": n - pixel_histogram[0],
        "pixels_above_threshold": pixels, "max_channel_delta": pixel_max.getextrema()[1],
        "mae": round(mae, 8), "alpha_mae": round(channel_mae[3], 8), "diff_ratio": round(ratio, 8),
        "threshold": threshold, "limits": {"mae": limit_mae, "diff_ratio": limit_ratio},
        "status": "pass" if mae <= limit_mae and ratio <= limit_ratio else "fail",
    }
    write_json(output / "metrics.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "slice", "export-layers"):
        sub = commands.add_parser(name)
        sub.add_argument("spec", type=Path)
        sub.add_argument("--base", type=Path, default=Path("."))
        if name != "validate":
            sub.add_argument("--out", type=Path, required=True)
    build = commands.add_parser("build-godot")
    build.add_argument("spec", type=Path)
    build.add_argument("--layout", type=Path, required=True)
    build.add_argument("--project", type=Path, default=Path("client"))
    build.add_argument("--assets", type=Path, required=True)
    build.add_argument("--out", type=Path, required=True)
    cmp = commands.add_parser("compare")
    cmp.add_argument("reference", type=Path)
    cmp.add_argument("actual", type=Path)
    cmp.add_argument("--roi", type=int, nargs=4, required=True, metavar=("X", "Y", "W", "H"))
    cmp.add_argument("--threshold", type=int, default=8)
    cmp.add_argument("--limit-mae", type=float, default=3)
    cmp.add_argument("--limit-ratio", type=float, default=0.01)
    cmp.add_argument("--out", type=Path, default=Path("build/ui-restore"))
    args = parser.parse_args()
    try:
        if args.command == "compare":
            report = compare(args.reference, args.actual, args.roi, args.out, args.threshold,
                             limit_mae=args.limit_mae, limit_ratio=args.limit_ratio)
            print(json.dumps(report))
            return 0 if report["status"] == "pass" else 1
        spec = read_spec(args.spec)
        if args.command == "validate":
            print(f"valid: {validate(spec, args.base)}")
        elif args.command == "slice":
            print(json.dumps(slice_assets(spec, args.base, args.out)))
        elif args.command == "export-layers":
            export(spec, args.base, args.out)
            print(args.out)
        else:
            print(build_godot(spec, read_spec(args.layout), args.out,
                              project=args.project, assets_dir=args.assets))
    except (OSError, ValueError, TypeError, KeyError, AttributeError, IndexError, Image.DecompressionBombError) as exc:
        parser.exit(2, f"ui-restore: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
