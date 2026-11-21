# J Harness 8.1 Windows 이동형 시작 안내

## 설치하고 첫 작업 시작하기

1. Windows x64에서 패키지 압축을 풉니다. Node는 패키지에 들어 있습니다. 내 문서처럼 쓸 수 있는 폴더에 설치합니다.
2. 패키지 폴더에서 `.\Install-JHarness.cmd -ProjectPath "C:\Projects\MyProject" -ApproveInstall`을 실행합니다. 예시 경로를 작업할 폴더 경로로 바꾸세요. 패키지를 푼 폴더 자체에서 작업하려면 `.\JHarness.cmd setup`을 실행합니다.
3. 프로젝트 폴더에서 `.\JHarness.cmd quickstart`를 실행합니다. 설치된 코딩 CLI를 찾아 다음 행동을 안내합니다. CLI를 직접 고르려면 `--client codex`, `--client claude`, `--client agy` 중 하나를 붙입니다. 선택한 CLI가 없으면 공식 설치 안내를 보여줍니다.
4. 같은 프로젝트 폴더에서 선택한 CLI를 시작하고, `quickstart`에 나온 첫 요청 예시를 실제 만들고 싶은 프로그램으로 바꿔 입력합니다. 하네스가 프로젝트 지침을 읽고 필요한 도구, 첫 기능, 테스트와 실행법을 안내하도록 요청합니다.

`.\JHarness.cmd doctor`로 하네스 설치와 프로젝트 연결을 확인합니다. `READY_LOCAL`과 `BOUND_VERIFIED`가 나오면 로컬 하네스를 쓸 준비가 된 것입니다. 로그인 화면이 뜨면 선택한 CLI에서 진행합니다. `environment plan --client codex`는 해당 CLI의 상세 환경 점검 결과를 JSON으로 보여줍니다.

## 작업 중 확인할 명령

- `.\JHarness.cmd route "만들고 싶은 기능"`은 계획을 미리 보여줍니다. 코딩 CLI는 `begin`, `advance plan --note "구현 계획과 테스트 기준"`, `advance implement`, `verify`로 작업을 기록합니다. 각 명령 뒤에 `--help`를 붙이면 사용법을 볼 수 있습니다.
- `.\JHarness.cmd progress`는 현재 작업 단계와 최근 검증 결과를 보여줍니다. 결과가 `STALE`이면 마지막 통과 기록 이후 코드나 실행 환경이 바뀌었으므로 현재 버전에서 테스트를 다시 실행합니다.
- 테스트가 통과하면 코딩 CLI가 `advance handoff`로 넘어가고, 사용법을 담은 파일을 `finish --guide README.md`처럼 지정해 작업을 마칩니다.

PowerShell 스크립트를 직접 호출하는 코딩 CLI는 `& .\JHarness.ps1 verify '--' 'C:\path\to\test.exe' 'test-script'`처럼 검증 구분자 `'--'`를 따옴표로 감싸세요.

Windows Codex에서 **테스트 출력 안에** `spawn EPERM`이 보이면, 실행된 테스트 도구가 내부에서 별도 프로세스를 시작하지 못했을 수 있습니다. 같은 테스트를 프로젝트 폴더의 일반 터미널에서 `verify`로 실행하거나, 테스트 도구가 지원하는 단일 프로세스 옵션을 사용하세요.

Before importing Core, the wrapper checks every payload hash, path containment, completeness, version and any project manifest pin. Missing or damaged files block execution with no v7 fallback. Manifest checks attest local integrity, not an OS security boundary or publisher signature.

Mutable workflow, events, logs, approved external Skills and lessons live under project `.jh-artifacts/j-harness-core`. Events for a workflow carry its run ID. Verification persists the executable, argument count, exit status and hashes. The command response includes redacted argument previews. Portable discovery defaults to bundled and project Skills.

Ordinary local verification runs with the current user's OS permissions. Local evidence records the actual test command and result. `finish` records the verified handoff and its usage guide.

The canonical `project_mode` in `.ai/harness-state.json` and `.ai/harness-project.json` takes precedence over stack heuristics. Conflicting or invalid modes block workflow creation. An explicit `verification_scope` in the project binding selects included relative inputs and exclusions; unsafe paths, links, missing or empty inputs block verification. A changed source fingerprint invalidates previous PASS evidence before handoff and finish.

## Upgrade a published Alpha 3 project

Close the project's CLI sessions and finish the active workflow. Extract the 8.1 package into a separate folder and run these commands from that folder. Adjust the path to the Alpha 3 project.

```powershell
.\Install-JHarnessLocal.ps1 -Action Plan -Upgrade -ProjectPath 'C:\Projects\MyProject'
.\Install-JHarnessLocal.ps1 -Action Install -Upgrade -ApproveInstall -ProjectPath 'C:\Projects\MyProject'
```

The plan checks the published Alpha 3 manifest and lists the managed changes. Conflicts in the managed block, launcher or prior runtime stop the upgrade. The installer backs up the previous runtime and managed file bytes under `.jh-artifacts/j-harness-core/upgrades`, then runs the new `doctor`. A failed doctor triggers restore and verification of Alpha 3.

If an interruption leaves `upgrade.lock`, keep the lock, journal and backups. Run recovery using the same 8.1 package and project directory.

```powershell
.\Install-JHarnessLocal.ps1 -Action Recover -Upgrade -ApproveInstall -ProjectPath 'C:\Projects\MyProject'
```

Recovery checks that the old process has stopped and that the affected files match a known state in the journal. It verifies any completed upgrade or restores the previous Alpha 3 runtime and managed files. If recovery reports a conflict, keep the transaction files for review.

Run `JHarness.cmd doctor` and `JHarness.cmd progress` from the upgraded project. Project settings and historical workflow records remain available. An old verification appears as `STALE` when it was recorded against a different runtime, even when the product sources are byte-identical. Open a new coding session and rerun the project's verification before relying on fresh results.

Read the bundled `jh-guided-development` Skill for analysis → plan → implement → verify → handoff. Beginner Mode stays on. Real command evidence and independent release review remain required. `READY_LOCAL` means local runtime readiness; global connection, model behavior, real user verification and production deployment require separate observed evidence.
