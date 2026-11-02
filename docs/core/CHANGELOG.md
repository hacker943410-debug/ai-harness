# J Harness Core changelog
## v8.0.0-core-beta.1
- Based on locally verified 8.0.0-core-mvp.2.
- Codex-only distribution; Windows 11 x64 is the initial support candidate.
- Preserve existing Codex authentication, model settings and unmanaged global guidance.
- Include portable install/update/uninstall launchers and a package-local jh launcher.
- Retain mvp.2 read-only queries, project-local execution evidence and multiline Skill descriptions.
- Update transaction preserves Core backups/custom Skills/history and attempts rollback on failure.
- Claude/AGY adapters, provider token/cost metering and automatic budget enforcement remain unimplemented.
- No services, MSI, OS isolation, VM requirement or automatic CLI/Skill download.

## v8 Environment Bootstrap — Phase 1 candidate (not released)
- Read-only Windows preflight also usable without Node; Node-based selected-CLI and project-profile dependency inventory.
- Separate observed executable file from actual runtime authentication, model loading and command execution.
- Dependency plan never installs packages or changes Windows settings; no three-CLI subscription requirement.
- Owner-approved SHA-256 checked single-file offline staging primitive for future self-contained installation.
- Windows/Linux CI negative tests. Full install/rollback and enforced Supervisor remain NOT_IMPLEMENTED.
