# J Harness v8 Supervisor Phase 2 — Windows 보안 경계 검증 설계/후보

- 작성일: 2026-11-04
- 연계 저장소: `hacker943410-debug/ai-harness`
- 개발 기준점: PR #9, `d46653109020a170cc2ba4d1eff11585cee89eb5`
- 병합/배포: 실행하지 않음. **후보 산출물만 존재.**
- 출시 판단: **NO-GO**

## 1. 이번에 실제 작성한 것

**Windows 전용 시제품 코드**를 작성했습니다.

1. Windows Service Control Manager(SCM)에서 LocalService 계정으로 가동하는 읽기 전용 상태 서비스.
2. 테스트용 `ProgramData/JHarnessPhase2LabParent_*/jh-phase2-lab-*` 구조. 부모, 정책 디렉터리, 상태 파일을 신뢰된 관리자/SYSTEM/LocalService와 분리하여 ACL로 보호. **Agent 계정에는 업무용 workspace의 Modify 권한만 부여**.
3. 다른 로컬 계정의 실제 일반 사용자 토큰으로 `policy.json` 읽기/쓰기, `state.json` 쓰기 및 일반 작업 폴더 쓰기 검증.
4. Windows Named Pipe에서 `status`는 읽기 전용으로 답하고, `toggle`·`change_policy` 등 변경 명령을 거부하는 서비스.
5. 프로브 전후 정책과 상태 파일 SHA-256 보존 확인.
6. SCM 서비스를 중단한 뒤 읽기 전용 상태 클라이언트 `Get-Phase2LabStatus.ps1`가 `BLOCKED / SUPERVISOR_UNREACHABLE`를 반환하는지 확인.
7. GitHub Windows 일회용 가상 실행기를 위한 수동 트리거 워크플로와 테스트 종료 후 서비스·계정·임시 폴더 삭제 로직.

서비스는 어떤 경우에도 `launchAuthorized=true`를 반환하지 않으며, `ENFORCED`라고 보고하지 않습니다. CLI 실행기, 도구 허가 및 사용자 인증된 토글 기능은 구현되지 않았습니다.

## 2. 필요한 실제 Windows 수용 테스트

| 검사 ID | 적대적 시나리오 | 기대값 | 현재 결과 |
|---|---|---|---|
| WIN-01 | Windows SCM 서비스가 LocalService로 기동 | 실제 서비스 ID `S-1-5-19`, `Running` | NOT_RUN |
| WIN-02 | 비관리자 별도 로컬 계정이 보호 정책 읽기 | AccessDenied | NOT_RUN |
| WIN-03 | 동일 계정이 보호 정책/토글 상태 쓰기 | AccessDenied | NOT_RUN |
| WIN-04 | 동일 계정이 프로젝트 Workspace 쓰기 | ALLOWED | NOT_RUN |
| WIN-05 | 동일 계정이 공개 IPC에서 toggle/policy 변경 시도 | DENY, 정책/상태 해시 불변 | NOT_RUN |
| WIN-06 | 공개 IPC의 status/doctor | BLOCKED / NOT_ATTESTED / launchAuthorized=false | NOT_RUN |
| WIN-07 | 서비스 중단·파이프 연결 실패 | 사용자 작업이 관리형으로 허가되지 않음 | NOT_RUN |
| WIN-08 | 테스트용 사용자/서비스/폴더 삭제 | 재확인 PASS, 실패 시 수동 검토 | NOT_RUN |
| WIN-09 | 실제 Codex Tool·Shell·MCP 우회 | 별도 도구 중개/샌드박스에서 차단 | NOT_IMPLEMENTED |
| WIN-10 | 인증된 사용자 ON/OFF 화면 | AI 사용자는 토글 불가 | NOT_IMPLEMENTED |

## 3. 무엇을 검증했다고 주장할 수 없는가?

