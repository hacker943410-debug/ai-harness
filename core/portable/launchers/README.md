# J Harness project portable for Windows x64

Run `JHarness.cmd status` to check the bundled Core. No system Node, Git or Codex installation is required; Windows PowerShell 5.1 or newer is required.

Install into a chosen project using `Install-JHarness.cmd` with the project and explicit approval arguments documented by `Install-JHarnessLocal.ps1 -?`. Run `JHarness.cmd setup` to use this extracted folder as the project. The installer preserves user instructions and project workflow records.

When calling the PowerShell script directly, quote the verification separator as a literal argument: `& .\JHarness.ps1 verify '--' 'C:\path\to\test.exe' 'test-script'`. PowerShell otherwise consumes a bare `--` before forwarding arguments. The launcher preserves literal quotes, UTF-8 text and trailing backslashes in verifier arguments.

This is the v8 Alpha distribution. The actual Core version is 8.0.0-core-beta.1 and adapter version is 1.0.0. READY_LOCAL verifies local operation only. Read `.agents/j-harness/PORTABLE.md` for integrity, workflow and evidence boundaries. There is no v7 fallback.
