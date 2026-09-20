# AI Harness Patch Notes

이 문서는 AI Harness의 사용자 관점 변경사항과 검증 결과를 누적 기록한다. 최신 항목을 위에 추가한다.

## 3.1 — 2026-09-20

### 목표

기존 CORE·ROUTER·JIT·Agent/Model Hierarchy를 유지하면서 Jev를 선택형 경량 Decision Advisor로 추가한다. 판단 순서는 `Deterministic → Optional Jev → Existing Router / Reasoning Model`이며 Runtime Core가 최종 Policy Authority다.

### 추가 및 변경

- `workflows/DECISION_ENGINE.md`: 제한된 의미 분류, Compact Context, typed 결과, 보안 경계, Fallback, Shadow, Trace와 단계 도입 계약을 한곳에 정의했다.
- `POLICY_INDEX.yaml`: Harness 3.1, Decision Engine Metadata, Global 기본 비활성, Shadow, `CONFIG_REQUIRED` 신뢰도 기준, `existing_router` Fallback을 추가했다.
- CORE·ROUTER·README·PROJECT_INIT·Doctor를 같은 계약으로 맞췄다. 새 P27이나 새 Agent/Model Hierarchy는 만들지 않았다.
- `scripts/jev-decision.mjs`와 `scripts/test-jev-scenarios.mjs`를 추가했다. Vercel AI Gateway의 `typesafe-ai/jev`를 사용하고 인증은 `AI_GATEWAY_API_KEY` 환경변수로만 참조한다.
- 실행기는 `non_sensitive` 입력만 허용하고, 질문·후보·typed 응답·사용량을 엄격히 검증하며 안전하게 추린 결과만 반환한다. timeout·형식 오류·Provider 실패는 기존 Router 복귀로 닫힌다.
- Global 기본값은 계속 비활성이다. 검증을 마친 프로젝트가 명시적으로 선택한 Shadow만 활성화할 수 있고, Calibration 전 신뢰도 기준은 `CONFIG_REQUIRED`로 유지한다.
- 가격 정보는 참고 문서에만 두고 Runtime 분기에 사용하지 않는다.

### 호환성

Jev는 Global 기본 비활성이다. 비활성·미설정·실패·저신뢰 상태에서는 기존 Router와 Reasoning 경로가 그대로 동작한다. 프로젝트별 Shadow를 활성화해도 기존 Router가 실제 경로를 결정한다.

### 검증

- R0 비민감 실제 Canary 3건은 선택 3/3·복귀 0, 평균 684ms·중앙 448ms·최대 1185ms, 합계 1463토큰, 해당 세 호출 보고 비용 0이었다. 이를 일반 성능·정확도·향후 무료 보장으로 해석하지 않는다.
- R1 오프라인 입력·응답 검사 22/22와 Codex 추가 반례 2/2를 통과했다. 후보 소유 여부, 빈 사용량, 비용 미제공 표기, 응답 본문까지의 시간 제한을 국소 보완했으며 R1·독립 검토 중 외부 호출은 0건이다.
- `Test-HarnessRepo.ps1 -HarnessRoot C:\AI-Harness -Json` → `PASS_WITH_WARNING` (`2026-09-20T13:46:08.8738217+00:00`). 정책 파일 매핑, Catalog, Schema, 공용 Runtime 검사는 통과했다.
- 경고는 이번 변경 전에도 있던 `markitdown 0.0.1a4` prerelease 고정 1건이며 Jev 변경으로 새로 생긴 오류는 없다.
- Global/Project `git diff --check` 통과, Project `.ai/harness.yaml` YAML 파싱과 Global 참조 경로 존재 확인을 통과했다.
- 응답 계약은 Vercel 공식 Jev 가이드와 R0 실제 응답으로 확인했다. 가격은 Runtime 분기에 사용하지 않는다.

## 3.0 — 2026-08-24

`POLICY_INDEX.yaml` 의 `harness_version` 이 `3.0` 이다. 그 값이 버전의 정본이다.

