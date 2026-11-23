# Changelog

## J Harness 8.2.3

- 대화 차례마다 첫 안내나 응답에 버전 표시를 한 번 출력하도록 프로젝트 지침을 추가했습니다. 초기 `badge` 확인 결과와 지침 로드 상태를 구분하고, 고정 출력 형식은 보존합니다.
- 8.2.2 프로젝트의 업데이트와 중단 후 복구를 지원합니다.

[8.2.3 설치·업데이트 안내와 검증 범위](docs/releases/v8.2.3.md)

## J Harness 8.2.2

- `environment inspect`와 `environment plan`이 프로젝트에 저장한 AI CLI를 기본으로 점검합니다. `--client`는 해당 명령에만 적용됩니다.
- GitHub 설치기에서 기존 프로젝트에 대한 업데이트 계획, 적용, 복구를 지원합니다. `8.2.1`에서의 전환을 추가하고, ZIP 안의 안내서에 Windows PowerShell에서 바로 실행할 수 있는 업데이트·복구 명령을 적었습니다.

[8.2.2 설치·업데이트 안내와 검증 범위](docs/releases/v8.2.2.md)

## J Harness 8.2.1

- 새 설치 후 첫 `quickstart`에서 Codex, Claude Code, AGY 중 사용할 CLI를 고릅니다. 선택은 프로젝트에 저장하고, 이후에는 해당 CLI의 설정 및 첫 요청을 안내합니다.
- 공개 Alpha 3, 검증한 8.1.0과 8.2.0 이동형 배포본에 대해 프로젝트 업데이트와 중단 후 복구를 지원합니다.

## J Harness 8.2.0

- Claude Code의 프로젝트 지침 연결을 추가하고, `doctor`에서 공통 지침과 CLI별 지침 상태를 보고합니다.
- 번들 Node를 22.23.5로 보안 업데이트했습니다. 이동형 안내서 무결성 검사, 런처의 Node 시작 환경 격리, 검증 로그의 민감한 값 마스킹을 보강했습니다.

## J Harness 8.1.0

- 선택한 CLI 하나로 환경 점검, 첫 기능 구현, 실제 테스트와 초보자용 인계까지 진행하는 이동형 흐름을 추가했습니다.
- Alpha 3에서의 업데이트·복구, 작업별 실행 기록, 변경 후 이전 검증 결과 무효화, Windows 경로와 명령 인수 처리를 보강했습니다.

## J Harness 8.0.0-alpha.3

- Windows 프로젝트 이동형 배포를 기본 설치로 제공했습니다. 버전과 ZIP 해시를 고정하고, 프로젝트에 런타임과 지침을 설치했습니다.

[버전별 변경 배경, 사용법과 검증 범위](docs/releases/v8.2.1.md)

## 7.0.0 — 2026-10-13

- First-party official Roblox Studio Agent Plugin discovery, safe Codex MCP doctor and Studio session evidence consistency gate.
- Rojo/Rokit/Luau template, opt-in static build/lint checks, Roblox capability permission model, PROJECT ETERNAL game requirements.
- Expand installation and CLI operations manual, live test evidence consistency gate (strictly untrusted), negative tests and full Windows/Linux plus v6.2 regression coverage.
- Consolidate all six branch histories and port separate-client Skill integrity tracking into the current transactional installer without removing Force protection or rollback.
- Preserve v6.2 token/guard/verification architecture and all 26 policies. Actual local Studio read/edit/play/console/screenshots, source reconciliation, restoration and a two-client StudioTestService run were observed; the user reviewed original private evidence.
- Synchronize 7.0.0 identity and add Windows/Linux verification plus operator-review/runtime-hash publication gates. Tags remain immutable. PROJECT ETERNAL gameplay and production DataStore behavior remain outside the tested starter scope.

## 6.2.0 — release candidate (final CI validation required)

- Wire existing Jev decision executor to opt-in project Shadow activation, safe Vercel Gateway live canary, guarded Codex execution and typed offline regression tests.
- Keep global Jev disabled by default; preserve fallback, explicit consent and synthetic-only provider state.
- Update Jev HTTP call to Vercel documented `/v1/evaluate` contract; provider live testing still required.
- Include previously staged v6.1 changes; no release version bump until Codex verifies.

## 6.0.0

- Add executable sixteen-phase lifecycle and evidence, acceptance, review, release and production gates.
- Add four project modes, independent development state, beginner guidance, decision/risk profiles and delta-first maintenance.
- Add self-contained install/adoption/update route, source manifest/version agreement, read-only plans, immutable source pins, transactional project checkpoint/freeze/rollback/audit/backfill/resume.
- Preserve 26 policies, existing machine runtime/client installers, dashboard Skill and disabled-by-default Jev advisor.
- Add token/model/reasoning profiles, compaction actions, bounded role packets, benchmark cases and evidence/traceability.
- Validation and measured benchmark are linked from harness/build-log.md; unsupported real production/model/novice outcomes remain explicit limitations.

## 5.1.0

See CLI_PATCH_NOTES_V5_1.md and historical PATCH_NOTES.md for native Skill integrity and safe source update fixes.
