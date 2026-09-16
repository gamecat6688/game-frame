# 第三方与本地项目来源

- **excel2pb**：`https://github.com/gamecat6688/excel2pb`，固定提交见 `tools/excel2pb.lock.json`。通过已有源码项目编译接入，未复制其整个仓库。`tools/format_workbooks.py` 来自该项目的 excel2pb-config 技能脚本。
- **excel2pb-config 技能**：完整迁入 `.agents/skills/excel2pb-config/`，保留中英文规则、openpyxl 参考资料与格式化脚本；文档已适配本项目的目录、构建和多语言流程。
- **GDScript protobuf**：`client/addons/protobuf/` 和 `tools/protoc-gen-gdscript-simple/` 来自已有 `game-godot-network` 模板中的 Li Xi 实现；各自的 MIT LICENSE 保留在对应目录。`protoc_gen_gdscript.py` 与 `protobuf/runtime/wire.gd` 复用模板中的适配层。
- **Godot GDExtension**：`bridge/godot/gdextension_interface.h` 由 Godot 4.7.1 导出，文件头保留 Godot MIT 许可。
- **Protocol Buffers Go**：依赖 `google.golang.org/protobuf v1.36.11`，由 Go modules 管理。
- **coder/websocket**：`github.com/coder/websocket v1.8.15`，MIT 许可，服务端 WebSocket、控制帧与消息边界实现，由 Go modules 管理。
- **websocket-client**：`websocket-client==1.9.0`，Apache-2.0 许可，仅用于 Python 集成测试，见 `tools/requirements-tests.txt`。
- 原型角色、场景 SVG 为本项目原创占位素材；游戏结构参考放置卡牌，未复制其角色、美术或原始数据。
- 字体运行时使用系统字体。本项目没有复制或分发 Windows 字体文件。