### 목표

특정 PC에 맞춰진 구성을 **GitHub에서 받아 어느 PC에서든 설치·사용할 수 있는 3계층 구조**로 재편한다. 무엇을(Layer A, git) / 어디에·누구로(Layer B, 도구 루트) / 어떤 capability ID를(Layer C, 프로젝트)를 섞지 않는다. 설계 근거는 `proposals/HARNESS_V3_PROPOSAL.md`, 진행 상태는 `proposals/HANDOFF.md`에 있다.

### 2026-08-24 — 공개, 플러그인, 에스코트

#### 저장소가 Public 이 됐다 (MIT)

`https://github.com/hacker943410-debug/ai-harness` — 누구든 쓰고 고치고 배포할 수 있다.

v3 설계 당시의 결정(D1)은 Private 였고, 뒤집혔다.
**공개만으로는 부족하다.** 라이선스 없는 공개 저장소는 법적으로 모든 권리 유보라
남이 합법적으로 쓸 수 없다. `LICENSE`(MIT)를 넣었고 `plugin.json` 의
`"license": "UNLICENSED"` 도 고쳤다.

공개 전 히스토리 감사 — 커밋 36개, diff 103,244줄:

| 대상 | 결과 |
|---|---|
| 비밀값 (private key / OAuth 토큰 / API 키) | 0건 |
| secret 키+값 | 0건 |
| 등록 지문 `hmac-sha256:…` / `tools-root.id` / Drive 폴더 id / OAuth client id | 0건 |
| `credentials.json` / `tokens.json` / `runtimes.json` / `clients.json` | 커밋된 적 없음 |

**3계층 분리가 문서가 아니라 실제로 지켜졌다는 증거다.** 비밀값과 머신 상태는
Layer B 에만 있었고 `.githooks/pre-commit` 이 경로와 값 양쪽으로 막고 있었다.
설계가 말뿐이었으면 지금 히스토리 재작성을 하고 있었을 것이다.

#### 설치 에스코트 — 도구를 알고 고르게 한다

카탈로그에 109개(MCP 65 + Skill 44)가 있어도 그게 뭔지 모르면 0개다.
**아는 사람만 쓸 수 있는 도구는 설치되지 않은 것과 같다.**

```powershell
.\scripts\Invoke-HarnessEscort.ps1 -SavePlan .\escort.json
```

- "이 프로젝트에서 주로 뭘 하실 건가요?" → 추천 세트와 **왜 그걸 권하는지**
- 카탈로그를 번호로 훑고, 번호를 치면 **쉬운 말로** 자세히
- 항목마다 설치 여부를 묻고, 예면 **자동인지 직접인지** 다시 묻는다
  - 자동 = 계획에 담고 `Install-Harness.ps1` 이 확인받고 실행
  - 직접 = 명령을 순서대로 안내하고 기록만 남긴다
- `g` 목표 다시 · `r` 추천 다시 · `q` 마치기. 아무것도 안 고르고 나가도 된다
- 읽기 전용: `-List` / `-Explain <번호|id>` / `-Tips`

**AI 없이 돈다.** 하네스를 처음 까는 시점에는 AI 가 아직 연결돼 있지 않을 수 있다.

**에스코트도 적용하지 않는다.** 계획 파일만 낸다. 계획 생산자는 셋이 됐지만
(`Get-HarnessEnvironment` / `Sync-HarnessClients` / `Invoke-HarnessEscort`)
적용자는 여전히 `Install-Harness.ps1` 하나다.

**자동 설치를 막을 때는 이유를 말한다.** `discovery_only` 처럼 좌표가 확정되지 않은 항목,
정확한 버전을 못 정한 npm/pypi, 준비물이 필요한 컨테이너·SDK 방식.
막는 것과 이유 없이 안 되는 것은 다르다.

설명 문구는 스크립트가 아니라 `catalogs/escort-glossary.json` 과
`escort-profiles.json` 에 있다. 도구가 늘어도 스크립트를 고치지 않는다.
절차는 `workflows/ESCORT.md`, 설치 흐름 안에서의 자리는 `HARNESS_INSTALL.md` §5.0b.

