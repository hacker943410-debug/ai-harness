# AI Harness ROUTER

Document Version: 1.1
Harness Version Source: `POLICY_INDEX.yaml`의 `harness_version`
Purpose: 26개 정책 원문을 매번 읽지 않고 현재 Task에 필요한 정책만 JIT로 선택한다.
Canonical detail: 정책 03이 Router 자체의 상세 설계를 소유한다.

---

## 1. 절대 원칙

- 세션 시작 시 26개 정책 원문을 전부 읽지 않는다.
- POLICY_INDEX.yaml의 짧은 메타데이터로 먼저 분류한다.
- 정책 원문은 현재 행동을 실제로 바꿀 때만 읽는다.
- "관련 있을 수도 있음"만으로 전문 정책을 모두 로드하지 않는다.
- 반대로 Security / Migration / Destructive / External Contract 등 중요한 경계가 실제로 발견되면 늦지 않게 추가 로드한다.
- 기본 목표는 2~5개 정책 원문이지만, 위험한 작업에서 필요한 정책을 억지로 줄이지 않는다.

## 1.1 Runtime 진입과 Fast Health Check

Task routing 전에 `.ai/harness.yaml` 또는 `.ai/HARNESS.md`가 가리키는 `HARNESS_ROOT`를 기준으로 다음 Metadata Check만 수행한다.

1. Root 접근 가능
2. `CORE.md` 존재 및 읽기 가능
3. `ROUTER.md` 존재 및 읽기 가능
4. `POLICY_INDEX.yaml` 존재 및 파싱 가능
5. `policy_count == 26`
6. Index의 `paths.policies_dir`가 존재

이 Fast Check는 P01~P26 원문 전체 검사가 아니다. 전체 파일 매핑·Adapter·버전·참조·Secret 흔적 검사는 요청 시 `HARNESS_DOCTOR.md`를 JIT로 읽어 수행한다. Doctor는 전문 정책이 아니며 Pxx Active Policy 수에 포함하지 않는다.

Runtime Health 판정:

- `HEALTHY`: Fast Check 통과, 현재 Task에 필요한 정책 연결 사용 가능
- `DEGRADED`: 일부 비핵심 결함이 있으나 현재 Task를 안전하게 제한 수행 가능
- `BLOCKED`: Core/Router/Index를 신뢰할 수 없거나 현재 Task의 Critical Policy 파일이 없음

오류가 Task와 무관하다는 근거가 있을 때만 `DEGRADED`로 계속한다. Index가 선택한 Critical Policy가 없으면 그 내용을 추측하지 않고 `BLOCKED`로 보고한다. 예를 들어 Migration Task의 P16 또는 Security Task의 P17이 없으면 해당 변경을 진행하지 않는다.

---

## 2. Routing 입력

매 Task 시작 시 내부적으로 다음을 판단한다.

### TASK
예:
- question
- explanation
- code_navigation
- bug_fix
- feature_change
- refactor
- design
- project_planning
- migration
- security
- external_contract
- harness_change

### PHASE
- DISCOVERY
- SPEC
- PLANNING
- IMPLEMENTATION
- VERIFICATION
- HANDOFF
- REVIEW

### RISK
- LOW
- MEDIUM
- HIGH
- CRITICAL

### BOUNDARIES
현재 확인된 것만:
- UI
- API
- BACKEND
- DATABASE
- EXTERNAL_SERVICE
- AUTHORIZATION
- SECRET
- INFRASTRUCTURE
- SHARED_CODE
- MULTI_AGENT
- DESIGN
- NONE

---

## 3. 정책 선택 단계

### Step A — Always-loaded compact files
이미 읽은 것으로 간주:
- CORE.md
- ROUTER.md
- POLICY_INDEX.yaml

정책 03 원문 자체는 정상 Task마다 다시 읽지 않는다.

### Step B — Task 후보 선택
POLICY_INDEX.yaml의 `triggers`와 `candidate_bundles`를 사용해 후보를 만든다.

### Step C — Materiality Filter
각 후보에 질문한다.

1. 이 정책을 읽으면 현재 행동이나 판단이 달라지는가?
2. 현재 Phase에서 실제로 적용되는가?
3. 이미 CORE/Index 요약만으로 충분한가?
4. 해당 위험 경계가 실제로 존재하는가, 단순 가능성뿐인가?

`YES`가 충분히 명확한 정책만 원문을 읽는다.

### Step D — Execute
선택 정책의 규칙에 따라 작업한다.

### Step E — Re-route
작업 중 다음이 발견되면 다시 분류한다.

