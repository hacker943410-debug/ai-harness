# J Harness Core project portable runtime

This adapter (1.0.0) runs Core 8.0.0-core-beta.1 entirely from the project. The Windows distribution includes trusted Node 22.22.2; Node, Git, Codex and a global profile do not need to be installed.

Run `JHarness.cmd status` from the extracted package. Install into a project with `Install-JHarnessLocal.ps1`; it preserves existing project guidance and mutable records. `JHarness.cmd setup` adds the project binding and guidance. The runtime can also be invoked with `node portable.mjs --project <directory> status`.

Supported Core commands: status, doctor, begin, advance, verify, finish, policy, skills, progress, learn, lessons. Global installation, toggles and uninstall are unavailable through this wrapper. Existing global APIs retain their behavior outside the wrapper.

Before importing Core, the wrapper checks every payload hash, path containment, completeness, version and any project manifest pin. Missing or damaged files block execution with no v7 fallback. Manifest checks attest local integrity, not an OS security boundary or publisher signature.

Mutable workflow, events, logs, approved external Skills and lessons live under project `.jh-artifacts/j-harness-core`. Portable discovery defaults to bundled and project Skills. Native company Word Skills and private-profile resolution follow the existing Core contracts.

The canonical `project_mode` in `.ai/harness-state.json` and `.ai/harness-project.json` takes precedence over stack heuristics. Conflicting or invalid modes block workflow creation. An explicit `verification_scope` in the project binding selects included relative inputs and exclusions; unsafe paths, links, missing or empty inputs block verification. A changed source fingerprint invalidates previous PASS evidence before handoff and finish.

Read the bundled `jh-guided-development` Skill for analysis → plan → implement → verify → handoff. Beginner Mode stays on. Real command evidence and independent release review remain required. `READY_LOCAL` means local runtime readiness; global connection, model behavior, real user verification and production deployment require separate observed evidence.
