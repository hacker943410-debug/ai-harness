# Jev Decision Engine 통합 계획 — Harness 3.1

- 상태: **Phase 0~2 완료 — Global 기본 비활성 / 검증된 프로젝트 Shadow opt-in**
- 작성일: 2026-09-20
- 기준: 현재 `C:/AI-Harness`와 사용자가 제공한 「Codex CLI Harness 업데이트 지침서」
- 외부 조사: Phase 0/1은 수행하지 않음. Phase 2에서 Vercel 공식 Jev 가이드의 v4 typed 응답 계약을 확인함.

## 1. Harness Change Contract

Problem:

- 현재 Compact Router는 Task / Phase / Risk / Boundary를 분류하고 필요한 정책을 JIT로 고르지만, 제한된 의미 판단을 저비용 Decision Model에 맡기는 선택 경로는 없다.
- 실제 Model Router, Provider Adapter, Decision Telemetry 실행기는 존재하지 않는다.

Current Behavior:

```text
Fast Health Check
→ Parent Agent의 Task 분류
→ POLICY_INDEX 후보 선택
→ Materiality Filter
→ JIT Policy Load
→ 실행·검증·재분류
```

Proposed:

```text
Deterministic Rule
→ (선택·검증된 경우만) Jev constrained semantic decision
→ Existing Router / Reasoning Model
```

- Jev는 Advisor이며 Runtime Core, Project Rule, Security Guard의 권한을 넘겨받지 않는다.
- Jev가 없거나 꺼져 있거나 실패하거나 신뢰 기준을 충족하지 못하면 기존 Router가 그대로 동작한다.
- 첫 적용은 `enabled: false`, `mode: shadow`, threshold `CONFIG_REQUIRED`다.
- 실제 Provider 호출 코드는 Provider API 계약과 인증 방식이 확정되기 전에는 만들지 않는다.

Affected Task Classes:

- Task / Risk / Boundary / Policy 후보 분류
- Agent / Subagent / Model Tier 후보 선택 보조
- 정형 검증 뒤 남은 제한적 Continue / Retry / Stop 의미 판단

Expected Benefit:

- Parent Agent가 반복하는 제한적 분류 부담 감소
- 불필요한 Policy·Agent 설명 로드 감소
- JIT Context 선택 정밀화 가능
- 복잡한 Reasoning Model 호출 전 단계의 저비용 판단 경로 확보

Risk:

- 유효한 형식이지만 잘못된 판단
- Provider 장애·인증 실패·응답 지연
- Decision Model이 권한·보안·완료 판정을 과도하게 통제하는 구조로 번질 위험
- 실행기가 없는 상태에서 문서만 보고 Jev가 활성화됐다고 오인할 위험

Metric:

- 기존 경로와 Jev 추천의 일치 여부
- 최종 경로, override 이유, fallback 사용 여부
- 로드된 Context 크기, Reasoning 호출 수, Retry 수
- Task 성공과 사용자 수정 여부

Canary:

- Phase 1: 비활성
- Phase 2: Shadow only
- Phase 3: 낮은 위험의 제한된 Routing만 후보
- Continue / Retry / Stop은 별도 근거가 쌓인 뒤 검토

Rollback:

- Project 또는 Global 설정에서 `enabled: false`
- 설정·Provider가 없으면 기존 Router로 자동 복귀
- Jev 관련 문서·설정 제거 없이도 기존 흐름은 유지

## 2. 발견 결과

### 이미 있는 것

- `CORE.md` + `ROUTER.md` + `POLICY_INDEX.yaml` Compact Runtime
- Task / Phase / Risk / Boundary 분류
- Materiality Filter와 JIT Policy Loading
- P02의 Model Tier, Capability, Confidence, Escalation, Deterministic First 설계
- P06의 Evidence 기반 Verification / Completion / Retry 계약
- P17의 Security·Permission·Secret 경계
- Project-local Rule 우선순위와 기존 Fallback 역할

