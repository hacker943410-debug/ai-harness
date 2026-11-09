# J Harness v8 Phase 2 — Windows CI 실행을 위한 소유자 검토·승인 절차

**상태 (2026-11-05): 로컬 코드/정적 회귀 37 PASS, 실제 Windows 실행 NOT_RUN, 제품 출시 NO-GO.**

## 왜 기존 수동 워크플로를 교체했는가?

기존 `v8-supervisor-phase2-windows-ci-CANDIDATE.yml`은 `workflow_dispatch`만 포함하여, 워크플로가 아직 기본 브랜치 `main`에 존재하지 않으면 GitHub Actions UI의 수동 실행 버튼으로 시작할 수 없습니다. 공식 안내: <https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow>.

이번 실행 후보는 **`pull_request` 트리거**로 변경했습니다. PR의 base가 `feature/v8-environment-bootstrap-phase2`, head가 `feature/v8-supervisor-phase2-windows-ci`, 동일 저장소의 소유자 계정이 작성한 PR일 때만 CI를 시작하도록 job-level 조건을 추가했습니다. 병합은 금지합니다. 같은 저장소의 Draft PR만 열어도 처음 테스트를 시작할 수 있습니다. `pull_request_target`, `push`, `workflow_dispatch`는 사용하지 않습니다.

## 준비 작업 (GitHub Desktop 권장)

1. GitHub Desktop에서 `hacker943410-debug/ai-harness` 저장소를 엽니다. 변경사항이 있는 개인 작업 트리가 있다면 **절대로 덮어쓰지 마세요**.
2. `Fetch origin` 이후 `feature/v8-environment-bootstrap-phase2` 브랜치를 기준으로 **새 브랜치** `feature/v8-supervisor-phase2-windows-ci`를 생성합니다. 기존 PR #9 브랜치 자체를 수정하지 않습니다.
3. 이 패키지의 `repo-overlay/` **내부 내용만** 새 브랜치의 저장소 루트에 복사합니다. 하위 경로(`.github/workflows`, `core/supervisor`, `core/tests`, `windows/phase2`, `docs/v8`, `patches`)를 그대로 유지합니다. 기존 파일 충돌이나 예상 밖의 수정이 발생하면 즉시 중지합니다.
4. GitHub Desktop의 변경 목록을 검토합니다. 특히 `windows/phase2/Invoke-Phase2WindowsCILab.ps1`은 임시 사용자·서비스 생성/삭제가 있으므로 **Windows hosted runner에서만 실행**되는지 확인합니다.
5. 소유자 본인의 GitHub 인증 경로로 해당 개발 브랜치를 커밋하고 Publish합니다. **AI에게 소유자 인증정보·Push 권한을 주지 않습니다.**
6. GitHub 웹의 `Compare & pull request`를 눌러 **Draft Pull Request**를 생성합니다. **base: `feature/v8-environment-bootstrap-phase2` / compare: `feature/v8-supervisor-phase2-windows-ci`**가 정확해야 합니다. `main`을 base로 선택하지 마세요. 병합도 하지 마세요.
7. Actions/PR Checks에서 `Static contracts` → `Windows 2022 LocalService + distinct worker token` 순으로 실행되는지 확인합니다. 실기 실패 시 산출물 `j-harness-phase2-windows-evidence-unsigned`를 확인합니다. 아티팩트는 독립 증거가 아닌 **실행기 보고 자료**이며 서명되지 않았습니다.

## 성공 판정 요건

- Windows 2022 hosted runner임이 기록되어야 합니다. 일반 PC, self-hosted runner 실행은 허용하지 않습니다.
- SCM 서비스의 실제 계정이 `NT AUTHORITY\\LocalService`인 증거가 있어야 합니다.
- 별도 비관리자 사용자 SID 및 Trust Store / Workspace ACL이 독립 관측되어야 합니다.
- 보호된 정책·상태 파일 접근 및 변경은 ACCESS_DENIED여야 합니다.
- 일반 작업공간은 쓰기 가능해야 합니다.
- `toggle`, `change_policy`, `launch`, `deploy` 요청은 DENY여야 합니다.
- 서비스 종료 후 상태 클라이언트는 `BLOCKED / SUPERVISOR_UNREACHABLE`이어야 합니다.
- 임시 사용자·서비스·디렉터리 정리 결과가 PASS여야 합니다.
- 소스 SHA·컴파일된 서비스 SHA-256·CI 로그·아티팩트 기록을 함께 보존해야 합니다.

## 엄격한 한계

이 테스트는 **Windows 권한 경계의 실험**일 뿐입니다. 실제 Codex/Claude/AGY 세션, 인증 보호, Tool/MCP 전체 중개, 사용자 전용 토글 UI, 서명된 배포 설치, 프로젝트 외부 완전 격리까지 검증하는 것이 아닙니다. `PASS_WINDOWS_PHASE2_LIMITED_SCOPE_NO_CLI_ENFORCEMENT`만 허용하며 **제품 상태는 계속 NO-GO**입니다.

워크플로 조건에 적힌 소유자 로그인 값은 CI 실행 범위를 좁히는 필터일 뿐, 소유자 본인 직접 승인의 보안 증거가 아닙니다. 외부 자격증명·Windows 비밀·GitHub token을 Agent 프로세스에 제공하지 않습니다.

`GITHUB_*`/`RUNNER_*` 환경 변수 및 명시적 스위치는 오작동 예방용 실행 가드로, 보안 경계의 완전한 신원 인증이 아닙니다. **이 PowerShell 스크립트를 실제 사용자 PC에서 실행하지 마세요.**

## 근거 기록

- 사용자 PC/저장소/원본 릴리스 미변경, Windows 실기 NOT_RUN
- 로컬 Node: 37 PASS, 0 FAIL, 0 SKIP
- 현재 확인된 base PR #9 SHA: `d46653109020a170cc2ba4d1eff11585cee89eb5`
- PR #7 설계는 별도 Draft 상태. 이번 CI 후보는 해당 설계를 실제 OS 완성으로 주장하지 않음