- schema / data / persisted state 변화
- auth / permission / tenant / secret
- 새로운 package / SDK / 외부 API 계약
- architecture-level 선택
- 예상 밖 shared impact
- plan invalidation
- 반복 실패
- multi-agent / parallel 필요성

---

## 4. 기본 Routing 예시

### A. 단순 설명
예: "이 코드가 무슨 뜻이야?"

보통 원문 정책:
- 09가 실제로 쉬운 설명이 필요할 때
- 11이 불확실성/추론 구분이 중요한 경우

코드 변경이 없으면 04/06/26을 자동 로드하지 않는다.

### B. 작은 코드 수정
예: 라벨 변경, 로컬 조건문 수정

후보:
- 04 변경 범위
- 06 검증
- 26 코드베이스 실행

사용자 의도 충돌이 없으면 14 원문까지 항상 읽을 필요는 없다. CORE가 최소 의도 보존을 담당한다.

### C. 일반 Bug Fix
후보:
- 04
- 06
- 21 (여러 단계면)
- 26
- 11 (Root Cause에 불확실성이 큰 경우)

### D. 일반 Feature
후보:
- 04
- 06
- 10
- 21
- 26

Requirement가 이미 완전히 확정되었으면 07은 생략한다.

### E. 주관적 UI/디자인
후보:
- 07
- 10
- 12
- 14

실제 코드 수정 단계에 들어갈 때:
- 04
- 06
- 26
를 필요에 따라 추가한다.

### F. External API / Package / SDK
추가:
- 15

버전·계약·Lockfile 변경이 실제로 없으면 15 Full Load가 필요 없는지 다시 판단한다.

### G. DB / Schema / Data Migration
추가:
- 16

보통:
- 04
- 06
- 16
- 26

Security 경계도 있으면 17 추가.

### H. Auth / Permission / Secret / Tenant
추가:
- 17

보통:
- 04
- 06
- 17
- 26

### I. Architecture Decision
후보:
- 18
- 21
- 25 (기존 계획 변경 시)
- 01 또는 02 (Harness/Codebase architecture 자체일 때만)

### J. 장기 프로젝트
후보:
- 20 Roadmap
- 21 Active Plan
- 24 Progress

의존성과 병렬 실행이 실제로 복잡할 때만:
- 22

### K. Scope가 새기 시작함
- 23

현재 Plan 자체가 Evidence 때문에 틀린 경우:
- 25

### L. 오류 발생 후 학습
- 08

Lesson이 반복되거나 자동화 후보가 됨:
- 13

Harness 자체의 품질 개선:
- 19

---

## 5. Full Policy를 정상 Task에서 자주 열지 말아야 하는 문서

### 정책 01
일반 Coding Task에서는 26을 사용한다.
01은 다음에만 주로 읽는다.
- Code Map bootstrap
- Feature Map schema
- Indexer
- MCP
- Map validator
- Codebase Knowledge System architecture

### 정책 02
일반적으로 Subagent에게 02 전체를 전달하지 않는다.
필요한 Role / Objective / Constraints / Output만 Task Packet으로 전달한다.
02 Full Load는 Multi-Agent Harness 구조 자체를 설계·수정할 때 우선한다.

### 정책 03
ROUTER.md가 Compact Runtime Router 역할을 한다.
03 Full Load는 Router 설계 변경, 충돌, 디버깅, 평가 시 사용한다.

### 정책 19
일반 Feature 구현용 정책이 아니다.
Harness / Router / Model / Policy / Validator 성능을 평가할 때 읽는다.

---

## 6. Policy Load 상태

내부적으로 다음 셋 중 하나로 관리할 수 있다.

- INDEX_ONLY: POLICY_INDEX의 목적/Trigger만 인지
- ACTIVE: 원문을 읽고 현재 Task에 적용
- RELEASED: Phase가 끝나 상세 원문은 Working Context에서 제거하고 필요한 결정만 보존

`ACTIVE`가 많을수록 좋은 것이 아니다.

기본 Trace Mode는 `record_only`다. 사용자 응답마다 장황하게 출력하지 않고, 프로젝트가 상태 파일을 사용하면 `.ai/current-state.md`에 다음만 짧게 보존한다.

- Active Policies: Policy ID
- Policy Load Reason: ID별 선택 이유
- New Boundary Trigger: 재라우팅을 일으킨 경계
- Released Policies: 해제된 Policy ID

정책 전문, Secret, Credential, 긴 Tool Output은 Trace에 복사하지 않는다. 사용자가 요청하거나 Harness Debug / Doctor / Router 분석을 수행할 때만 Trace Mode를 `display`로 취급해 현재 기록을 보여준다.

