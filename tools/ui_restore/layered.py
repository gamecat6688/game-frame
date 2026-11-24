"""Deterministic raster-layer export; no inferred content or editable text."""

import io
from pathlib import Path
import struct
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image

Layer = tuple[str, tuple[int, int], Image.Image]
_CHANNELS = ((0, "R"), (1, "G"), (2, "B"), (-1, "A"))


def export_layers(
    design_size: tuple[int, int], layers: list[Layer], output: Path
) -> None:
    """Write independent RGBA raster layers (input order: bottom to top)."""
    width, height = design_size
    if any(type(value) is not int or value <= 0 for value in design_size):
        raise ValueError("Layer export requires a positive integer canvas size")
    suffix = output.suffix.lower()
    if suffix not in {".ora", ".psd"}:
        raise ValueError("Layer export output must end in .ora or .psd")
    if not layers:
        raise ValueError("Layer export requires at least one raster layer")
    if suffix == ".psd" and (max(design_size) > 30000 or len(layers) > 32767):
        raise ValueError("Canvas or layer count exceeds the PSD (version 1) limits")
    for name, (x, y), image in layers:
        if not name or any(
            not (0x20 <= ord(c) <= 0xD7FF or 0xE000 <= ord(c) <= 0xFFFD or
                 0x10000 <= ord(c) <= 0x10FFFF)
            for c in name
        ):
            raise ValueError("Layer names cannot be empty or contain invalid characters")
        if (
            type(x) is not int or type(y) is not int or x < 0 or y < 0
            or image.width <= 0 or image.height <= 0 or image.mode != "RGBA"
            or x + image.width > width or y + image.height > height
        ):
            raise ValueError(f"Layer {name!r} must be RGBA and fit the canvas at its offset")
    merged = Image.new("RGBA", (width, height))
    for _, offset, image in layers:
        merged.alpha_composite(image, dest=offset)
    output.parent.mkdir(parents=True, exist_ok=True)
    if suffix == ".ora":
        _write_ora(output, merged, layers)
    else:
        _write_psd(output, merged, layers)


def _png(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _write_ora(output: Path, merged: Image.Image, layers: list[Layer]) -> None:
    # https://www.openraster.org/baseline/layer-stack-spec.html
    # The ZIP entries use a fixed DOS time (ZipInfo default) for reproducibility.
    root = ET.Element("image", {
        "version": "0.0.3", "w": str(merged.width), "h": str(merged.height),
    })
    stack = ET.SubElement(root, "stack")
    with zipfile.ZipFile(output, "w") as archive:
        archive.writestr(zipfile.ZipInfo("mimetype"), b"image/openraster")
        for index, (name, (x, y), image) in enumerate(reversed(layers)):
            source = f"data/layer{index:04d}.png"
            ET.SubElement(stack, "layer", {
                "name": name, "x": str(x), "y": str(y), "src": source,
                "opacity": "1.0", "visibility": "visible", "composite-op": "svg:src-over",
            })
            archive.writestr(zipfile.ZipInfo(source), _png(image))
        archive.writestr(
            zipfile.ZipInfo("stack.xml"), ET.tostring(root, encoding="utf-8", xml_declaration=True)
        )
        archive.writestr(zipfile.ZipInfo("mergedimage.png"), _png(merged))
        thumbnail = merged.copy()
        thumbnail.thumbnail((256, 256), Image.Resampling.LANCZOS)
        archive.writestr(zipfile.ZipInfo("Thumbnails/thumbnail.png"), _png(thumbnail))


def _pack(fmt: str, *values: object) -> bytes:
    return struct.pack(">" + fmt, *values)


def _psd_layer_record(name: str, offset: tuple[int, int], image: Image.Image) -> bytes:
    x, y = offset
    # PSD Pascal byte name, padded to a multiple of four, plus its Unicode counterpart.
    encoded = name.encode("mac_roman", errors="replace")[:255]
    pascal = bytes([len(encoded)]) + encoded
    pascal += b"\0" * (-len(pascal) % 4)
    utf16 = name.encode("utf-16-be")
    unicode_name = _pack("I", len(utf16) // 2) + utf16
    extra = (
        b"\0" * 8 + pascal + b"8BIMluni" + _pack("I", len(unicode_name)) + unicode_name
    )
    channel_length = 2 + image.width * image.height
    return (
        _pack("iiiiH", y, x, y + image.height, x + image.width, len(_CHANNELS))
        + b"".join(_pack("hI", channel, channel_length) for channel, _ in _CHANNELS)
        + b"8BIMnorm" + _pack("BBBBI", 255, 0, 0, 0, len(extra)) + extra
    )


def _write_psd(output: Path, merged: Image.Image, layers: list[Layer]) -> None:
    # https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
    # PSD stores the editable layer records bottom-to-top. Each has raw 8-bit planar channels.
    records = [_psd_layer_record(name, offset, image) for name, offset, image in layers]
    layer_length = 2 + sum(map(len, records)) + sum(
        len(_CHANNELS) * (2 + image.width * image.height) for _, _, image in layers
    )
    padding = -layer_length % 2
    padded_length = layer_length + padding
    mask_section_length = 4 + padded_length + 4
    if mask_section_length > 0xFFFFFFFF:
        raise ValueError("Layer data exceeds the PSD (version 1) section size limit")
    with output.open("wb") as fp:
        fp.write(_pack("4sH6xHIIHH", b"8BPS", 1, 4, merged.height, merged.width, 8, 3))
        fp.write(_pack("IIIIh", 0, 0, mask_section_length, padded_length, -len(layers)))
        for record in records:
            fp.write(record)
        for _, _, image in layers:
            for _, channel in _CHANNELS:
                fp.write(b"\0\0")  # Compression = raw
                fp.write(image.getchannel(channel).tobytes())
        fp.write(b"\0" * padding)
        fp.write(b"\0" * 4)  # No global layer mask.
        # The compatibility composite uses Photoshop's white matte + alpha convention.
        # Any rounding in that preview does not affect the original editable RGBA channels.
        fp.write(b"\0\0")
        preview = Image.new("RGB", merged.size, "white")
        alpha = merged.getchannel("A")
        preview.paste(merged, mask=alpha)
        for _, channel in _CHANNELS[:-1]:
            fp.write(preview.getchannel(channel).tobytes())
        fp.write(alpha.tobytes())
