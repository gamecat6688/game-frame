# Editing excel2pb Workbooks with openpyxl

excel2pb uses cell comments to declare field constraints. When reading or writing `.xlsx` files, use a library that preserves comments. Use `openpyxl`; never write the workbook back with pandas.

- A regular data sheet has four fixed header rows: row 1 contains field names, row 2 types, row 3 export filters, and row 4 descriptions; data starts on row 5. An enum sheet whose name ends in `_Enum` has only one header row, and enum values start on row 2.
- Only comments on field-name cells in row 1 are treated as tags. Separate multiple tags with `;`.
- openpyxl row and column indexes start at 1 and therefore match the row and column numbers displayed by Excel.
- Preserve existing colors, borders, comments, and frozen panes when editing a workbook. Center functional rows 1–4 in regular data sheets and keep row 4 descriptions wrapped. In enum sheets, center only functional row 1. Use Excel's default horizontal and vertical alignment for value rows: row 5 onward in regular sheets and row 2 onward in enum sheets. Do not bulk-center value cells.
- Fit columns to their visible content after changing field names or values. Count full-width CJK characters as two display units, add horizontal padding, and cap long-text columns at a practical width such as 48. Wrap text beyond that cap and increase the row height rather than creating extremely wide sheets.
- For deterministic formatting, prefer `../scripts/format_workbooks.py <workbook-or-directory>`. It preserves existing workbooks, uses the sheet name to distinguish regular and `_Enum` sheets, centers only their functional rows, restores default horizontal and vertical alignment for value rows, computes Unicode-aware column widths, and wraps and raises long rows. Run it after the final excel2pb export because the i18n merge may regenerate `I18N.xlsx` and discard earlier width or height adjustments.

## Read Sheets and Comments

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

## Write Tags

```python
from openpyxl.comments import Comment

cell = ws.cell(row=1, column=3)
cell.comment = Comment("fk:Item.ID;index;", "designer")
wb.save("table/xlsx/物品.xlsx")
```

Replace a comment by assigning a new value to `cell.comment`; delete it by assigning `None`. When editing an existing workbook, call `load_workbook()` first. Do not create a new `Workbook` and overwrite the file, because doing so loses other sheets and comments.

Text such as `[Threaded comment]`, Excel compatibility notices, or Microsoft links is not an excel2pb tag. If the comment contains no required `fk:` or `index` tag, remove the entire comment. If compatibility text wraps an actual value such as `Comment: fk:...`, normalize it to the plain tag text.

When formatting alignment, derive the functional-row count from the sheet name: one row for `_Enum` sheets and four rows otherwise. Keep wrapping enabled for row 4 only in regular data sheets:

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
