# AI Harness — PROJECT INIT

Version: 3.1
Mode: One-time project initializer
Audience: Coding Agent / CLI Agent
Execution: 새 프로젝트 또는 Harness 연결을 재설정할 때만 실행
Official Filename: `PROJECT_INIT.md`

---

# 0. 임무

현재 작업 디렉터리에 Global AI Harness를 연결하라.

이 파일은 **프로젝트 최초 초기화용**이다.

정상 초기화 후 일반 Task마다 이 파일을 다시 읽지 않는다.

26개 정책 원문을 프로젝트로 복사하거나 전부 preload하지 않는다.

`BOOTSTRAP.md`를 공식 설치 파일명이나 Runtime 진입점으로 만들지 않는다. 기존 `BOOTSTRAP.md`가 발견되면 사용 여부와 참조를 먼저 확인하고 임의 삭제하지 않는다.

---

# 1. HARNESS_ROOT 결정

기본적으로:

```text
HARNESS_ROOT = 이 PROJECT_INIT.md가 위치한 디렉터리
```

로 간주한다.

사용자가 명시적으로 다른 Harness Root를 지정한 경우 그 경로를 사용한다.

HARNESS_ROOT에는 최소 다음이 존재해야 한다.

```text
CORE.md
ROUTER.md
POLICY_INDEX.yaml
HARNESS_DOCTOR.md
policies/
```

`CORE.md`, `ROUTER.md`, `POLICY_INDEX.yaml` 또는 `policies/`가 없으면 존재하지 않는 내용을 추측하지 말고 초기화 `BLOCKED`로 보고한다. `HARNESS_DOCTOR.md` 누락은 진단 기능 결함으로 명시하고 설치 안전성에 미치는 영향에 따라 `DEGRADED` 또는 `BLOCKED`로 판정한다.

---

# 2. 먼저 Harness 자체를 검증

다음을 확인한다.

```text
HARNESS_ROOT/
├─ CORE.md
├─ ROUTER.md
├─ POLICY_INDEX.yaml
├─ HARNESS_DOCTOR.md
└─ policies/
```

검증:

1. CORE.md 읽기 가능
2. ROUTER.md 읽기 가능
3. POLICY_INDEX.yaml 읽기 및 YAML 파싱 가능
4. Index의 `harness_version`을 Global Version Source로 읽을 수 있음
5. Index에 `policy_count = 26`
6. P01~P26 존재
7. 각 Index의 `file`이 `policies/` 실제 파일과 일치하고 선두 제목이 해당 `purpose`와 명백히 어긋나지 않음
8. `HARNESS_DOCTOR.md` 존재 및 읽기 가능

초기화 단계에서 26개 정책 원문 내용을 전부 읽지 않는다.

파일 존재/경로 확인만 하면 되는 경우 전문 내용을 열지 않는다.

이 단계는 Doctor의 설치 필수 Subset이다. Full Doctor의 전체 항목을 Initializer에 복제하지 않는다.

---

# 3. 현재 Project Root 식별

현재 Working Directory를 기준으로 Project Root를 판단한다.

가능하면 다음 Evidence를 사용한다.

```text
.git/
package.json
pyproject.toml
Cargo.toml
go.mod
pom.xml
build.gradle
*.sln
*.csproj
기존 AGENTS.md
기존 CLAUDE.md
기존 GEMINI.md
```

아무것도 없는 빈 디렉터리라면 현재 디렉터리를 Project Root로 사용한다.

상위의 다른 Repository를 실수로 수정하지 않는다.

---

# 4. 기존 프로젝트를 보존

초기화는 기존 프로젝트 규칙을 파괴하지 않는다.

다음 파일이 존재할 수 있다.

```text
AGENTS.md
CLAUDE.md
GEMINI.md
README.md
CONTRIBUTING.md
.ai/
```

기존 파일을 통째로 덮어쓰지 않는다.

기존 Instruction과 Global Harness가 충돌할 수 있으므로 먼저 읽고 보존해야 할 프로젝트 고유 규칙을 확인한다.

---

# 5. 생성할 최소 Project Harness 구조

기본적으로 다음만 필요하다.

```text
<Project Root>/
└─ .ai/
   ├─ HARNESS.md
   ├─ harness.yaml
   └─ current-state.md
```

