# Evidence and quality interpretation

Keep three outcomes separate: source/profile integrity, rendered artifact
quality, and installed-client usability. The helper reports structural results
only. The reviewer records actual Word/render observations separately and binds
them to the final DOCX SHA-256.

| Dimension | Points | Evidence |
|---|---:|---|
| Reference fidelity | 30 | Exact page geometry; source theme/styles/media; representative cover/body/heading/table/header/footer comparison |
| Package and source integrity | 25 | Source unchanged, ZIP/XML and relationships valid, preserve-only parts unchanged, exact output receipt |
| Layout and readability | 20 | All final pages rendered and visually reviewed; no clipping/overlap/missing glyphs; table headers and page breaks usable |
| Content correctness | 15 | Requested content covered, no inherited sample facts, no fabricated approvals/dates, correct running title/numbering |
| Reuse and installation | 10 | Installed skill/profile resolve, helper works from installed path, original project instructions/skills remain intact |

Score each dimension against observed evidence and explain deductions. Scores
are a review rubric, not a measured probability that future documents are free
of defects. Do not award points for a command that was not run. Mark unknown
dimensions unscored and the total incomplete.

Acceptance requires at least 90/100 AND all critical gates passing. Any source
change, confidentiality leak, corrupted/unopenable file, changed preserve-only
part without explanation, missing text/glyphs, clipping/overlap, false content,
or failed required test blocks acceptance regardless of score. A check for a
missing reference, hash drift, malformed content, existing output, or missing
render evidence must fail or remain pending, never silently fall back.

Word read-only PDF export refreshes fields in memory but does not persist
updated caches in the DOCX. Report that distinction. A final saved Word copy
requires fresh validation and a new hash-bound receipt; do not reuse the
pre-save package receipt. Page-count fields must agree with the intended
numbering scope (body section versus whole document).

CI uses only synthetic documents on Windows/Linux. It proves those tested code
paths, not company-template visual fidelity, Microsoft Word automation on a
machine without Word, automatic model behavior, or v8 production enforcement.
The current session can verify installed files and a deterministic smoke run;
new-session natural-language auto-discovery is a separate observation.
