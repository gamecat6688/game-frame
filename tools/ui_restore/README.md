# UI Restore MVP

A deterministic offline asset pipeline. It does not attempt to infer transparency from a flattened screenshot, nor reconstruct hidden PSD layers.

Requirements: Python 3.10+, Pillow.

```sh
python -m pip install Pillow
python -m unittest tools.ui_restore.test_restore -v
python -m tools.ui_restore validate specs/currencies.slices.json --base input
python -m tools.ui_restore slice specs/currencies.slices.json --base input --out client/ui_restore/assets
python -m tools.ui_restore build-godot specs/currencies.slices.json --out client/ui_restore/styles
python -m tools.ui_restore compare reference.png actual.png --roi 24 170 672 64
```

Coordinate rectangles are [x,y,width,height] in the reference design canvas. The MVP requires an actual supplied reference image. No reference art is checked in.

## Currency panel

Current scene: `client/ui/main.tscn` -> `View/Margin/Main/Currencies`. The node is a PanelContainer inside a VBoxContainer, so its position is controlled by the parent. Preserve its Row children GoldLabel, Gold, XPLabel, XP and all unique names. Apply the generated StyleBoxTexture as a local `theme_override_styles/panel` after art has been approved. Do not assign an absolute position.

The sample JSON contains proposed measurements, not measured coordinates from a finished design. Existing theme.tres uses a StyleBoxFlat with 16/14 content margins. Keep those values initially. Gold and XP are runtime text, not baked art.

## Known limitations

* Cropping a flattened screenshot preserves its original RGBA but cannot recover occluded layers or correct transparency.
* PSD/ORA export is a later phase and is not implemented here.
* Visual comparison checks only an explicit ROI; lock font, locale, viewport, render scaling, and test values.
* Nine-slice corners must be reviewed at actual target sizes.
* The generated StyleBox is not automatically installed into the existing scene.