다음은 처음부터 만들지 않는다.

```text
active-plan.md
active-spec.md
roadmap.md
task-dag.md
decisions/
maps/
learning/
```

실제 Task가 필요로 할 때 관련 JIT Policy에 따라 생성한다.

---

# 6. `.ai/harness.yaml` 생성/갱신

목적:
Global Harness 위치와 Runtime 계약을 구조적으로 기록한다.

권장 내용:

```yaml
schema_version: "1.0"

harness:
  version: "<GLOBAL_HARNESS_VERSION>"
  initialized_with: "<GLOBAL_HARNESS_VERSION>"
  root: "<HARNESS_ROOT>"
  core: "CORE.md"
  router: "ROUTER.md"
  policy_index: "POLICY_INDEX.yaml"
  doctor: "HARNESS_DOCTOR.md"
  policies_dir: "policies"
  policy_count: 26

runtime:
  preload_all_policies: false
  use_jit_policy_loading: true
  fast_health_check: true
  policy_load_trace: "record_only"
  default_target_active_policies: "2-5"

decision_engine:
  workflow: "workflows/DECISION_ENGINE.md"
  engine: "jev"
  enabled: false
  mode: "shadow"
  provider: "CONFIG_REQUIRED"
  model: "CONFIG_REQUIRED"
  confidence:
    auto_accept: "CONFIG_REQUIRED"
    reasoning_review: "CONFIG_REQUIRED"
  fallback: "existing_router"

project:
  harness_bridge: ".ai/HARNESS.md"
  current_state: ".ai/current-state.md"
```

실제 HARNESS_ROOT를 기록한다.

`harness.version`은 초기화 시 읽은 `POLICY_INDEX.yaml`의 현재 `harness_version`을 기록한다. `initialized_with`는 새 Project에서는 같은 값으로 만들고, 이후 일반 재연결에서는 기존 값을 보존한다. 실제 구조 Migration을 수행한 경우에만 해당 Migration에 사용한 Version으로 갱신한다.

Global Version과 `initialized_with`가 다르다는 사실만으로 오류라고 단정하지 않는다. Compatibility 판단은 Doctor가 현재 구조와 함께 보고한다.

기존 `harness.yaml`이 있다면 알 수 없는 사용자 설정을 삭제하지 않는다.
Harness 관리 필드만 안전하게 병합한다.

---

# 7. `.ai/HARNESS.md` 생성/갱신

이 파일은 **프로젝트에서 사용하는 Canonical Harness Bridge**다.

다음 의미를 반드시 포함한다.

