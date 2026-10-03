# v5.1 Inventory

Source of truth: GitHub `hacker943410-debug/ai-harness`, commit `8ebab0087b228c0203a202bead8fb56853d9cb27`; fetch confirmed HEAD equals origin/main before migration. Detailed 114-file inventory and SHA-256: [inventory.json](inventory.json).

Runtime: PowerShell 5.1+, Node 22+, Git; 26 JIT policies, CORE 1.2, ROUTER 2.0, PROJECT_INIT 3.1. Layer A declarative source / Layer B machine runtime and credential state / Layer C project bindings remain separate. No repository AGENTS.md existed. The consuming project has a custom L1 Excel skill; it is outside this source migration.

Existing capabilities: bootstrap Git ref pinning and dirty/ahead refusal; machine plan installer with journal and rollback; environment diagnosis; runtime manifests; three native client descriptors; capability catalogs and project capability locks; dashboard-builder Skill; optional Jev shadow advisor disabled by default with deterministic fallback; read-only Doctor; secret pre-commit guard; repository AST/lint/schema checks and local Git/Skill regressions. Existing workflows and Skill references are reused without copying policies into projects.

Baseline commands: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRepo.ps1 -Json`, `Test-HarnessRelease.ps1`, `node scripts/test-jev-scenarios.mjs`. Raw results are collected before implementation; historical patch-note results alone are insufficient. No general phase engine, transition transaction, beginner full-lifecycle simulator, or same-case v5/v6 benchmark exists.

Current mode: MIGRATION / H3 / R3. Source development state: SAFE_CHECKPOINT at baseline commit; isolated worktree branch upgrade/v6.0. Installed v5.1 checkout and untracked plan.json stay intact. Runtime implementation introduces no package dependency or folder relocation.
