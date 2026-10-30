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
