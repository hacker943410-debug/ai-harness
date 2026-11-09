---
name: jh-company-word
description: Create company Word documents from the user's private reference profile when asked for 회사용 Word 양식, 회사 문서 양식, or corporate Word formatting. Preserve the reference's visual system while adapting the outline to the requested document.
---

Use the company's retained Word reference as the design authority. The reference
is private local data and is not bundled with this public skill.

1. Resolve `.ai/company-word.json` in the current project, then the same filename
   under the active `CODEX_HOME` (or `~/.codex` when unset), then the shared user
   default `~/.agents/company-word.json`. Read `profile_path`;
   verify its reference hash with the helper. An explicit supplied profile takes
   precedence. If no profile exists, request one reference DOCX and distill it;
   do not silently substitute a generic corporate style.
2. Read the private `artifact.md`, `profile.json`, and the relevant source page
   images. Confirm page geometry, theme/fonts, cover, heading levels, body,
   tables, logos, running titles, footer and numbering. See
   [format-profile.md](references/format-profile.md).
3. Map the user's actual content to the requested document type. Reuse source
   components; a long SOW reference does not require every later report to
   use the same chapters. Use a cover for formal reports; omit it for a short
   memo when appropriate. Include history/approval/TOC/dividers only when the
   document needs them. Never copy sample people, dates, approvals or business
   claims into a new document. Do not invent missing facts.
4. For supported cover/body/headings/lists/tables, write a content JSON and run:

   ```text
   python <skill>/scripts/company_word.py build --profile <private-directory> --content <content.json> --output <new.docx>
   python <skill>/scripts/company_word.py verify --profile <private-directory> --output <new.docx>
   ```

   The helper clones the retained package and documented prototypes, preserves
   untouched ZIP parts, replaces source running titles, and requests field
   refresh. It refuses overwrites. Rich history/approval/TOC/divider composition
   uses direct source-derived OOXML with a documented expanded slot map and its
   own fidelity checks; do not represent the helper as supporting those modes.
5. Open the generated file in Word, refresh fields and inspect every rendered
   page. `Render-CompanyWord.ps1` opens the document read-only and exports PDF;
   rasterize that PDF using an available trusted local renderer. It does not
   save Word's updated field caches into the DOCX. If cached fields must be
   persisted, use a separate working copy, save it in Word, then repeat package,
   layout and content verification on that final copy. Record actual renderer,
   page count, font substitutions, and any intentional deviations.
6. Evaluate [quality.md](references/quality.md). `STRUCTURAL_PASS_VISUAL_REQUIRED`
   means only structural checks passed. Never claim Word compatibility, visual
   fidelity, activated client discovery or production readiness from file
   creation, skill installation, or a numerical score alone.

The reference, profile, source page images and generated business documents stay
local unless the user explicitly chooses a destination. Publish only generic
code, instructions and synthetic fixtures. Preserve original source bytes.