```text
GLOBAL HARNESS ROOT:
<실제 HARNESS_ROOT>

이 프로젝트는 Global AI Harness를 사용한다.

일반 Task 시작 시 26개 정책 원문을 전부 읽지 않는다.

먼저:
1. <HARNESS_ROOT>/CORE.md
2. <HARNESS_ROOT>/ROUTER.md
3. <HARNESS_ROOT>/POLICY_INDEX.yaml

만 Runtime 기준으로 사용한다.

Task routing 전에 Root, CORE, ROUTER, Index parse, policy_count,
policies directory만 Fast Health Check한다.
일반 Task에서 P01~P26 원문 전체를 검사하지 않는다.

상세 Policy Precedence는 ROUTER.md를 따른다.
핵심 Runtime을 신뢰할 수 없거나 현재 Task의 Critical Policy가 없으면 BLOCKED,
현재 Task와 무관한 비핵심 결함만 있으면 제한적으로 DEGRADED로 동작한다.
없는 정책 내용을 추측하거나 검증하지 않은 상태를 HEALTHY라고 하지 않는다.

그 후 현재 Task를 Task / Phase / Risk / Boundary로 분류하고
POLICY_INDEX와 ROUTER를 사용해 현재 행동에 실제 필요한 정책만
<HARNESS_ROOT>/policies/에서 JIT로 읽는다.

판단은 Deterministic Rule을 먼저 사용한다. 제한된 의미 판단에 Jev를 사용할 수 있지만
기본값은 비활성이고 최초 모드는 shadow다. Jev는 추천만 하며 Runtime Core가 최종 권한을 가진다.
Jev가 비활성·미설정·실패·저신뢰 상태이면 기존 Router/Reasoning 경로로 Fallback한다.
실제 Provider 호출 계약은 필요할 때 <HARNESS_ROOT>/workflows/DECISION_ENGINE.md를 JIT로 읽는다.

기본 목표는 보통 2~5개의 전문 정책이며 강제 상한은 아니다.

작업 중 새로운 Boundary가 발견되면 Router를 다시 실행한다.

- Database / Schema / Migration → P16
- Auth / Permission / Tenant / Secret / IAM → P17
- Package / SDK / External API → P15
- Durable Architecture Decision → P18
- Scope Drift → P23
- Existing Plan Invalidated → P25
- Repeated Failure → P08/P13

P01은 Codebase Map/Indexer/MCP 자체를 구축·수정할 때 주로 사용한다.
일반 Coding Task의 코드 탐색은 P26을 사용한다.

P02 전체를 일반 Subagent마다 반복 전달하지 않는다.
Subagent에는 필요한 Role, Objective, Constraints, Context Refs, Output Contract만 전달한다.

P03 전체는 Router를 설계·디버깅할 때 주로 사용한다.
정상 Runtime에서는 ROUTER.md가 Compact Router 역할을 한다.

작업이 끝난 Phase의 전문 정책 원문은 계속 재로드하지 않고
필요한 Decision / Evidence / Blocker만 Project State에 압축 보존한다.

Policy Load Trace의 기본 모드는 record_only다.
State에는 Policy ID, Load Reason, New Boundary Trigger, Released Policy만 짧게 기록한다.
사용자 요청 또는 Harness Debug / Doctor / Router 분석 때만 display한다.

`.ai` 상태, Plan, Spec, Decision, Map, Learning, Trace, Checkpoint, Handoff에는
Secret이나 Credential 실제 값을 저장하지 않는다.
필요하면 환경변수명 또는 승인된 Secret Store 참조만 기록한다.

사용자가 Harness Doctor를 요청하면 <HARNESS_ROOT>/HARNESS_DOCTOR.md를 읽고
기본 Read-only 진단을 수행한다. 이 문서는 P27이 아니며 전문 정책 수에 포함하지 않는다.

실제 Source / Runtime / Test Evidence가 AI의 추측이나 오래된 Map보다 우선한다.
검증하지 않은 것을 완료라고 주장하지 않는다.
```

이 파일에 26개 전문 정책의 전문을 복사하지 않는다.

---

# 8. `current-state.md` 초기화

파일이 없다면 최소 Template만 만든다.

```markdown
# Current Project State

Status: INITIALIZED

Harness Runtime:
- Health: <HEALTHY | DEGRADED | BLOCKED | NOT_CHECKED>
- CORE: <loaded | unavailable | not_checked>
- ROUTER: <loaded | unavailable | not_checked>
- INDEX: <loaded | unavailable | not_checked>

Current Goal:
- Not set

Current Phase:
- Not set

Active Task:
- None

Active Policies:
- None

Policy Load Reasons:
- None

New Boundary Triggers:
- None

Released Policies:
- None

Confirmed Decisions:
- None

Material Unknowns / Blockers:
- None

Next Step:
- Await user task
```

이미 존재한다면 사용자 상태를 덮어쓰지 않는다.

초기화 검증 뒤 실제 결과로 `Harness Runtime`만 갱신할 수 있다. 확인하지 않은 값을 `HEALTHY` 또는 `loaded`로 기록하지 않는다. 이 파일을 포함한 `.ai` 상태에는 Secret이나 Credential 실제 값을 기록하지 않는다.

---

# 9. CLI Adapter 전략

목표는 각 CLI의 자동 Context 파일에 **얇은 Bridge만** 두는 것이다.

26개 정책을 Adapter에 복제하지 않는다.

## 9.1 현재 CLI를 신뢰성 있게 식별할 수 있을 때

현재 실행 환경이 명확하다면 그 CLI의 Adapter만 우선 생성/갱신한다.

대표 기본 파일명:

```text
Codex 계열      → AGENTS.md
Claude Code     → CLAUDE.md
Gemini CLI      → GEMINI.md
```

현재 CLI의 실제 설정/프로젝트 규칙이 다른 파일명을 사용하도록 구성되어 있으면 실제 설정을 따른다.

