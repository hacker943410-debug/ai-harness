---
name: office-pptx
description: 편집 가능한 PowerPoint PPTX를 설계·작성·수정하고 슬라이드별 시각 검증이 필요할 때 사용.
---
# PPTX implementation
AI Harness original guidance; NOT Vercel-authored.

## Procedure
1. Inspect source deck, masters, theme, slide order, audience, aspect ratio and editable requirements. Make risky layout/theme replacement a Decision Gate.
2. Create or edit slides with approved tools (e.g. python-pptx); preserve editable text, shapes and charts, source data, units and slide layouts. Never silently delete existing slides.
3. Reopen PPTX to verify slide/shapes/media/chart integrity. Render ALL slides and inspect overflow, font substitution, illegible labels, cropped content and theme consistency.
4. If slide rendering unavailable report NOT_RUN_VISUAL, not PASS. Provide PPTX, actual verification evidence and known limitations.
## JIT and safety
Only load relevant slides/references. Verify license for external images and templates; do not auto-fetch assets.