#### (선택) Claude Code 플러그인

```text
/plugin marketplace add hacker943410-debug/ai-harness
/plugin install ai-harness@ai-harness
```

`/harness-init` · `/harness-doctor` · `/harness-status` · `/harness-escort` 와
스킬 `harness-runtime` · `harness-capability`.

**플러그인은 정본이 아니다.** Layer A 의 파일을 가리키는 얇은 진입점이며
정책 원문을 복사하지 않는다. Codex 와 AGY 에는 이 메커니즘이 없으므로
플러그인이 정본이 되면 그 사용자들이 뒤처지고 마스터가 또 갈라진다.

**`.mcp.json` 은 일부러 넣지 않았다.** 제안서 §F8(b) 목록에는 있었지만,
공용 런타임의 실체는 Layer B 에 있어 경로가 PC 마다 다르고, 무엇보다 등록 경로가
`Register-HarnessRuntimeClient.ps1` 과 플러그인 둘로 갈라져 "적용하는 문은 하나"가 깨진다.

하네스를 고치는 PC 는 로컬 경로(`add C:\AI-Harness`)로, 그냥 쓰는 PC 는 GitHub 으로 등록한다.
**한 PC 에서 둘 다 등록하지 않는다** — 같은 이름이 겹치면 어느 쪽이 로드됐는지 알 수 없다.

#### 검사 규칙 추가 (`Test-HarnessRepo.ps1`)

| 코드 | 판정 | 막는 것 |
|---|---|---|
| `ESCORT_UNKNOWN_ID` | FAIL | 카탈로그에 없는 id 를 추천하는 것. 존재하지 않는 도구를 권유하면 사용자를 막다른 길로 보낸다 |
| `ESCORT_DUPLICATE_PROFILE` | FAIL | 프로필 id 중복 |
| `ESCORT_UNKNOWN_INSTALL_KIND` | WARN | 카탈로그가 쓰는 설치 방식인데 사전에 설명이 없는 것 |

#### 문서 정합

- `README.md` 가 아직 v2.2("Google Drive = MASTER")를 설명하고 있었다. D6 과 정면으로 어긋난다.
  §0(3계층) 신설, §3 정본·런타임·스냅샷, §15 git clone 기준,
  §21 "바꾸는 문은 하나", §22 에스코트, §23 플러그인, §24 라이선스.
  **README 가 v3 에서 처음으로 Layer B 의 존재를 언급한다.** 그전에는 어디에도 없었다
- `HANDOFF.md` 의 손으로 관리하던 커밋 이력 표를 **삭제했다.**
  `6d56aba` 에서 멈춘 채 커밋 5개가 뒤에 붙어 있었고 아무도 몰랐다.
  아무도 그 표를 근거로 쓰지 않았기 때문이다. git 이 정본이다
- 클라이언트 등록(codex 등)을 **미결 사항에서 종결했다.** Layer B 는 쓰는 사람이 쓸 때
  연결한다. 저장소가 특정 PC 의 등록 상태를 미결로 들고 있을 이유가 없다

### 검증 (2026-08-24)

- `Test-HarnessRepo.ps1` — PASS_WITH_WARNING (경고 1건은 알려진 `markitdown` 프리릴리스 고정)
- `ESCORT_UNKNOWN_ID` **음성 테스트** — 가짜 id 를 넣으면 실제로 FAIL 이 난다
- 에스코트 전 구간 — 에스코트 → 계획 파일 → `Install-Harness.ps1 -DryRun` 이 실제 명령 표시
  → `change-plan.schema.json` 통과
- 플러그인 — `claude plugin validate` 통과, 실제 설치 후 `details` 로 구성요소 5개 로드 확인
  (MCP servers 0 — 의도대로)