---

## 7. Scope별 기본 후보 Bundle

Bundle은 "자동 전체 로드"가 아니라 후보 집합이다.

- QUICK_CODE_CHANGE → [04, 06, 26]
- BUG_FIX → [04, 06, 11, 21, 26]
- FEATURE → [04, 06, 10, 21, 26]
- DESIGN → [07, 10, 12, 14]
- EXTERNAL_CONTRACT → [04, 06, 15, 26]
- MIGRATION → [04, 06, 16, 26]
- SECURITY_CHANGE → [04, 06, 17, 26]
- LONG_PROJECT → [20, 21, 24]
- PARALLEL_WORK → [02, 21, 22]
- REPLAN → [11, 21, 23, 25]
- FAILURE_LEARNING → [08, 13]
- HARNESS_CHANGE → [02, 03, 18, 19]
- CAPABILITY_ACQUISITION → [06, 15, 23]
- CAPABILITY_WITH_AUTH → [06, 15, 17, 23]

Materiality Filter를 적용해 실제 ACTIVE 정책은 더 적을 수 있다.

### Capability Boundary

현재 Agent의 내장 도구, 프로젝트의 기존 CLI/Package/Script, 이미 설치된 MCP/Skill로 현재 Goal을 안전하게 달성할 수 없을 때만 `TOOL_CAPABILITY_GAP`을 선언한다.

- `MCP_DISCOVERY` → P15, 권한·Credential이 있으면 P17 추가
- `SKILL_DISCOVERY` → P15
- `PROJECT_TOOL_INSTALL` → P06, P15, P23
- `REMOTE_MCP_AUTH` → P15, P17
- `TOOL_VERSION_DRIFT` → P11, P15, 필요 시 P25
- `TOOL_INSTALL_FAILED` → P08, P15
- `PRODUCTION_CAPABILITY` → P15, P17 및 명시적 실행 경계 확인

실제 획득 절차는 `<HARNESS_ROOT>/workflows/CAPABILITY_ACQUISITION.md`를 JIT로 읽는다. Catalog 전문은 preload하지 않고 `<HARNESS_ROOT>/catalogs/`를 검색한다. 기존 Capability로 충분하면 새 MCP/Skill을 설치하지 않는다.

---

## 8. Routing 출력 형식

필요할 때 내부적으로만 짧게 유지:

```text
ROUTING
Task:
Phase:
Risk:
Boundaries:

Active Policies:
- Pxx — 이유

Index Only:
- Pyy — 원문까지는 불필요

New Trigger Watch:
- DATABASE
- SECURITY
- EXTERNAL_CONTRACT
...
```

사용자가 별도로 요구하지 않는 한 매번 이 표를 장황하게 출력할 필요는 없다.

---

## 9. Policy Precedence와 Conflict 처리

이 절은 Harness 내부 충돌 해결 순서의 Canonical Owner다. Material Conflict가 생기면 다음 순서로 적용 가능성을 검토한다.

1. 적용 가능한 System / Platform / Safety 제약
2. 현재 사용자의 명시적 요청과 금지사항
3. 현재 프로젝트의 더 구체적이고 확정된 Local Rule / Locked Spec
4. Safety / Security / Data Loss / Destructive Operation Guard
5. 현재 Task에 ACTIVE인 전문 JIT Policy
6. CORE의 일반 원칙
7. Agent의 일반적인 선호나 추론

이 순서는 상위 플랫폼 제약을 프로젝트 파일이나 사용자 요청으로 우회한다는 뜻이 아니다. Global Policy와 Project-local Rule이 충돌하면 일반적으로 더 구체적인 Project Rule을 우선 검토하되, Secret Protection, Security Boundary, Data Loss 방지, Destructive Guard를 Local Rule만으로 자동 약화하지 않는다.

현재 사용자의 요청은 과거 Project Preference보다 우선할 수 있다. 실제 Source / Runtime / Test Evidence는 오래된 Map, 상태 기록, AI 기억보다 우선한다.

해결되지 않는 Material Conflict나 실제 Business Decision은 조용히 임의 확정하지 않는다. 충돌 항목, 적용 가능한 제약, 필요한 사용자 결정을 명시한다.

---

## 10. 종료 조건

현재 Phase가 끝나면:

- 더 이상 필요 없는 정책 원문은 RELEASED
- 결정·검증결과·Blocker만 State/Checkpoint에 남김
- 새로운 Task가 시작되면 다시 Index에서 선택

따라서 26개 정책은 "항상 메모리에 넣는 Prompt"가 아니라 "필요할 때 호출하는 운영 매뉴얼"이다.
