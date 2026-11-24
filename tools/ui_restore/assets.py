"""Validate locked PNG inputs and create in-place RGBA crops."""

import hashlib
import json
from pathlib import Path
import re

from PIL import Image


SIDES = ("left", "top", "right", "bottom")
ASSET_ID = re.compile(r"[a-z][a-z0-9_]*\Z")
FILE_PART = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]*\Z")
WINDOWS_DEVICES = {"CON", "PRN", "AUX", "NUL"} | {
    f"{kind}{i}" for kind in ("COM", "LPT") for i in range(1, 10)
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_spec(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def schema(data, name):
    require(isinstance(data, dict) and type(data.get("schema_version")) is int
            and data["schema_version"] == 1, f"{name}: schema_version must be 1")


def dimensions(value, label):
    require(isinstance(value, list) and len(value) == 2
            and all(type(v) is int and v > 0 for v in value),
            f"{label} must be [positive width, positive height]")
    return tuple(value)


def rect(value, size, label):
    require(isinstance(value, (tuple, list)) and len(value) == 4
            and all(type(v) is int for v in value), f"{label} must be [x, y, width, height]")
    x, y, w, h = value
    require(x >= 0 and y >= 0 and w > 0 and h > 0 and x + w <= size[0] and y + h <= size[1],
            f"{label} {list(value)} falls outside {list(size)}")
    return x, y, w, h


def safe_path(root, name, suffix, label):
    require(isinstance(name, str) and all(
        FILE_PART.fullmatch(part) and not part.endswith(".")
        and part.split(".")[0].upper() not in WINDOWS_DEVICES for part in name.split("/")
    ), f"{label}: use a portable relative path")
    require(name.lower().endswith(suffix), f"{label} must end in {suffix}")
    root = Path(root).resolve()
    result = root.joinpath(*name.split("/"))
    require(result.resolve().is_relative_to(root), f"{label}: path escapes its root")
    return result


def _margins(data, label):
    require(isinstance(data, dict) and all(type(data.get(s)) is int and data[s] >= 0
                                          for s in SIDES), f"{label}: expected four nonnegative integer margins")
    return tuple(data[s] for s in SIDES)


def validate_spec(spec):
    schema(spec, "slice spec")
    size = dimensions(spec.get("design_size"), "design_size")
    require(isinstance(spec.get("assets"), list) and spec["assets"], "assets must be a nonempty array")
    seen, files = set(), set()
    for a in spec["assets"]:
        require(isinstance(a, dict), "each asset must be an object")
        name = a.get("id")
        require(isinstance(name, str) and ASSET_ID.fullmatch(name), "asset id must be lower snake_case")
        require(name not in seen, f"duplicate asset id: {name}")
        seen.add(name)
        file = a.get("file")
        safe_path(Path.cwd(), file, ".png", f"{name}.file")
        folded = file.casefold()
        require(folded not in files and not any(
            f.startswith(folded + "/") or folded.startswith(f + "/") for f in files),
            f"conflicting output file: {file}")
        files.add(folded)
        _, _, w, h = rect(a.get("source_rect"), size, f"{name}.source_rect")
        if "pixel_size" in a:
            require(dimensions(a["pixel_size"], f"{name}.pixel_size") == (w, h),
                    f"{name}.pixel_size must match source_rect")
        if "content_rect" in a:
            rect(a["content_rect"], (w, h), f"{name}.content_rect")
        require(a.get("trimmed", False) is False, f"{name}: auto-trimming breaks in-place coordinates")
        require(a.get("alpha", "straight") == "straight", f"{name}: alpha must be straight")
        kind = a.get("source_kind", spec.get("source_kind", "flattened"))
        require(kind in ("flattened", "isolated"), f"{name}: invalid source_kind")
        for flag in ("requires_source_layer", "requires_transparency"):
            require(type(a.get(flag, False)) is bool, f"{name}.{flag} must be a boolean")
        require(not a.get("requires_source_layer") or kind == "isolated",
                f"{name}: isolated source layer required; cannot extract it from a flattened image")
        require(not a.get("requires_transparency") or kind == "isolated",
                f"{name}: transparency-dependent art requires an isolated source")
        safe_path(Path.cwd(), a.get("source_image", spec.get("source_image")), ".png", f"{name}.source_image")
        require(a.get("type") in ("bitmap", "nine_slice"), f"{name}: expected bitmap or nine_slice")
        if a["type"] == "nine_slice":
            s = a.get("nine_slice")
            l, t, r, b = _margins(s, f"{name}.nine_slice")
            require(l + r < w and t + b < h, f"{name}: nine-slice needs a nonempty center")
            require(type(s.get("center_draw", True)) is bool, f"{name}.center_draw must be a boolean")
            require(s.get("stretch_x", "stretch") in ("stretch", "tile", "tile_fit")
                    and s.get("stretch_y", "stretch") in ("stretch", "tile", "tile_fit"),
                    f"{name}: invalid nine-slice stretch mode")
            margins = a.get("content_margin", s)
            _margins(margins, f"{name}.content_margin")
        else:
            require("nine_slice" not in a and "content_margin" not in a,
                    f"{name}: bitmap cannot have nine-slice margins")
    return size


def load_crops(spec, base):
    size = validate_spec(spec)
    sources, used_rects, crops = {}, {}, []
    for a in spec["assets"]:
        name = a["id"]
        source_name = a.get("source_image", spec.get("source_image"))
        kind = a.get("source_kind", spec.get("source_kind", "flattened"))
        path = safe_path(base, source_name, ".png", f"{name}.source_image").resolve()
        if path not in sources:
            with Image.open(path) as source:
                require(source.format == "PNG" and getattr(source, "n_frames", 1) == 1,
                        f"{source_name}: expected a single PNG image")
                require(source.size == size, f"{source_name}: expected {size}, got {source.size}")
                # PNG uses straight alpha. Reject high-bit-depth input instead of silently
                # quantizing RGB or alpha to the output's 8 bits per channel.
                with path.open("rb") as header:
                    require(header.read(25)[24] <= 8, f"{source_name}: 16-bit PNG is unsupported")
                has_alpha = "A" in source.getbands() or "transparency" in source.info
                sources[path] = source.convert("RGBA"), has_alpha, sha256(path)
        source, has_alpha, source_sha = sources[path]
        require(kind != "isolated" or has_alpha, f"{source_name}: isolated source PNG must carry alpha")
        x, y, w, h = a["source_rect"]
        if kind == "isolated":
            for x2, y2, w2, h2, name2 in used_rects.get(path, []):
                require(x + w <= x2 or x2 + w2 <= x or y + h <= y2 or y2 + h2 <= y,
                        f"{name} overlaps {name2} on the same isolated sheet; supply separate layer PNGs")
            used_rects.setdefault(path, []).append((x, y, w, h, name))
        crop = source.crop((x, y, x + w, y + h))
        alpha = crop.getchannel("A")
        alpha_range = alpha.getextrema()
        bounds = alpha.getbbox()
        require(bounds is not None, f"{name}: crop has no visible pixels")
        require(not a.get("requires_transparency") or alpha_range[0] < 255,
                f"{name}: crop has no transparency")
        content = a.get("content_rect", [0, 0, w, h])
        cx, cy, cw, ch = content
        require(cx <= bounds[0] and cy <= bounds[1] and cx + cw >= bounds[2] and cy + ch >= bounds[3],
                f"{name}: content_rect clips visible pixels")
        crops.append((a, crop, {
            "id": name, "file": a["file"], "type": a["type"], "size": [w, h],
            "source_image": source_name, "source_sha256": source_sha, "source_kind": kind,
            "source_rect": [x, y, w, h], "origin": [x, y], "content_rect": content, "trimmed": False,
            "alpha": "straight", "alpha_range": list(alpha_range),
        }))
    return size, crops


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate(spec, base):
    return load_crops(spec, base)[0]


def slice_assets(spec, base, output):
    size, crops = load_crops(spec, base)
    output = Path(output)
    targets = [safe_path(output, a["file"], ".png", f"{a['id']}.file") for a, _, _ in crops]
    sources = {safe_path(base, meta["source_image"], ".png", "source").resolve() for _, _, meta in crops}
    require(not any(target.resolve() in sources for target in targets), "Slice would overwrite a source PNG")
    manifest_path = safe_path(output, "manifest.json", ".json", "manifest")
    manifest = {"schema_version": 1, "design_size": list(size), "assets": []}
    # Validate every crop and resolve every output before writing any files.
    for target, (_, crop, metadata) in zip(targets, crops):
        target.parent.mkdir(parents=True, exist_ok=True)
        crop.save(target, format="PNG", compress_level=9)
        metadata["sha256"] = sha256(target)
        manifest["assets"].append(metadata)
    write_json(manifest_path, manifest)
    return manifest
