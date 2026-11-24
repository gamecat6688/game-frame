"""Render the game's currency panel and compare against its pre-texture style.

Run after Godot has imported the client, e.g. tools/build.ps1. Run with a
graphics display (the Godot headless Dummy renderer cannot provide pixels).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from PIL import Image

from tools.ui_restore.__main__ import compare

ROOT = Path(__file__).resolve().parents[2]
CASES = ([720, 1120], [600, 1120])


def save_roi(source: Path, roi: list[int], destination: Path) -> None:
    x, y, width, height = roi
    with Image.open(source) as image:
        image.crop((x, y, x + width, y + height)).save(destination, format="PNG")


def verify(godot: str, output: Path, timeout: float) -> bool:
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".capture-", dir=output) as work:
        capture = Path(work)
        log = output / "godot.log"
        try:
            result = subprocess.run(
                [godot, "--path", str(ROOT / "client"), "--audio-driver", "Dummy",
                 "--resolution", "480x640", "--script", "res://tests/ui_restore_capture.gd",
                 "--", str(capture)],
                cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace",
                timeout=timeout, check=False,
            )
        except subprocess.TimeoutExpired as exc:
            partial = (exc.stdout or b"") + (exc.stderr or b"")
            log.write_bytes(partial)
            raise RuntimeError(f"Godot capture timed out after {timeout:g}s; see {log}") from exc
        log.write_text(result.stdout + result.stderr, encoding="utf-8")
        if result.returncode or "ERROR:" in result.stdout + result.stderr:
            raise RuntimeError(f"Godot capture failed; see {log}")

        report = json.loads((capture / "capture.json").read_text(encoding="utf-8"))
        cases = report["cases"]
        if [case["viewport"] for case in cases] != list(CASES):
            raise RuntimeError("Godot did not return both expected viewport captures")
        ok = True
        for index, case in enumerate(cases):
            width, _ = case["viewport"]
            reference = capture / f"reference-{width}.png"
            actual = capture / f"actual-{width}.png"
            destination = output if index == 0 else output / f"width-{width}"
            result = compare(reference, actual, case["roi"], destination)
            ok = result["status"] == "pass" and ok
            case["comparison"] = result
            if index == 0:
                save_roi(reference, case["roi"], destination / "reference-roi.png")
                save_roi(actual, case["roi"], destination / "actual-roi.png")
            reference.replace(destination / "reference.png")
            actual.replace(destination / "actual.png")
        preview = output / "preview"
        preview_metrics = compare(
            output / "actual.png", capture / "preview-720.png", cases[0]["roi"],
            preview, threshold=0, limit_mae=0, limit_ratio=0,
        )
        (capture / "preview-720.png").replace(preview / "actual.png")
        report["preview_comparison"] = preview_metrics
        ok = preview_metrics["status"] == "pass" and ok
        report["status"] = "pass" if ok else "fail"
        (output / "capture.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.7.x console executable")
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "ui-restore" / "godot")
    parser.add_argument("--timeout", type=float, default=90)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    try:
        passed = verify(args.godot, args.out, args.timeout)
    except (RuntimeError, OSError, ValueError, KeyError) as exc:
        parser.exit(2, f"{exc}\n")
    print(f"Currency appearance comparison: {'pass' if passed else 'fail'} ({args.out})")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
