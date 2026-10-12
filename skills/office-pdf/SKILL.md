---
name: office-pdf
description: PDF 생성·편집·병합·분할 및 렌더링 품질 검증이 필요할 때 사용.
---
# PDF implementation
AI Harness original guidance; NOT Vercel-authored.

## Procedure
1. Distinguish creation vs edit vs conversion. Record paper, fonts, page size, form and accessibility requirements; preserve original and signed files.
2. Use approved PDF engine (e.g. ReportLab, WeasyPrint, pypdf, PyMuPDF as task appropriate). Verify Korean glyph coverage/font embedding. Do not alter signatures or legal evidence without explicit authorization.
3. Reopen PDF; check page count/sizes, text extraction, links/bookmarks/forms and metadata. Render EACH page to inspect tables, clipping, page breaks and images.
4. For true redaction confirm underlying content removal, not covering. For merging check page provenance/order. Missing renderer => VISUAL_NOT_RUN, never PASS.
5. Deliver PDF, verification results, source where applicable and constraints.
## JIT and safety
Read relevant pages only, avoid OCR unless needed. Never automatically upload confidential PDFs or install unreviewed external skills.