- 공개 경로 — 인증 없이 `raw.githubusercontent.com` 에서 `marketplace.json` HTTP 200.
  제안서 §11 **V7**("private 저장소 marketplace 미검증") 쟁점 소멸

### 고친 실수 (기록해 둔다)

- **계획 단계를 `optional: true` 로 냈다.** 적용자가 전부 제외해 "적용할 단계가 없습니다" 가 떴다.
  사용자가 **명시적으로 y 를 누른 것**을 "선택 사항"으로 모델링한 게 틀렸다. `optional: false` 로 고쳤다
- **에스코트가 EOF 에서 터졌다.** `Read-Host` 는 입력 통로가 닫히면 빈 문자열이 아니라 `$null` 을 준다.
  그것을 문자열로 다뤄 `.Trim()` 에서 터졌다. "빈 줄 3연속"만 세고 있었던 게 문제였다.
  `$null` 은 "입력이 없다"가 아니라 "통로가 닫혔다"이므로 즉시 종료 코드 `3` 으로 빠진다
- **되돌아갈 길이 없었다.** 목표 선택과 추천이 한 번 지나가면 끝이어서 껐다 켜야 했다.
  `g` / `r` / `h` 를 넣었다. **한 번 지나가면 끝인 화면은 사용자를 껐다 켜게 만든다**
- **`HARNESS_INSTALL.md` 이 에스코트를 몰랐다.** `ESCORT.md` 는 "설치 가이드의 도구 고르기 단계"라고
  주장하는데 그 문서에는 언급이 0건이었다. 편도 참조다. 에스코트의 대상이 *처음 세팅하는 사람*인데
  정작 처음 읽는 문서에서 안 보였다. §5.0b 로 넣었다

> 마지막 두 건은 **사용자가 직접 써 보고 나왔다.**
> 스크립트가 도는 것과 쓸 만한 것은 다르다. 검증했던 것은 앞쪽이었다.

### 2.2 에서 은퇴한 것

아래는 **삭제됐다.** 2.2 항목에 남아 있는 사용법을 따르지 않는다.

- `scripts/Initialize-GoogleWorkspaceMcp.ps1` → `scripts/Install-HarnessRuntime.ps1` (설치) + `scripts/Connect-HarnessRuntimeAuth.ps1` (인증) + `scripts/Sync-HarnessClients.ps1` → `scripts/Install-Harness.ps1` (등록)
- `scripts/Resolve-GoogleWorkspaceMcp.ps1` → `scripts/Resolve-HarnessRuntime.ps1` (런타임 종류에 무관)
- `settings/google-workspace/manifest.json` + `mcp-server.template.json` → `runtimes/google-workspace.runtime.json` (버전·서버 정의의 단일 소스)
- 사용자 환경변수 `AI_HARNESS_GOOGLE_MCP_COMMAND` → 도구 루트 + 런타임 인덱스의 상대 경로. **실행 경로를 환경변수에 박지 않는다.** 루트를 옮겨도 해석이 따라와야 하기 때문이다.

은퇴한 환경변수는 값이 남아 있어도 아무도 읽지 않지만, 옛 실행 파일을 가리킨 채 사람과 되살아난 옛 스크립트를 오도한다. 그래서 매니페스트의 `retired_locators`가 그 이름을 선언하고 환경 진단이 삭제를 제안한다(적용은 계획 파일을 거친다).

### 왜 지웠는가

옛 스크립트는 없어진 래퍼 `.cmd`를 **다시 만들었다.** 그 래퍼는 `GOOGLE_WORKSPACE_SERVICES`에 `contacts`를 포함하고 있어서, 한 번만 실행돼도 방금 해소한 등록 드리프트가 되살아난다. 새 경로를 만들고 옛 경로를 남겨 두면, 남은 쪽이 조용히 이긴다.

## 2.2 — 2026-08-23

### 목표

MCP 호환 AI가 바뀌어도 Google Workspace 업무를 동일한 PC 공용 런타임과 OAuth profile로 수행할 수 있도록 기반을 구성했다.

### 추가 및 변경

