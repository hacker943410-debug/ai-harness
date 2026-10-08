# Codex CLI / Office Skills: v6.1 Candidate (2026-10-08)

## Current main baseline
- AI Harness 6.0.0, commit d0503b0f6aa07db4cdb5429e03b428f86d6f68e7.
- Keep 6.0.0 source/version pin until 6.1 validated, tagged and approved.
- Candidate branch upgrade/v6.1 is **not released**, and must not merge automatically.

## Source attribution
Vercel's skills.sh is an ecosystem/discovery interface and is not proof that all listed skills are Vercel-authored. Official vercel-labs/agent-skills covers web engineering and does not constitute Vercel-origin DOCX, PPTX, XLSX, PDF skills. Anthropic's separately published source-available office skills must not be copied or redispatched without individual license/content review.
The four new skills under skills/office-* are original AI Harness instructions, not third-party copies. They use locally available tools, with strict validation requirements.

## CLI compatibility work, not yet verified
Review official Codex release notes at:
- https://github.com/openai/codex/releases/tag/rust-v0.160.0
- https://github.com/openai/codex/releases/tag/rust-v0.160.1

Adapter last verified_on 2026-08-23. Skill path separately verified 2026-09-30. Check effective local version and CLI capabilities, not assumed command existence.

Run on actual target Windows host:
```powershell
codex --version
codex mcp --help
codex mcp list --json
node scripts/validate-harness-v6.mjs
node --test scripts/test-harness-v6.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRelease.ps1
```
Missing CLI / renderer is NOT_RUN, not PASS. MCP list is not authenticated handshake. Do not log config secrets, automatically modify CODEX_HOME, auto-upgrade CLI or enable prerelease/Guardian experimental features.

Validate remote stdio MCP Windows SYSTEMROOT/TEMP/TMP preservation, PowerShell sandbox/path/permission, subagent failure propagation, resume state and model/effort catalog behavior. Existing economy/balanced/frontier routing must remain dynamic, with real provider telemetry marked UNKNOWN until measured.

## Skill acceptance tests before merge
1. Each bundled SKILL.md has correct frontmatter, catalog entry, manifest payload, readable source and unique id.
2. On disposable project, use Install-ProjectSkill.ps1 -Id office-docx -ProjectRoot <test> -Client Codex; repeat each id; check .agents/skills/id/SKILL.md, lock metadata, idempotency, rollback and preservation of custom user files.
3. Generate real sample DOCX/PPTX/XLSX/PDF, reopen and validate package, content, formulas, cross references, fonts and pages. Render documents/slides/pages using approved available software; visually inspect overflow. Missing renderer must block claiming visual PASS.
4. Run full Harness 6.0 regression and compare benchmark with equal tasks; do not claim token reduction from file size alone. Real model tokens/billing and novice productivity need measured replay, not synthetic assertions.
5. Update HARNESS_VERSION/manifest source_ref/other version owners together **only after** Codex validation, release plan and tag are consistent. GitHub main and v6.0 tag remain unchanged until human-authorized merge.
