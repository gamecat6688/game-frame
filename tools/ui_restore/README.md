# Godot UI 原位还原工具链

离线工具链：参考 PNG → 原尺寸透明切片与坐标清单 → Godot 静态场景与九宫格 → 实际渲染截图验收。可从隔离素材导出 ORA／PSD，不接入 UIFlow，也不读取或修改 Go 业务逻辑。

## 从仓库根目录运行

依赖 Python 3.10+、Pillow。可额外安装 `psd-tools`，让测试使用独立读取器验证 PSD；工具本身不需要它。

~~~powershell
python -m pip install -r tools/ui_restore/requirements.txt
python -m pip install psd-tools
python -m unittest discover -s tools/ui_restore -v

$spec = 'tools/ui_restore/specs/currencies.slices.json'
$layout = 'tools/ui_restore/specs/currencies.layout.json'
$source = 'tools/ui_restore/sample'
$generated = 'client/ui/components/currencies_restore'
python -m tools.ui_restore validate $spec --base $source
python -m tools.ui_restore slice $spec --base $source --out $generated
python -m tools.ui_restore build-godot $spec --layout $layout --project client --assets $generated --out $generated
python -m tools.ui_restore export-layers $spec --base $source --out build/ui-restore/currencies.ora
python -m tools.ui_restore export-layers $spec --base $source --out build/ui-restore/currencies.psd
~~~

首次使用自定义输出目录，先导入 Godot，以生成导入缓存。默认图形构建会跑现有页面、多语言、单机 DLL、在线 WebSocket 回归；这里没有修改 Excel，因此可以使用仓库已提交的表格产物。

~~~powershell
$godot = 'C:\path\to\Godot_v4.7.1-stable_win64_console.exe'
$gccBin = 'C:\path\to\mingw\bin'
pwsh -File tools/build.ps1 -Godot $godot -CompilerBin $gccBin -SkipTables -Test
python -m tools.ui_restore.verify_godot --godot $godot
~~~

需 Windows x64、Godot 4.7.x 和可用的图形显示。Godot 的 headless Dummy renderer 无法产生有效截图。报告在 `build/ui-restore/godot/`：`reference.png`、`actual.png`、`diff.png`、`metrics.json`、布局尺寸与测试值 `capture.json`，另有 `width-600/` 和 `preview/` 子目录。一次真实运行的精简证据见 [evidence/](evidence/)；其中 720 宽的对照图只裁取 ROI，未重绘。

也可单独比较任意同尺寸截图：

~~~powershell
python -m tools.ui_restore compare reference.png actual.png --roi 24 151 672 61 --out build/ui-restore/manual
~~~

ROI 坐标为 `[x, y, width, height]`，以画布左上为原点，右下边界不包含在内。比较原始 RGBA 通道：默认平均误差 ≤ 3 且任一通道差值 > 8 的像素比例 ≤ 1%，Alpha 差在差异图上按洋红显示。通过退出 0，超阈退出 1，输入或运行错误退出 2。要求完全相同可指定 `--threshold 0 --limit-mae 0 --limit-ratio 0`。

## 切片与布局数据约定（版本 1）

- 素材 ID 用小写下划线（如 `panel_currency_bg`）。源文件和输出文件均用相对路径。源 PNG 的尺寸须等于 `design_size`；有覆盖关系的图层用各自的透明 PNG，同一画布坐标，不允许对同一张隔离图做重叠裁剪。
- `source_rect` 是画布上的整数像素矩形。输出 RGBA PNG 保留整个矩形（不自动裁减或缩放），包括完全透明区域的 RGBA 值。`content_rect` 用切片局部坐标，必须覆盖所有非零 Alpha 像素。Manifest 记录 `origin`、`source_rect`、`content_rect`、原始尺寸、Alpha 范围及 SHA-256，供 Godot 生成器核对。
- `source_kind: "isolated"` 用于独立的透明源素材；`requires_transparency: true` 还要求裁出的组件确有透明像素。默认 `"flattened"` 仅可做原样裁切，不能重建 Alpha、被遮挡内容或分层。标记为 `requires_source_layer` 的组件没有隔离源时直接失败，不能用满底色的截图冒充透明素材。
- `bitmap` 用于静态图标或插画；`nine_slice` 的边带使用像素整数，中心必须非空。横纵方向分别支持 `stretch`、`tile`、`tile_fit`。`content_margin` 决定文字／子节点内边距，与九宫格边带分开。
- 布局 JSON 支持静态 Control、HBox/VBox、PanelContainer、Label、TextureRect、Button，生成独立设计尺寸的静态场景。固定矩形坐标相对父节点；Container 内的子节点不允许写绝对矩形。九宫格资源用于 PanelContainer 的面板和 Button 的 normal；hover／pressed 仍由主题提供。文本翻译键和预览值不写进 PNG。
- ORA／PSD 按切片数组从底到顶叠放，所有图层保留原位坐标与 Alpha。输出是可独立编辑的 8 位栅格图层，不是 Photoshop 文字、矢量或智能对象。PSD 测试校验了其独立读取器和二进制层记录，未人工在 Photoshop 中打开验证。
- 生成器不重写已有业务场景。先在预览场景确认尺寸，再在业务节点挂载生成的 `StyleBoxTexture` 或引用生成场景；不要在运行时创建这套布局。

## 顶部货币栏示例与验收边界

`client/ui/main.tscn` 的 `View/Margin/Main/Currencies` 仍由原来的 VBoxContainer 排版。唯一生产布局变更是给该 PanelContainer 设置本地 `theme_override_styles/panel`，指向生成的 `panel_currency_bg.tres`。保留 `GoldLabel`、`Gold`、`XPLabel`、`XP`；金币和经验仍由 `AdventureView.render` 写入。预览 JSON 的 `binding`／`existing_path` 只记录集成关系，不会注入运行时代码。实际集成由现有 smoke 检查本地 DLL 与测试 WebSocket 服务器钱包数值。

示例使用仓库现有 `client/ui/theme.tres` 的 StyleBoxFlat 外观：从原样式绘制到 64×64 透明 Godot SubViewport，取回 OpenGL 预乘像素并转换为直通 Alpha，在 720×1120 透明画布的 `(24,151)` 放置，形成 [隔离源 PNG](sample/existing_theme_currencies_layer.png)。该 PNG 是锁定的测试输入，**不是外部提供或批准的新美术原稿**。九宫格边带均为 16 px，内容内边距左右 16 px、上下 14 px；运行时根据父容器尺寸拉伸。

可视化测试在同一个 Godot 进程渲染真实主场景，固定英语、金币 `12,345`、经验 `678`，为独立截图测试停用 Bootstrap，不伪造后端调用。每种宽度分别截图生成的 StyleBoxTexture 与原有主题的 StyleBoxFlat（临时移除局部覆盖，未使用生成 PNG 作为基准），断言面板、行和四个标签的坐标完全一致。另验证生成预览与 720 宽实际货币栏逐像素一致。视觉通过只说明工具链能还原仓库已有外观；新美术还原须提供批准的独立图层与目标截图后重新验收。