- 아직 **Windows 서비스 컴파일, SCM 실행, 실제 ACL 차단은 한 번도 관측하지 않았습니다.** 로컬 테스트 33개는 Linux용 및 정적 코드 계약 테스트로, Windows OS 증거가 아닙니다.
- 일반 사용자 계정 분리는 **완전한 Windows 제한 토큰/Low Integrity/AppContainer 샌드박스가 아닙니다.** 파일 ACL의 일부 위협을 줄일 뿐, 일반 Windows 사용자의 네트워크 접속·프로세스·레지스트리·사용자 프로필 접근까지 막지 않습니다.
- 별도 계정으로 실행한다는 사실만으로 Codex/Claude/AGY가 그 계정 아래서 실행되는 것은 아닙니다. 현재 Agent Probe만 해당 계정으로 실행됩니다.
- 시스템 관리자나 보호된 자격증명을 획득한 공격자까지 차단한다는 보장은 없습니다. 지정한 임시 Lab 경계에 한정됩니다.
- 임시 파이프 인증, 재생 공격, 가짜 프로세스 바인딩, 서명 검증, 보안 감사를 포함하는 운영용 Supervisor는 아닙니다.
- 관리자/LocalService가 파일을 고의로 바꾸는 공격 모델에 대한 확실한 방어도 아닙니다.
- 분리된 GitHub 소유자 자격증명/릴리스 보안 통제를 이 코드 자체가 설정해 주는 것은 아닙니다.

## 4. CI 실행 안전 게이트

- `-IAmInDisposableGitHubWindowsRunner` 스위치와 `GITHUB_ACTIONS=true`, `RUNNER_OS=Windows`, `RUNNER_ENVIRONMENT=github-hosted`, `RUNNER_TEMP` 확인이 충족되어야만 테스트용 시스템 변경 진입.
- `workflow_dispatch`만 정의; PR/Push 자동 트리거 없음. GitHub-hosted Windows 2022에 한정한 후보.
- 지정된 라벨·GUID의 테스트 폴더와 마커만 정리. 다른 사용자 계정, 운영 서비스, 전역 PATH, 인증 파일을 변경하지 않음.
- `LocalService` 서비스가 조회만 가능하도록 IPC 프로토콜을 제한. GitHub의 `RUNNER_ENVIRONMENT` 기준으로 self-hosted 실행기는 거절. 서비스 종료와 파일 원본 해시 검사 포함.
- 테스트 실패, 종료 후 리소스 잔여, 실제 Windows 기록 누락은 **NO-GO**.
- GitHub CI Runner 설정, 작업 과정과 보호된 서비스 생성·삭제는 소유자가 분리된 신뢰 경계에서 승인한 경우에만 수행합니다.

## 5. 우선순위

1. 사용자가 코드와 `CANDIDATE` 워크플로를 검토한 뒤 GitHub 별도 개발 브랜치에 반영.
2. GitHub-hosted Windows 2022에서 **실제 SCM/Windows ACL 증적**을 생성. 빌드 오류나 실행 오류는 정확히 FAILED로 기록.
3. 해당 테스트 통과 후에도 즉시 제품 출시하지 않음. 보호된 Supervisor와 Codex CLI 실제 실행/Tool 경계, 감사 로그, 사용자 본인 확인 구현.
4. 이어서 Claude/AGY 어댑터 및 설치·서명·롤백 체계 통합. 세 구독을 모두 요구하지 않음.

**최종 판정: NO-GO.**

## 2026-11-05 — PR 전용 CI 보완

기존 `workflow_dispatch`만 있는 파일은 기본 브랜치 등록 문제로 실행되지 않을 수 있으므로, 별도 `.github/workflows/v8-supervisor-phase2-windows-ci.yml`를 새로 준비했습니다. 동일 저장소의 소유자 PR이 `feature/v8-environment-bootstrap-phase2`를 base로 하는 경우에만 CI를 실행합니다. `main` 병합 없이 검증할 수 있습니다. 독립 ACL 검사 및 기존 보호 파일 직접 쓰기·읽기 부정 테스트와 금지된 launch/deploy IPC 테스트도 보강했습니다.

로컬 Node 테스트 37 PASS이며 **실제 Windows 검증은 아직 NOT_RUN**입니다. 사용 절차는 `PHASE2_PR_CI_OWNER_CHECKLIST_KO.md`를 따릅니다.