## 9.2 여러 CLI를 함께 사용할 프로젝트

프로젝트에서 Codex/Claude/Gemini를 번갈아 사용할 것이 명확하다면 여러 Adapter를 만들 수 있다.

## 9.3 CLI를 식별할 수 없을 때

추측으로 프로젝트 고유 규칙을 교체하지 않는다.

기존 Adapter가 있으면 해당 Adapter를 사용한다.

아무 Adapter도 없고 현재 도구가 어떤 파일을 자동 로드하는지 확정할 수 없다면:

1. `.ai/HARNESS.md`와 `.ai/harness.yaml`까지는 생성한다.
2. 현재 Agent가 실제로 사용하는 Instruction file을 확인 가능한 Evidence가 있으면 사용한다.
3. 확인 불가하면 임의의 "자동 로드된다"는 주장을 하지 않는다.
4. 초기화 결과에 Adapter 미확정을 명시한다.

---

# 10. Adapter Managed Block

기존 Adapter가 있어도 전체를 덮어쓰지 않는다.

다음 Marker 사이만 Harness가 관리한다.

```text
<!-- AI-HARNESS:START -->
...
<!-- AI-HARNESS:END -->
```

정확히 한 쌍의 Marker가 이미 존재하면 해당 Block만 교체한다.

Marker가 여러 쌍이거나 시작/끝 Marker 수가 다르면 기존 내용을 보존하고 Doctor Warning으로 보고한다. 임의로 모든 Block을 삭제하거나 합치지 않는다.

Marker가 없으면 기존 문서 의미를 보존하면서 적절한 위치에 Block 하나만 추가한다.

권장 Block:

```markdown
<!-- AI-HARNESS:START -->
## Global AI Harness

이 프로젝트의 공통 AI 실행 규칙은 `.ai/HARNESS.md`를 따른다.

작업을 시작할 때 `.ai/HARNESS.md`를 읽고,
그 문서가 가리키는 Global `CORE.md`, `ROUTER.md`,
`POLICY_INDEX.yaml`을 기준으로 현재 Task에 필요한 정책만 JIT로 적용한다.

`policies/`의 26개 전문 정책을 한 번에 preload하지 않는다.

프로젝트 고유 규칙과 이 Harness가 충돌하면
충돌을 숨기지 말고 적용 가능한 상위/더 구체적인 제약을 확인한다.
<!-- AI-HARNESS:END -->
```

---

# 11. Gemini Adapter 최적화

현재 Gemini CLI가 `GEMINI.md` Import를 지원하는 환경이면,
중복 문구 대신 `.ai/HARNESS.md`를 import하는 얇은 Block을 사용할 수 있다.

예:

```markdown
<!-- AI-HARNESS:START -->
@./.ai/HARNESS.md
<!-- AI-HARNESS:END -->
```

단, 현재 환경이 해당 Import 문법을 지원한다는 Evidence가 있을 때만 사용한다.

26개 policies 전체를 import하지 않는다.

---

# 12. Codex Adapter 원칙

`AGENTS.md`를 사용하는 환경이면 Managed Block에서 `.ai/HARNESS.md`를 먼저 읽도록 지시한다.

Global 26개 정책을 `AGENTS.md` 전문에 복사하지 않는다.

기존 하위 디렉터리별 `AGENTS.md`가 있다면 해당 Scope의 더 구체적인 프로젝트 규칙을 보존한다.

---

# 13. Claude Adapter 원칙

`CLAUDE.md` 또는 현재 Claude Code 설정에서 사용하는 Project Instruction 파일을 사용한다.

기존 Project Memory/Instruction을 지우지 않는다.

Harness Managed Block만 추가한다.

현재 CLI가 파일 import 기능을 지원하는 것이 확인되면 `.ai/HARNESS.md`를 직접 연결할 수 있으나, 확인되지 않은 문법을 만들어내지 않는다.

---

# 14. 프로젝트가 빈 디렉터리인 경우

빈 프로젝트라도 과도한 Scaffold를 생성하지 않는다.

Harness 관점에서는:

```text
.ai/HARNESS.md
.ai/harness.yaml
.ai/current-state.md
현재 CLI Adapter
```

까지만 생성하면 초기화 완료로 볼 수 있다.

