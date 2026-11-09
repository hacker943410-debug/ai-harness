# Private company Word profile

Store one local directory containing:

| File | Purpose |
|---|---|
| `reference.docx` | Exact retained source; SHA-256 fixed in the profile |
| `profile.json` | Page/section geometry, package-part inventory, stable component/slot locators and quality gates |
| `artifact.md` | Measured typography/table/component rules, content capacities, intended adaptations and render evidence |
| `reference-render/` | Locally rendered reference pages; never public CI artifacts |

The project binding `.ai/company-word.json` contains only `schema_version: 1`,
`skill: "jh-company-word"`, and an absolute local `profile_path`. It does not
contain business prose, passwords or credentials. A user-wide binding may live
under the active Codex home. Project binding overrides the user-wide default.

Profile capture is deliberate: inspect all distinct page patterns and create a
selection JSON with top-level `word/document.xml` body indices. `prototypes`
contains `heading1`, optional `heading2`/`heading3`, `body`, optional `bullet`, and
`table`. `body_section` selects the source section properties. Optional `cover`,
`cover_section` and `cover_slots` select a cover and editable fields. A cover
slot role is one of title/subject/subtitle/version/owner/summary.
`running_text` maps exact source leaf-paragraph text to a replacement containing
`{{running_title}}`; images, logos and other drawing structures stay intact.
`preserve_text` lists reviewed fixed brand/copyright paragraphs. Unknown header
or footer prose is rejected. `clear_text_parts` explicitly names unused
header/footer parts whose source text must be erased in derivatives, such as
business-specific divider text. Do not clear parts needed by selected sections.
Tracked revisions, comments, real notes, custom properties or custom XML containing hidden prose
require a reviewed sanitized working copy; keep the original retained separately.

```text
python <skill>/scripts/company_word.py capture --source <reference.docx> --selection <selection.json> --profile <new-private-directory>
```

Capture refuses active content, tracked revisions, unreviewed external relationships, unsafe ZIP
paths, malformed XML and existing profiles. Never put the private directory
inside a public source checkout. These checks do not replace reviewing the
source document for confidential or unwanted content.

Build content JSON contains `title`, optional `subject`, `subtitle`, `version`,
`owner`, `summary`, `running_title`, `include_cover`, and `sections`.
Each section has `heading`, optional `level` (1–3), `paragraphs`, `bullets`, and
`tables`; a table has `headers` and rectangular string `rows`.
Only supplied facts fill slots. Covers are not forced on short memoranda.

The helper supports cover/body/heading/list/table composition. History,
approvals, TOC and dividers are inspected reference components; their presence
in the source inventory does not mean the helper automates their composition.
Use an explicit OOXML composition and broader verification when required.

All unmodified ZIP parts, including themes, styles, numbering and media, remain
byte-identical. Intentional changes are limited to main content, settings,
core metadata and header/footer text/fields. The build receipt binds source,
content and output hashes. It is local evidence, not a cryptographic attestation
or a guarantee that an AI selected the skill.

For additional tables, retain the source's borders, fill and text properties;
adapt column widths within printable width and repeat the header. A content
capacity error requires editing the content/layout, never silently shrinking
text. Regenerate to a new output path for each iteration.
