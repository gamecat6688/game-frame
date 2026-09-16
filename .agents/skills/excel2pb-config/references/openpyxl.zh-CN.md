# 用 openpyxl 读写 excel2pb 配置表

excel2pb 使用单元格批注声明字段约束；读写 `.xlsx` 必须选择保留批注的库。使用 `openpyxl`，不要用 pandas 写回工作簿。

- 普通数据表固定四行表头：第 1 行字段名、第 2 行类型、第 3 行导出过滤、第 4 行说明，数据从第 5 行开始。名称以 `_Enum` 结尾的枚举表只有一行表头，枚举值从第 2 行开始。
- 只有第 1 行字段名单元格的批注会被视为 tag；多个 tag 用 `;` 分隔。
- openpyxl 的行、列编号从 1 开始，与 Excel 显示的行号一致。
- 修改现有工作簿时保留颜色、边框、批注和冻结窗格。普通数据表的第 1–4 行功能表头水平、垂直居中，第 4 行说明文字开启自动换行；枚举表仅第 1 行作为功能表头并居中。值行使用 Excel 默认水平、垂直对齐：普通表从第 5 行起，枚举表从第 2 行起；不得批量居中。
- 修改字段名或数值后，按可见内容调整列宽。中日韩全角字符按两个显示单位计算，增加水平留白，长文本列最大宽度建议限制为 48；超过上限的文本自动换行并增加行高，不要把整张表拉得过宽。
- 需要确定性格式化时，优先运行 `../scripts/format_workbooks.py <工作簿或目录>`。它会保留现有工作簿，根据 sheet 名区分普通表和 `_Enum` 枚举表，仅将各自的功能行居中，将值行恢复为默认水平、垂直对齐，按 Unicode 显示宽度调整列宽，并处理长文本换行和行高。应在最后一次 excel2pb 导出后运行，因为 i18n 合并可能重新生成 `I18N.xlsx`，覆盖此前的列宽或行高。

## 读取表与批注

```python
import openpyxl

wb = openpyxl.load_workbook("table/xlsx/物品.xlsx")
for ws in wb.worksheets:
    if ws.title.startswith("#"):
        continue

    names = [cell.value for cell in ws[1]]
    types = [cell.value for cell in ws[2]]
    filters = [cell.value for cell in ws[3]]

    for col in range(1, ws.max_column + 1):
        cell = ws.cell(row=1, column=col)
        tags = [] if not cell.comment else [
            tag.strip() for tag in cell.comment.text.split(";") if tag.strip()
        ]

    for row in range(5, ws.max_row + 1):
        values = [ws.cell(row=row, column=col).value for col in range(1, ws.max_column + 1)]
        if not any(value is not None and str(value) != "" for value in values):
            continue
```

## 写入 tag

```python
from openpyxl.comments import Comment

cell = ws.cell(row=1, column=3)
cell.comment = Comment("fk:Item.ID;index;", "designer")
wb.save("table/xlsx/物品.xlsx")
```

覆盖批注时重新赋值 `cell.comment`；删除批注时赋值 `None`。修改现有表时先 `load_workbook()` 再改，不能新建 Workbook 覆盖原文件，否则会丢掉其他 sheet 与批注。

如果批注正文包含 `[Threaded comment]`、Excel 版本兼容说明或微软链接，这些文字不是 excel2pb tag。确认其中没有必要的 `fk:` 或 `index` 后删除整个批注；若兼容文本后仍带有实际 `Comment: fk:...`，则把批注规范化为纯 tag 文本。

设置对齐时，根据 sheet 名确定功能行数：`_Enum` 枚举表为 1 行，其他表为 4 行。仅普通数据表的第 4 行固定开启自动换行：

```python
from copy import copy

is_enum = ws.title.endswith("_Enum")
functional_rows = 1 if is_enum else 4

for row in range(1, ws.max_row + 1):
    for cell in ws[row]:
        alignment = copy(cell.alignment)
        if row <= functional_rows:
            alignment.horizontal = "center"
            alignment.vertical = "center"
        else:
            alignment.horizontal = None
            alignment.vertical = None
        if not is_enum and row == 4:
            alignment.wrap_text = True
        cell.alignment = alignment
```