소스코드 Framework, package manager, build system은 사용자의 실제 프로젝트 요구가 나오기 전 임의 선택하지 않는다.

MCP/Skill용 `.ai/capability-lock.json`과 `.ai/mcp/desired.json`도 초기화 시 미리 만들지 않는다. 실제 작업에서 Capability Gap이 확인되고 첫 프로젝트 로컬 도구를 설치·설정할 때 생성한다.

---

# 15. 프로젝트가 기존 Repository인 경우

초기화 중 다음을 조사한다.

- 기존 프로젝트 Instruction
- Repository root
- 주요 build/test entry
- 기존 `.ai` 또는 Agent configuration
- 프로젝트 고유 규칙 충돌

하지만 Codebase 전체를 분석하거나 P01~P26 전체를 읽지는 않는다.

Codebase Map을 실제로 구축하라는 요청이 없으면 P01 Full Load를 하지 않는다.

---

# 16. 설치 중 정책 JIT 사용

Initializer 자체도 필요한 정책만 사용한다.

기본적으로 CORE / ROUTER / POLICY_INDEX로 충분하다.

다음 상황에서만 추가 정책을 읽는다.

- 기존 프로젝트 파일 변경 영향이 복잡함 → P04
- 기존 Project Instruction과 충돌 → P14 / 필요 시 P11
- Harness Router 자체 문제가 발견됨 → P03
- Harness Architecture를 수정해야 함 → P02 / P19
- Codebase Map을 최초 구축하라는 명시 요구 → P01

초기화라고 26개를 모두 읽지 않는다.

---

# 17. Idempotency

이 Initializer는 다시 실행해도 프로젝트를 망가뜨리지 않아야 한다.

재실행 시:

```text
기존 .ai/HARNESS.md
→ Harness 관리 내용만 갱신

기존 .ai/harness.yaml
→ Harness 관리 필드만 갱신
→ initialized_with는 구조 Migration이 없으면 보존

기존 Adapter
→ AI-HARNESS Marker 내부만 갱신
→ Marker가 정확히 한 쌍일 때만 자동 갱신

기존 current-state.md
→ 보존
```

불필요한 중복 Block을 만들지 않는다.

---

# 17.1 PC 공용 Google Workspace MCP 자동 연결

Harness 초기화 시 `runtimes/google-workspace.runtime.json`이 존재하면 다음 순서로 처리한다.

1. `scripts/Resolve-HarnessRuntime.ps1 -RuntimeId google-workspace`로 현재 상태를 해석한다. **읽기 전용이며 아무것도 설치하지 않는다.** exit 4는 미설치이며 오류가 아니다.
2. 위치는 사용자 환경변수가 아니라 도구 루트(`AI_HARNESS_TOOLS_ROOT`) 기준의 런타임 인덱스(`runtimes.json`의 `command_rel`)로 해석한다. **실행 경로를 환경변수에 박지 않는다.** 도구 루트가 옮겨져도 해석되어야 하기 때문이다.
3. 런타임이 없고 Google 관련 업무를 사용할 가능성이 있거나 사용자가 공용 설치를 요청했다면 `scripts/Install-HarnessRuntime.ps1 -RuntimeId google-workspace`를 실행한다. 인증은 `scripts/Connect-HarnessRuntimeAuth.ps1`이 별도로 담당한다.
4. 등록은 진단이 아니라 **적용 경로**를 거친다. `scripts/Sync-HarnessClients.ps1 -SavePlan`으로 계획을 만들고, 사용자가 확인한 뒤 `scripts/Install-Harness.ps1 -Plan`으로 적용한다. 초기화가 클라이언트 등록을 조용히 수행하지 않는다.
5. 이미 같은 이름과 같은 command가 등록되어 있으면 재등록하지 않는다. 정합 판정은 `Sync-HarnessClients.ps1`이 선언·원장·실제 3자를 대조해서 낸다.
6. 프로젝트에는 실제 command 경로나 token을 복제하지 않고 capability ID만 기록한다.

전체 수명주기(install → auth → verify → sync → restart)는 `workflows/SHARED_RUNTIME.md`에 있다.

