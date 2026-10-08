---
name: office-xlsx
description: Excel XLSX 수식·표·차트·서식·대시보드를 작성 또는 기존 Workbook을 수정하고 검증할 때 사용.
---
# XLSX implementation
AI Harness original guidance; NOT Vercel-authored.

## Procedure
1. Inspect workbook sheets, formulas, named ranges, validations, tables, pivots, links and output targets. Preserve original and establish BEFORE baseline.
2. Edit native XLSX using approved tools such as openpyxl (for existing workbook) or XlsxWriter (for new output). Distinguish from dashboard-builder (HTML dashboard). Preserve styles and functions; do not silently discard unsupported workbook features.
3. Reopen output and verify sheets, formulas, dependencies, named ranges, validations, links, formats, charts and data integrity.
4. openpyxl does NOT calculate formulas; verify cached/calculated results with an approved Excel-compatible calculation engine when available. Without it mark calculated output UNVERIFIED. Check representative edge cases and print layout.
5. Give resulting XLSX, baseline differences, test results and limitations.
## JIT and safety
Load necessary sheets/ranges only. No macro execution, remote refresh, hidden secrets or assumed formulas.
