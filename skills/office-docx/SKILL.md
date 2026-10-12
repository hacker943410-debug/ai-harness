---
name: office-docx
description: Word DOCX 문서를 작성·수정하고 구조·서식·페이지를 검증할 때 사용.
---
# DOCX implementation
AI Harness original guidance; NOT Vercel-authored.

## Procedure
1. Confirm audience, intended content, source document, style constraints, tables, headers and page setup. For edits preserve the original and operate on a copy. Explain material choices with pros, cons and risks.
2. Implement editable .docx using installed/approved tools (e.g. python-docx). Preserve original styles, tables, numbering, sections and embedded objects; do not silently reformat an existing document.
3. Reopen result. Check DOCX package, headings, tables, media, links, numbering and references. Render every page with approved available renderer, inspect line wrapping, clipping, broken tables, page splitting and Korean font fallback.
4. If renderer absent, mark visual verification NOT_RUN, not PASS. Provide document, modifications, actual test commands and limitations.
## Verify — mandatory evidence
Reopen the resulting document and record structural and rendered-page verification status; if no renderer is available, record VISUAL_NOT_RUN rather than PASS.

## Token and safety
Use only relevant source sections and just-in-time policies. Do not auto-install external tools or overwrite the original. Do not invent content.
