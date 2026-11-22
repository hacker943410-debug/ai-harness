# J Harness 8.2.1 Windows 이동형 시작 안내

## 설치하고 첫 작업 시작하기

1. Windows x64에서 패키지 압축을 풉니다. Node는 패키지에 들어 있습니다. 내 문서처럼 쓸 수 있는 폴더에 설치합니다.
2. 패키지 폴더에서 `.\Install-JHarness.cmd -ProjectPath "C:\Projects\MyProject" -ApproveInstall`을 실행합니다. 예시 경로를 작업할 폴더 경로로 바꾸세요. 패키지를 푼 폴더 자체에서 작업하려면 `.\JHarness.cmd setup`을 실행합니다.
3. 프로젝트 폴더에서 `.\JHarness.cmd quickstart`를 실행하고 사용할 AI CLI를 고릅니다. 실행 파일을 찾은 CLI가 목록에 먼저 표시됩니다. 예를 들어 Claude Code를 쓰려면 `.\JHarness.cmd select claude`를 실행하세요. 선택한 CLI가 없으면 그 CLI의 공식 설치 안내가 나옵니다.
4. Claude Code를 선택했고 연결 안내가 나오면 `.\JHarness.cmd connect claude`를 실행합니다. 기존 `CLAUDE.md` 내용은 보존하고 `AGENTS.md`를 읽는 줄을 추가합니다. Codex와 AGY는 프로젝트의 `AGENTS.md`를 사용합니다.
5. 같은 프로젝트 폴더에서 선택한 CLI를 시작하고, `quickstart`에 나온 첫 요청 예시를 실제 만들고 싶은 프로그램으로 바꿔 입력합니다. 하네스가 프로젝트 지침을 읽고 필요한 도구, 첫 기능, 테스트와 실행법을 안내하도록 요청합니다.

선택은 프로젝트에 저장됩니다. 이후에는 `.\JHarness.cmd quickstart`만 실행하세요. 사용 CLI를 바꾸려면 `select codex`, `select claude`, `select agy` 중 하나를 실행합니다. 이번에만 다른 CLI의 안내를 보려면 `quickstart --client agy`처럼 실행하세요.

`.\JHarness.cmd doctor`에서 하네스 설치와 프로젝트 연결, `clientGuidance`의 지침 파일 상태를 확인합니다. Codex에서 `AGENTS.override.md`를 쓰는 프로젝트는 해당 파일의 지침이 우선합니다. 기존 지침은 그대로 보존되므로 하네스 연결도 필요한 경우 파일을 검토하세요. `modelApplication`은 실제 CLI 세션에서 따로 확인합니다. 로그인 화면이 뜨면 선택한 CLI에서 진행합니다. `environment plan --client codex`는 해당 CLI의 상세 환경 점검 결과를 JSON으로 보여줍니다.

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

## Alpha 3, 8.1.0 또는 8.2.0 프로젝트 업데이트

프로젝트의 CLI 세션을 닫고 진행 중인 작업을 마칩니다. 8.2.1 패키지를 별도 폴더에 푼 다음, 패키지 폴더에서 아래 명령을 실행합니다. 예시 경로를 업데이트할 프로젝트 폴더로 바꾸세요.

```powershell
.\Install-JHarnessLocal.ps1 -Action Plan -Upgrade -ProjectPath 'C:\Projects\MyProject'
.\Install-JHarnessLocal.ps1 -Action Install -Upgrade -ApproveInstall -ProjectPath 'C:\Projects\MyProject'
```

설치기는 지원하는 Alpha 3, 8.1.0, 8.2.0의 배포 해시를 확인합니다. 첫 명령은 변경 계획을 보여줍니다. 관리 지침, 실행 파일 또는 이전 런타임에 충돌이 있으면 업데이트를 중단합니다. 설치기는 이전 런타임과 관리 파일을 `.jh-artifacts/j-harness-core/upgrades`에 백업한 뒤 새 `doctor`를 실행합니다. 실패하면 이전 버전으로 복구하고 검증합니다.

중단으로 `upgrade.lock`이 남으면 잠금 파일, 작업 기록과 백업을 보관하세요. 업데이트에 사용한 8.2.1 패키지와 같은 프로젝트 경로로 복구를 실행합니다.

```powershell
.\Install-JHarnessLocal.ps1 -Action Recover -Upgrade -ApproveInstall -ProjectPath 'C:\Projects\MyProject'
```

복구는 기존 프로세스가 종료됐는지, 파일이 작업 기록과 일치하는지 확인합니다. 완료된 업데이트는 그대로 검증하고, 중단된 업데이트는 이전 런타임과 관리 파일을 복구합니다. 충돌이 나오면 복구 기록을 보관해 검토하세요.

Run `JHarness.cmd doctor` and `JHarness.cmd progress` from the upgraded project. Project settings and historical workflow records remain available. An old verification appears as `STALE` when it was recorded against a different runtime, even when the product sources are byte-identical. Open a new coding session and rerun the project's verification before relying on fresh results.

Read the bundled `jh-guided-development` Skill for analysis → plan → implement → verify → handoff. Beginner Mode stays on. Real command evidence and independent release review remain required. `READY_LOCAL` means local runtime readiness; global connection, model behavior, real user verification and production deployment require separate observed evidence.