### 없는 것

- 실제 Model Registry와 Decision Provider Adapter
- Jev 호출 실행기
- Jev Feature Flag와 Shadow 비교 기록
- Decision Result의 typed contract를 강제하는 실행 코드
- Jev 전용 threshold calibration 자료

### 오래된 로컬 연결

- 현재 프로젝트의 `.ai/harness.yaml`은 Global 2.2와 은퇴한 Google Workspace 경로를 가리킨다.
- 실제 Global Harness는 3.0이며 이번 변경 뒤 3.1이 된다.
- 로컬 Bridge는 Global Root를 직접 가리키므로 Global 문서 변경은 즉시 보이지만, 구조화 설정과 현재 상태 기록은 별도 갱신이 필요하다.

## 3. 최소 변경 계획

| 파일 | 변경 | 이유 |
|---|---|---|
| `CORE.md` | Deterministic → optional Jev → Reasoning hierarchy와 권한 경계 | 모든 Runtime의 최소 계약 |
| `ROUTER.md` | Jev Advisor 조건, Shadow, fallback, compact input/output | JIT 앞의 유일한 통합 지점 |
| `POLICY_INDEX.yaml` | 3.1 버전과 기본 비활성 Decision Engine metadata | 상시 읽는 Compact 설정 |
| `workflows/DECISION_ENGINE.md` | 상세 계약의 단일 정본 | CORE/ROUTER 장문화 방지 |
| `README.md` | 역할과 단계식 도입 요약 | 사용자용 운영 설명 |
| `PROJECT_INIT.md` | 신규 Project Bridge의 기본 비활성 설정 | 프로젝트마다 같은 안전 기본값 |
| `HARNESS_DOCTOR.md` | Decision Engine 연결·보안·fallback 진단 | 활성화 오인 방지 |
| `PATCH_NOTES.md` | 3.1 변경과 제한 기록 | 버전 변경 이력 |
| 프로젝트 `.ai/harness.yaml` | 3.1 연결, 은퇴 경로 정리, Jev 비활성 | 현재 로컬 반영 |
| 프로젝트 `.ai/HARNESS.md` | Optional Decision Layer bridge | 새 Runtime 계약 전달 |
| 프로젝트 `.ai/current-state.md` | 실제 버전·비활성 상태 기록 | 오래된 2.2 주장 제거 |

## 4. 이번 단계에서 만들지 않는 것

- Jev HTTP endpoint 추측 구현
- Provider SDK 또는 Package 설치
- API Key 파일
- 근거 없는 confidence 숫자
- 가격 기반 Runtime 분기
- Jev가 보안 승인·삭제·배포·권한 상승을 결정하는 경로
- 새 Agent 또는 새 Policy 계층

## 5. Phase 2 진입 조건

다음이 모두 확정돼야 실제 호출기를 만든다.

1. 사용할 Provider 한 곳
2. 공식 요청·응답 계약
3. Secret 환경변수 이름과 저장 위치
4. timeout·rate limit·authentication failure 식별 방식
5. structured result schema
6. confidence calibration 자료 또는 수동 review-only 운영 기간
7. 실제 Shadow 로그 저장 위치와 보존 기간

## 6. 수락 조건

- Jev는 Coding/General Reasoning Model로 정의되지 않는다.
- Deterministic 판단이 항상 먼저다.
- `enabled: false`에서 기존 Runtime 흐름이 바뀌지 않는다.
- Shadow Mode에서는 기존 Router가 실제 경로를 결정한다.
- 실패·낮은 confidence·지원하지 않는 schema는 기존 Router/Reasoning으로 간다.
- JIT와 기존 Agent/Model 계층은 유지된다.
- Security-sensitive action 승인 권한은 Runtime Core와 Project Rule에 남는다.
- 가격과 confidence 숫자가 Runtime Logic에 하드코딩되지 않는다.
- 외부 조사 없이 Repository와 사용자 제공 정보만 사용한다.