- `C:\AI-Tools\google-workspace-mcp`에 `@dguido/google-workspace-mcp` 3.4.4를 정확한 버전으로 설치했다.
- Google Drive, Gmail, Calendar, Docs, Sheets, Slides, Contacts 공용 실행 래퍼와 범용 MCP 설정 예시를 추가했다.
- OAuth credential 가져오기, 사용자 전용 ACL 적용, 최초 인증을 수행하는 스크립트를 추가했다.
- `workflows/GOOGLE_WORKSPACE_MCP.md`에 공용 경로, 클라이언트 연결, 권한 경계, 공식 Google 원격 MCP 선택 기준을 정의했다.
- MCP Catalog에 `google-workspace-local` 항목을 추가했다.
- 비밀값이 없는 `settings/google-workspace/` 이식형 manifest와 설정 template을 추가했다.
- `Initialize-GoogleWorkspaceMcp.ps1`가 경로가 다른 PC에서도 공용 런타임을 설치하고 사용자 locator 환경변수를 설정한다.
- `Resolve-GoogleWorkspaceMcp.ps1`가 사용자 환경변수와 표준 후보 경로에서 command를 자동 탐지한다.
- PROJECT_INIT이 새 AI 클라이언트를 발견하면 사용자가 경로를 다시 입력하게 하지 않고 공식 방식으로 한 번 등록하도록 규정했다.
- 현재 PC의 Codex와 Claude Code에 `google-workspace`를 전역/사용자 범위로 등록했다.
- AGY CLI의 공용 `~/.gemini/config/mcp_config.json`에도 `google-workspace`를 등록하고 자동 초기화 대상에 추가했다.
- Google Drive MASTER `/AI-Harness`에 전체 Harness를 경로 기준으로 동기화했다(기존 31개 갱신, 신규 15개 생성, 실패 0개).

### 보안 및 제한

- OAuth client secret과 token은 Harness 및 프로젝트에 저장하지 않는다.
- Google Cloud의 Desktop app OAuth JSON 발급과 브라우저 동의는 사용자 계정 승인이 필요한 최초 1회 단계다.
- Google 공식 Workspace 원격 MCP는 2026-08-20 기준 Developer Preview이고 클라이언트별 OAuth redirect 설정이 필요하므로 PC 공용 기본값으로 사용하지 않았다.

### 검증

- PASS — npm audit 취약점 0건
- PASS — Node.js 24.19.0으로 런타임 요구사항(Node 22 이상) 충족
- PASS — MCP 실행 파일이 3.4.4로 시작되고 stdio 대기 상태 진입
- PASS — Desktop app OAuth credential과 access/refresh token 존재 및 JSON 파싱 확인(비밀값 미출력)
- PASS — 공용 MCP stdio handshake 및 tool discovery 확인
- PASS — 공용 locator 환경변수와 resolver가 동일 command를 반환
- PASS — Codex global 및 Claude Code user scope 연결 상태 확인
- PASS — Drive MASTER의 `settings/google-workspace` manifest/template 존재 확인
- INFO — 실제 Drive/Gmail 데이터 호출은 각 AI 클라이언트 등록·재시작 후 최소 권한 읽기 요청으로 확인

## 2.1 — 2026-08-23

### 목표

웹·모바일 프로젝트 진행 중 현재 Agent에 필요한 Capability가 없을 때, 적합한 MCP 또는 Agent Skill을 찾아 프로젝트 범위로 한 번 설치하고 이후 재사용할 수 있는 JIT Capability Acquisition 계층을 추가했다.

### 추가

- `catalogs/mcp-catalog.json`
  - 공통 개발, 웹, 디자인, DB, API, Cloud, 관측성, 협업, 분석, Android/iOS MCP 후보 정의
  - 검증된 설치 좌표와 검색 전용 후보를 `verified` / `discovery_only`로 구분
- `catalogs/skill-catalog.json`
  - Skills.sh에서 확인한 웹·모바일·DB·테스트·설계·작업 절차 Skill 정의
