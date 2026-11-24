"""Compile a static layout and texture assets into Godot 4 resources."""

import json
from pathlib import Path
import re

from PIL import Image

from .assets import (ASSET_ID, SIDES, dimensions, read_spec, rect, require, safe_path,
                     schema, sha256, validate_spec)


NODES = {"PanelContainer", "Control", "HBoxContainer", "VBoxContainer", "Label", "TextureRect", "Button"}
CONTAINERS = {"PanelContainer", "HBoxContainer", "VBoxContainer"}
STYLABLE = {"PanelContainer": "panel", "Button": "normal"}
NODE_NAME = re.compile(r"[A-Za-z][A-Za-z0-9_]*\Z")
STRETCH = {"stretch": 0, "tile": 1, "tile_fit": 2}


def q(value):
    return json.dumps(value, ensure_ascii=False)


def write_text(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(("\n".join(lines).rstrip() + "\n").encode("utf-8"))


def godot_path(path, project):
    path = Path(path).resolve()
    require(path.is_relative_to(project), f"{path} is outside the Godot project")
    return "res://" + path.relative_to(project).as_posix()


def stylebox(asset, texture_path):
    s = asset["nine_slice"]
    margin = asset.get("content_margin", s)
    lines = ['[gd_resource type="StyleBoxTexture" load_steps=2 format=3]', "",
             f'[ext_resource type="Texture2D" path={q(texture_path)} id="1_texture"]',
             "", "[resource]", 'texture = ExtResource("1_texture")']
    for side in SIDES:
        lines += [f"texture_margin_{side} = {s[side]}.0", f"content_margin_{side} = {margin[side]}.0"]
    for key, axis in (("stretch_x", "horizontal"), ("stretch_y", "vertical")):
        lines.append(f"axis_stretch_{axis} = {STRETCH[s.get(key, 'stretch')]}")
    lines.append(f"draw_center = {str(s.get('center_draw', True)).lower()}")
    return lines


def check_asset_outputs(spec, size, assets_dir):
    manifest = read_spec(safe_path(assets_dir, "manifest.json", ".json", "manifest"))
    schema(manifest, "slice manifest")
    require(dimensions(manifest.get("design_size"), "manifest.design_size") == size,
            "slice spec and manifest design sizes differ")
    require(isinstance(manifest.get("assets"), list), "manifest.assets must be an array")
    require(len(manifest["assets"]) == len(spec["assets"]), "assets and manifest count differ")
    for a, item in zip(spec["assets"], manifest["assets"]):
        aid = a["id"]
        x, y, w, h = a["source_rect"]
        require(isinstance(item, dict) and all(item.get(k) == v for k, v in (
            ("id", aid), ("file", a["file"]), ("type", a["type"]), ("source_rect", [x, y, w, h]),
            ("size", [w, h]), ("origin", [x, y]), ("alpha", "straight"),
            ("source_image", a.get("source_image", spec.get("source_image"))),
            ("source_kind", a.get("source_kind", spec.get("source_kind", "flattened"))),
            ("content_rect", a.get("content_rect", [0, 0, w, h])),
        )) and item.get("trimmed") is False, f"{aid}: stale or mismatched slice manifest; rerun slice")
        texture = safe_path(assets_dir, a["file"], ".png", f"{aid}.file")
        require(texture.is_file(), f"{aid}: missing PNG: {texture}")
        require(sha256(texture) == item.get("sha256"), f"{aid}: PNG checksum changed; rerun slice")
        with Image.open(texture) as f:
            require(f.format == "PNG" and f.mode == "RGBA" and f.size == (w, h),
                    f"{aid}: PNG must be RGBA in original dimensions")
            alpha_min, alpha_max = f.getchannel("A").getextrema()
            require(alpha_max > 0 and (not a.get("requires_transparency") or alpha_min < 255),
                    f"{aid}: generated texture failed alpha validation")


def render_scene(layout, size, assets, asset_paths, style_paths, project):
    schema(layout, "layout")
    require(dimensions(layout.get("design_size"), "layout.design_size") == size,
            "layout and slice spec design sizes differ")
    name = layout.get("scene_name")
    require(isinstance(name, str) and NODE_NAME.fullmatch(name), "invalid layout.scene_name")
    root = layout.get("root")
    require(isinstance(root, dict), "layout.root must be an object")
    resources, body, ids, unique = {}, [], set(), set()

    def ext(kind, path):
        key = (kind, path)
        if key not in resources:
            resources[key] = f"{len(resources) + 1}_restore"
        return f'ExtResource("{resources[key]}")'

    def add_rect(bounds):
        x, y, w, h = bounds
        for side, val in zip(SIDES, (x, y, x + w, y + h)):
            body.append(f"offset_{side} = {val}.0")

    def visit(node, parent_type, parent_path, parent_size, siblings):
        require(isinstance(node, dict), "every layout node must be an object")
        nid = node.get("id")
        require(isinstance(nid, str) and ASSET_ID.fullmatch(nid) and nid not in ids,
                f"invalid or duplicate node id: {nid}")
        ids.add(nid)
        nname = node.get("name", node.get("existing_name", nid))
        require(isinstance(nname, str) and NODE_NAME.fullmatch(nname) and nname not in siblings,
                f"{nid}: invalid or duplicate node name")
        siblings.add(nname)
        ntype = node.get("node_type")
        require(ntype in NODES, f"{nid}: unsupported node_type {ntype}")
        policy = node.get("layout_policy")
        require(policy in ("fixed", "container"), f"{nid}: invalid layout_policy")
        container_child = parent_type in CONTAINERS
        if container_child:
            require(policy == "container" and "rect" not in node,
                    f"{nid}: container children cannot set fixed coordinates")
            bounds = None
        else:
            require(policy == "fixed" or node is root,
                    f"{nid}: only a container can lay out this node")
            bounds = rect(node.get("rect"), parent_size, f"{nid}.rect")
        body.append(f'[node name={q(nname)} type={q(ntype)} parent={q(parent_path)}]')
        body.append(f"layout_mode = {2 if container_child else 0}")
        if bounds:
            add_rect(bounds)
        if "unique_name" in node:
            require(type(node["unique_name"]) is bool, f"{nid}: unique_name must be boolean")
            if node["unique_name"]:
                require(nname not in unique, f"{nid}: duplicate unique name {nname}")
                unique.add(nname)
                body.append("unique_name_in_owner = true")
        if "background" in node:
            aid = node["background"]
            require(ntype in STYLABLE and isinstance(aid, str) and aid in style_paths,
                    f"{nid}: background requires a nine_slice for PanelContainer or Button")
            if bounds:
                s = assets[aid]["nine_slice"]
                margin = assets[aid].get("content_margin", s)
                require(bounds[2] > max(s["left"] + s["right"], margin["left"] + margin["right"])
                        and bounds[3] > max(s["top"] + s["bottom"], margin["top"] + margin["bottom"]),
                        f"{nid}: panel rectangle must fit margins and a nonempty center")
            resource = ext("StyleBox", style_paths[aid])
            body.append(f"theme_override_styles/{STYLABLE[ntype]} = {resource}")
        if "texture" in node:
            aid = node["texture"]
            require(ntype == "TextureRect" and isinstance(aid, str) and aid in asset_paths,
                    f"{nid}: texture requires TextureRect and a known asset")
            resource = ext("Texture2D", asset_paths[aid])
            body.extend([f"texture = {resource}", "expand_mode = 1", "mouse_filter = 2"])
        if "text_key" in node or "preview_text" in node:
            require(ntype in ("Label", "Button"), f"{nid}: only Labels/Buttons support text")
            require(not ("text_key" in node and "preview_text" in node), f"{nid}: choose one text source")
            value = node.get("text_key", node.get("preview_text"))
            require(isinstance(value, str), f"{nid}: text must be a string")
            body.append(f"text = {q(value)}")
            if "preview_text" in node:
                body.append("auto_translate_mode = 2")
        if "binding" in node:
            require(ntype == "Label" and isinstance(node["binding"], str) and node["binding"],
                    f"{nid}: binding is documentary, only supported for Label")
        if "font_size" in node:
            font = node["font_size"]
            require(ntype in ("Label", "Button") and type(font) is int and font > 0,
                    f"{nid}: invalid font_size")
            body.append(f"theme_override_font_sizes/font_size = {font}")
        if "font_color" in node:
            color = node["font_color"]
            require(ntype in ("Label", "Button") and isinstance(color, list) and len(color) == 4
                    and all(type(v) in (float, int) and 0 <= v <= 1 for v in color),
                    f"{nid}: font_color must be [r,g,b,a] in range 0..1")
            body.append("theme_override_colors/font_color = Color(" + ", ".join(map(str, color)) + ")")
        if "expand" in node:
            require(container_child and type(node["expand"]) is bool, f"{nid}: invalid expand flag")
            if node["expand"]:
                prop = "vertical" if parent_type == "VBoxContainer" else "horizontal"
                body.append(f"size_flags_{prop} = 3")
        children = node.get("children", [])
        require(isinstance(children, list) and (not children or ntype not in
                ("Label", "Button", "TextureRect")), f"{nid}: invalid children")
        require(ntype != "PanelContainer" or len(children) <= 1,
                f"{nid}: PanelContainer can wrap only one child")
        body.append("")
        this_path = nname if parent_path == "." else f"{parent_path}/{nname}"
        names = set()
        for child in children:
            visit(child, ntype, this_path, bounds[2:] if bounds else parent_size, names)

    body.extend([f'[node name={q(name)} type="Control"]', "layout_mode = 0",
                 f"offset_right = {size[0]}.0", f"offset_bottom = {size[1]}.0"])
    if "theme" in layout:
        theme = safe_path(project, layout["theme"], ".tres", "layout.theme")
        require(theme.is_file(), f"missing theme {theme}")
        body.append(f'theme = {ext("Theme", godot_path(theme, project))}')
    body.append("")
    visit(root, "Control", ".", size, set())
    header = [f'[gd_scene load_steps={len(resources) + 1} format=3]', ""]
    header.extend(f'[ext_resource type={q(kind)} path={q(path)} id={q(rid)}]'
                  for (kind, path), rid in resources.items())
    return header + [""] + body


def build_godot(spec, layout, output, *, project, assets_dir):
    size = validate_spec(spec)
    project = Path(project).resolve()
    require((project / "project.godot").is_file(), f"missing Godot project at {project}")
    output = Path(output).resolve()
    assets_dir = Path(assets_dir).resolve()
    godot_path(output, project)
    godot_path(assets_dir, project)
    check_asset_outputs(spec, size, assets_dir)
    assets = {a["id"]: a for a in spec["assets"]}
    asset_paths = {aid: godot_path(safe_path(assets_dir, a["file"], ".png", aid), project)
                   for aid, a in assets.items()}
    resources = {aid: safe_path(output, f"{aid}.tres", ".tres", aid)
                 for aid, a in assets.items() if a["type"] == "nine_slice"}
    style_paths = {aid: godot_path(path, project) for aid, path in resources.items()}
    scene = render_scene(layout, size, assets, asset_paths, style_paths, project)
    scene_path = safe_path(output, layout["scene_name"] + ".tscn", ".tscn", "scene")
    for aid, path in resources.items():
        write_text(path, stylebox(assets[aid], asset_paths[aid]))
    write_text(scene_path, scene)
    return scene_path