새 AI 클라이언트가 처음 발견되면 사용자가 경로를 다시 말하게 하지 않는다. `settings/clients/<id>.client.json`의 등록 방식으로 command를 찾아 연결한다. 디스크립터가 없거나 MCP를 지원하지 않으면 임의 파일을 만들지 않고 `PARTIAL`로 보고한다.

OAuth credential과 token은 PC 사용자 profile에만 존재해야 하며 Google Drive MASTER, Harness, 프로젝트, Git 저장소에 업로드하지 않는다.

# 18. 검증

초기화 후 반드시 확인한다.

## Harness
- CORE 존재
- ROUTER 존재
- POLICY_INDEX 존재 및 파싱 성공
- Global Harness Version 확인
- policy_count = 26
- P01~P26 파일 매핑 확인
- HARNESS_DOCTOR 존재

## Project
- `.ai/HARNESS.md` 존재
- `.ai/harness.yaml` 존재
- `current-state.md` 존재 또는 기존 상태파일 보존
- 현재 CLI Adapter 연결 상태 확인
- Google Workspace MCP manifest가 있으면 공용 command 탐지 및 현재 MCP 지원 CLI 등록 상태 확인
- `.ai/harness.yaml`에 `version`, `initialized_with`, `root`가 존재
- Bridge와 Global Harness Root가 일치

## Context
- Adapter에 26개 전문 정책이 복사되지 않았음
- 모든 Policy를 preload하라는 지시가 없음
- JIT Policy Loading이 명시됨
- new boundary에서 re-route가 명시됨
- Policy Load Trace 기본값이 `record_only`
- Runtime Fast Health Check가 가능함
- Decision Engine 기본값이 비활성이고 Fallback이 `existing_router`임
- Jev가 Permission·Security·Budget·승인 권한을 갖지 않음
- Provider 호출기가 없으면 Shadow 실행이 구현되었다고 보고하지 않음

## Preservation
- 기존 Instruction 삭제 없음
- 기존 Project configuration 불필요 변경 없음
- Source code 변경 없음
- `.ai` 상태에 Secret / Credential 실제 값 저장 지시 없음

초기화만 요청받은 경우 Application Source Code를 수정하지 않는다.

마지막에 `HARNESS_DOCTOR.md`의 전체 진단을 복제하지 않고 위 설치 Subset을 실행한다. 실제 검사 결과가 통과하면 `Harness Doctor basic check: PASS`로 보고하고, 실패 또는 미검증 항목이 있으면 그 상태를 그대로 보고한다.

---

# 19. 초기화 완료 보고

사용자에게 쉬운 말로 다음만 보고한다.

```text
AI Harness 초기화 완료

Harness Root:
<path>

Project Root:
<path>

연결된 CLI:
...

생성:
- ...

갱신:
- ...

보존:
- ...

Runtime:
CORE + ROUTER + POLICY_INDEX만 기본 사용
전문 정책 26개는 필요한 경우에만 JIT Load

Version:
Global ... / initialized_with ...

Harness Doctor basic check:
PASS / WARNING / FAIL

Runtime Health:
HEALTHY / DEGRADED / BLOCKED

검증:
PASS / PARTIAL / BLOCKED

주의사항:
...
```

없는 문제를 만들어 보고하지 않는다.

---

# 20. 완료 조건

다음이 만족되면 INITIALIZED:

```text
Global Harness readable
+
Project Bridge installed
+
Appropriate CLI Adapter connected
+
26 policies not preloaded
+
JIT routing contract present
+
Existing project instructions preserved
+
Harness Doctor basic check passed
```

Adapter가 현재 환경에서 확정되지 않은 경우:

```text
PARTIALLY_INITIALIZED
```

로 보고하고 이미 완료된 `.ai` Bridge는 보존한다.

---

# 21. 최종 원칙

이 파일의 목적은 26개 정책을 프로젝트에 복사하는 것이 아니다.

목적은:

```text
PROJECT
   ↓
THIN ADAPTER
   ↓
.ai/HARNESS.md
   ↓
CORE + ROUTER + POLICY_INDEX
   ↓
CURRENT TASK
   ↓
ONLY NEEDED POLICIES
```

라는 연결을 한 번 설치하는 것이다.

초기화 후 일반 작업에서 `PROJECT_INIT.md`를 반복 로드하지 않는다.
