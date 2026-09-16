# excel2pb-config 技能

用于设计、编辑、整理和校验 `table/xlsx/` 下的 excel2pb 游戏配置工作簿，包括表头、字段类型、主键、外键、索引、枚举、国际化和客户端/服务端导出规则。

## 如何触发

- 显式触发：在请求中写 `$excel2pb-config`。
- 自动触发：请求涉及 `table/xlsx/` 下的 `.xlsx` 配置表、excel2pb、protobuf 表结构、`pk`、`unique`、`fk`、`index`、`i18n`、枚举、时间戳或 `c`/`s`/`cs` 导出过滤时，Codex 会自动选择本技能。

## 触发示例

```text
使用 $excel2pb-config 检查 table/xlsx 下所有配置表，列出会导致导出失败的问题。
```

```text
给道具配置表增加一个可本地化的描述字段，并保留现有表头样式和批注。
```

```text
检查奖励表里的 fk、复合主键和 repeated 嵌套值是否合法，然后整理列宽和行高。
```

技能的完整执行规则见 [SKILL.md](SKILL.md)。

## 当前项目

本技能迁自 excel2pb 项目，已适配本仓库目录、双端导出、自定义 Go 模板以及 Godot/excel2pb 两类翻译来源。配置变更时先读技能，再从仓库根目录运行：

```powershell
./tools/generate.ps1
python .agents/skills/excel2pb-config/scripts/format_workbooks.py table/xlsx
# 涉及玩法规则时，重建 DLL/服务器并验证
./tools/build.ps1 -Test
```

包含中文规则 [SKILL.zh-CN.md](SKILL.zh-CN.md)、中英文 openpyxl 参考资料及完整格式化脚本；无需到原 excel2pb 仓库读取这些技能文件。导表工具本身仍按 `tools/excel2pb.lock.json` 接入。