- `schemas/capability-lock.schema.json`
  - 프로젝트별 MCP/Skill 설치 기록 형식 정의
- `workflows/CAPABILITY_ACQUISITION.md`
  - Capability Gap 판정부터 검색, Risk Gate, 프로젝트 설치, 검증, 재사용까지의 표준 절차
- `scripts/Search-HarnessCapability.ps1`
  - 로컬 카탈로그를 Capability·도메인·이름으로 검색
- `scripts/Install-ProjectSkill.ps1`
  - Skills.sh CLI를 이용한 프로젝트 로컬 Skill 설치 및 Lock 기록
- `scripts/Install-ProjectMcp.ps1`
  - 정확한 Version의 npm MCP 프로젝트 설치 또는 검증된 Remote MCP 기록
- `scripts/Test-ProjectCapabilities.ps1`
  - Catalog, Lock, Version pin, 프로젝트 Scope, Secret 의심 패턴, 중복 MCP 검사

### 변경

- Harness Version을 `2.0`에서 `2.1`로 갱신
- Router에 `TOOL_CAPABILITY_GAP`, `MCP_DISCOVERY`, `SKILL_DISCOVERY`, `PROJECT_TOOL_INSTALL`, `REMOTE_MCP_AUTH`, `TOOL_VERSION_DRIFT`, `TOOL_INSTALL_FAILED`, `PRODUCTION_CAPABILITY` 경계 추가
- P15에 MCP/Skill을 Dependency 범위로 명시하고 JIT Acquisition 계약 추가
- P17에 MCP Credential, OAuth Scope, Project-local Config 보안 계약 추가
- Doctor에 Capability Catalog와 프로젝트 설치 상태 검사 항목 추가
- README와 PROJECT_INIT에 선택적 Capability 계층 연결

### 설계 결정

- MCP/Skill 전문을 `CORE`나 `POLICY_INDEX`에 preload하지 않는다.
- 설치 좌표를 확신할 수 없는 항목은 자동 설치하지 않고 `discovery_only`로 유지한다.
- 프로젝트 설정은 `.ai/mcp/desired.json`, 설치 상태는 `.ai/capability-lock.json`에 Secret 없이 기록한다.
- Client별 MCP 설정 형식은 서로 다르므로 정규화된 Desired State와 Client Adapter를 분리한다.
- 설치 성공과 Runtime 검증을 구분한다. 실제 호출 전에는 `verified`로 기록하지 않는다.

### 호환성 및 제한

- Skills 설치 후 Client에 따라 새 Agent 세션이 필요할 수 있다.
- iOS Simulator/Xcode MCP는 macOS와 Xcode가 필요하다.
- `registry_lookup`, `remote_or_client`, `source_or_registry` 항목은 설치 시점에 공식 문서를 재확인해야 한다.
- 현재 Patch는 전역 자동 설치를 제공하지 않는다. 프로젝트 범위가 기본이며 의도된 동작이다.

### 검증

- PASS — MCP Catalog JSON 파싱, 64개 ID 중복 없음
- PASS — Skill Catalog JSON 파싱, 44개 ID 중복 없음
- PASS — Capability Lock JSON Schema 파싱
- PASS — PowerShell Script 4개 AST 구문 파싱
- PASS — `browser automation` 검색에서 Playwright MCP와 Playwright Skill 반환
- PASS — Skill 설치 `-WhatIf`가 프로젝트 Root 대상 명령으로 생성됨
- PASS — MCP 설치 `-WhatIf`가 exact Version의 project devDependency 명령으로 생성됨
- PASS_WITH_INFO — Harness Root 대상 Capability Doctor; 설치 Lock이 아직 없음을 정상 정보로 반환

---

## 2.0 — 기존 기준선

- 26개 전문 정책
- CORE + ROUTER + POLICY_INDEX 기반 JIT Policy Loading
- PROJECT_INIT을 통한 얇은 Project Adapter 설치
- HARNESS_DOCTOR 기반 읽기 전용 운영 진단
