# AI Harness v3.0 제안서 — 배포 가능한 하네스 + 공용 런타임 레지스트리

- 문서 상태: **제안(REVIEW) v1.1** — 실행 승인 전. 이 문서만으로는 아무것도 변경되지 않는다.
- 작성일: 2026-08-23 / 개정: 2026-08-23 (Codex 교차검증 반영 — 처리 내역은 §15)
- 대상 하네스: `C:\AI-Harness` (현재 `harness_version: 2.2`)
- 검토자: 사용자, Codex CLI(교차검증)
- 이 문서가 정의하는 것: 요구사항 확인 / 구조 / 프로세스 흐름 / 확장 방법 / 스키마 / 마이그레이션 / 결정 필요 항목 / 수락 기준
- 이 문서가 정의하지 않는 것: 실제 코드 구현. 구현은 승인 후 별도 작업.

---

# 0. 검토 방법 (Codex 교차검증용)

이 문서를 다른 AI에게 검토시킬 때 다음 순서를 권장한다.

1. **§1 요구사항이 사용자의 의도와 일치하는가.** 여기가 틀리면 나머지는 전부 무의미하다.
2. **§12 실측 사실이 재현되는가.** 각 항목에 재현 명령을 같이 적어 두었다. 재현되지 않는 항목이 있으면 그 항목에 의존한 설계를 전부 의심해야 한다.
3. **§4 프로세스 흐름에 빠진 분기가 있는가.** 특히 실패 경로.
4. **§5 확장 가이드가 실제로 "파일 1개 추가"로 끝나는가.** 코드 수정이 필요해지는 경우가 있으면 설계 결함이다.
5. **§10 결정 항목의 추천안에 반대 근거가 있는가.**

반박할 때는 "일반적으로 좋지 않다"가 아니라 **구체적 실패 시나리오**(행위자, 행동, 잘못된 결과)로 반박할 것.

---

# 1. 내가 이해한 요구사항 — 먼저 이것부터 확인해 주세요

## R1. 새 프로젝트 시작이 반복 노동이 아니어야 한다
새 프로젝트를 시작할 때마다 하네스를 손으로 복사하거나 설정을 다시 만들지 않는다.
**GitHub에서 받아 → 설치 → 즉시 하네스 적용**까지가 정해진 짧은 절차여야 한다.

## R2. MCP는 PC에 한 번만 설치하고 계속 재사용한다
프로젝트마다 MCP를 다시 설치하거나 Google에 다시 로그인하지 않는다.
공용 런타임은 `AI-Tools`에 있고, 하네스는 **그것을 "찾아서" 쓴다.**
사용자가 매번 경로를 알려주지 않아야 한다.

## R3. 2.1에서 만든 카탈로그(필요할 때만 MCP를 쓰는 JIT 구조)와 결합한다
카탈로그에서 능력을 검색했을 때, 그 능력이 **이미 AI-Tools에 있으면 설치 없이 즉시 사용**,
없으면 **AI-Tools에 한 번 설치**하고 그다음부터는 모든 프로젝트가 재사용한다.

## R4. 앞으로 계속 추가·수정할 수 있어야 한다 ← **이번 질문의 핵심**
- 새 **지침(정책)** 추가
- 새 **MCP 정보** 추가
- 새 **플러그인 정보** 추가
- 새 **Skill** 추가
- 새 **AI 클라이언트** 추가
- 기존 항목 **업데이트**

이때 **하네스 코드를 고치는 일이 없어야 한다.** 데이터 파일 하나를 추가하면 끝나야 한다.
→ 이 문서는 이것을 **§5 확장 가이드**의 최우선 설계 목표로 삼는다.

## R5. 여러 AI CLI에서 동일하게 동작한다
현재: Claude Code / Codex CLI / AGY(Antigravity). 앞으로 다른 CLI가 추가될 수 있다.
새 CLI가 생겼을 때도 **사용자가 경로를 다시 말하지 않아야** 한다.

## R6. 지금은 실행이 아니라 제안이다
바로 적용하지 않는다. 사용자가 검토하고 Codex에게도 교차검증을 받은 뒤 결정한다.
따라서 이 문서는 **자립적**이어야 하고, 주장마다 **근거와 재현 방법**이 있어야 하며, **대안과 추천 이유**가 있어야 한다.

> **확인 요청:** R1~R6 중 빠졌거나 다르게 이해한 것이 있으면 알려 주세요. 특히 R4의 "추가하고 싶은 대상 목록"에 빠진 항목이 있는지가 중요합니다.

---

# 2. 설계 원칙 3가지

이 세 줄이 나머지 전부를 결정한다.

### 원칙 1 — 무엇을(What) / 어디에(Where) / 어떤 것을(Which) 를 절대 섞지 않는다

| 계층 | 이름 | 답하는 질문 | 저장소 | 예 |
|---|---|---|---|---|
| **A** | 하네스(Harness) | *무엇을* 어떤 버전으로 쓰는가 | GitHub | `@dguido/google-workspace-mcp@3.4.4`를 쓴다 |
| **B** | 머신(Machine) | *어디에* 설치됐고 *누구로* 인증됐나 | 로컬 PC (`AI-Tools`) | `%LOCALAPPDATA%\AI-Tools\...`에 있고 `default` 프로필로 인증됨 |
| **C** | 프로젝트(Project) | *어떤* 능력을 참조하나 | 프로젝트 `.ai/` | `google-workspace-local` 능력을 쓴다 |

**위반 판정:**
- A에 절대경로·비밀값이 있으면 → CI 실패
- C에 경로·토큰·머신 상태가 있으면 → Doctor FAIL
- B가 git에 들어가면 → pre-commit 차단

현재 2.2가 배포 불가능한 근본 이유가 이 혼합이다.
`settings/google-workspace/manifest.json`에 `"default_tools_root": "C:\\AI-Tools"`가 있고,
`scripts/Resolve-GoogleWorkspaceMcp.ps1:9`에 `C:\AI-Tools\...`가 하드코딩되어 있다. (§12-A)

### 원칙 2 — 확장은 코드가 아니라 데이터다

새 정책 / 새 MCP / 새 런타임 / 새 클라이언트 / 새 플러그인을 추가할 때
**스크립트를 수정해야 한다면 그것은 설계 실패로 간주한다.**
전부 "선언 파일 1개 추가 + 스키마 검증 통과"로 끝나야 한다. (§5)

### 원칙 3 — 상태는 주장하지 않고 증명한다

`설치됨(installed)` ≠ `등록됨(registered)` ≠ `인증됨(authenticated)` ≠ `검증됨(verified)`.
각 상태는 **누가 언제 무엇으로 확인했는지 증거**와 함께 기록한다.
증거 없는 `verified`는 Doctor가 FAIL로 처리한다.

현재 2.1의 `CAPABILITY_ACQUISITION.md §6`이 프로젝트 계층에서 이미 이 규칙을 갖고 있다. v3.0은 이 규칙을 **머신 계층으로 확장**할 뿐 새로 만들지 않는다.

---

# 3. 구조

## 3.1 Layer A — GitHub 저장소 `ai-harness`

```
ai-harness/
├─ .claude-plugin/
│  └─ marketplace.json              ★신규 Claude Code 플러그인 마켓플레이스 진입점
├─ plugins/                          ★신규 (선택) Claude 전용 편의 계층
│  └─ ai-harness/
│     ├─ .claude-plugin/plugin.json
│     ├─ skills/                     하네스 절차를 Skill로 노출
│     ├─ commands/                   /harness-init, /harness-doctor
│     └─ .mcp.json                   ${CLAUDE_PLUGIN_ROOT} 사용, 절대경로 없음
│
├─ .gitignore  .gitattributes  .editorconfig      ★신규 (현재 셋 다 없음)
├─ .githooks/pre-commit                           ★신규 비밀값 커밋 차단
├─ .github/workflows/validate.yml                 ★신규 CI
│
├─ README.md  PATCH_NOTES.md
├─ CORE.md  ROUTER.md  PROJECT_INIT.md  HARNESS_DOCTOR.md
├─ POLICY_INDEX.yaml                 사람이 읽는 정본
├─ POLICY_INDEX.compat.json          ★신규 기계가 읽는 계약 (이유는 §3.4)
│
├─ policies/                         P01~P26 (+앞으로 추가되는 정책)
│
├─ catalogs/
│  ├─ mcp-catalog.json               65개 → 계속 추가
│  ├─ skill-catalog.json             44개 → 계속 추가
│  └─ plugin-catalog.json            ★신규 플러그인 정보
│
├─ runtimes/                         ★신규 공용 런타임 "레시피"
│  ├─ google-workspace.runtime.json
│  └─ _TEMPLATE.runtime.json
│
├─ settings/clients/                 ★신규 CLI 등록 방법 = 데이터
│  ├─ claude.client.json
│  ├─ codex.client.json
│  └─ agy.client.json
│
├─ schemas/
│  ├─ capability-lock.schema.json    1.0 → 1.1
│  ├─ runtime-manifest.schema.json   ★신규
│  ├─ runtime-index.schema.json      ★신규
│  ├─ client-descriptor.schema.json  ★신규
│  ├─ mcp-catalog.schema.json        ★신규
│  └─ never-sync.generated.json      ★신규 비밀 글롭 단일 소스
│
├─ scripts/
│  ├─ _Harness.Common.ps1            ★신규 경로·인코딩 헬퍼 (버그 단일 수정점)
│  ├─ Resolve-HarnessRuntime.ps1     ★신규 읽기 전용. 찾기만
│  ├─ Install-HarnessRuntime.ps1     ★신규 Layer B에 1회 설치
│  ├─ Register-HarnessRuntimeClient.ps1  ★신규 CLI 1개에 1회 등록
│  ├─ Sync-HarnessClients.ps1        ★신규 (런타임 × 클라이언트) 정합
│  ├─ Connect-HarnessRuntimeAuth.ps1 ★신규 인증 (비밀값 위치 강제)
│  ├─ Test-HarnessRuntime.ps1        ★신규 verified를 쓸 수 있는 유일한 스크립트
│  ├─ Disconnect-HarnessRuntime.ps1  ★신규 해지/철회 (사고 대응용)
│  ├─ Test-HarnessRepo.ps1           ★신규 레포 자체 검사
│  ├─ Search-HarnessCapability.ps1   기존 (경로 버그 수정)
│  ├─ Install-ProjectMcp.ps1         기존 (+shared_runtime 가드, +레지스트리 해석)
│  ├─ Install-ProjectSkill.ps1       기존
│  └─ Test-ProjectCapabilities.ps1   기존 (+scope enum 확장)
│
├─ workflows/
│  ├─ CAPABILITY_ACQUISITION.md      기존 (+공용/프로젝트 분기)
│  ├─ SHARED_RUNTIME.md              ★신규 런타임 수명주기
│  ├─ EXTENDING_HARNESS.md           ★신규 §5의 실행판
│  └─ GOOGLE_WORKSPACE_MCP.md        기존 (런타임별 부록으로 축소)
│
└─ bootstrap/
   ├─ install.ps1  install.sh  harness.cmd  harness
```

**삭제/이동**
| 현재 | v3.0 |
|---|---|
| `settings/google-workspace/manifest.json` | `runtimes/google-workspace.runtime.json` |
| `settings/google-workspace/mcp-server.template.json` | 삭제 (manifest의 `server` 블록이 단일 소스) |
| `scripts/Initialize-GoogleWorkspaceMcp.ps1` | `Install-HarnessRuntime.ps1`로 일반화 |
| `scripts/Resolve-GoogleWorkspaceMcp.ps1` | `Resolve-HarnessRuntime.ps1`로 일반화 |

> 두 옛 스크립트 이름은 한 마이너 버전 동안 "경고 후 전달하는 3줄 shim"으로 남긴다. `PROJECT_INIT.md §17.1`이 이름으로 참조하고 있어서 즉시 삭제하면 마이그레이션 중간에 깨진다.

## 3.2 Layer B — 머신 (`AI-Tools`). git 절대 금지

**위치 탐색 순서** (첫 번째 성공이 이김)

```
1. -ToolsRoot 파라미터
2. $env:AI_HARNESS_TOOLS_ROOT           (프로세스)
3. Windows 전용: User 환경변수           (레지스트리 기반)
4. 포인터 파일 <config_home>/ai-harness/tools-root
5. 플랫폼 기본값  Windows: %LOCALAPPDATA%\AI-Tools   Unix: $HOME/.ai-tools
6. 레거시 C:\AI-Tools                    → 해석은 되지만 drift 경고
```

> **4번이 필요한 이유:** `[Environment]::SetEnvironmentVariable(...,'User')`는 .NET on Unix에서 **조용히 무시**된다. 현재 설계의 1순위 탐색 수단이 유닉스에서 영구히 죽어 있다.
> **6번을 "허용하되 경고"로 두는 이유:** 지금 이 PC의 Claude/AGY가 실제로 그 경로에 등록돼 있다. 즉시 끊으면 동작 중인 것이 깨진다. (§12-D)

**구성**

```
<tools_root>/
├─ runtimes.json          런타임 인덱스. Install/Test만 쓴다
├─ clients.json           (런타임 × 클라이언트) 등록 원장
├─ tools-root.id          GUID. "루트 이동"과 "다른 PC"를 구분
├─ logs/
├─ google-workspace/      runtime_id 하나당 디렉터리 하나
│  ├─ package.json  package-lock.json
│  └─ node_modules/.bin/google-workspace-mcp.cmd   ← 이것이 등록되는 command
└─ clients/pending/       설정 형식을 확인 못 한 CLI용 이식 가능 설정
```

**tools_root 밖이지만 여전히 Layer B (런타임 소유, manifest가 선언)**
```
%USERPROFILE%\.config\google-workspace-mcp\profiles\default\credentials.json
%USERPROFILE%\.config\google-workspace-mcp\profiles\default\tokens.json
```

## 3.3 Layer C — 프로젝트 `.ai/`

```
<project>/
├─ AGENTS.md | CLAUDE.md | GEMINI.md    AI-HARNESS 관리 블록만
└─ .ai/
   ├─ HARNESS.md            브리지
   ├─ harness.yaml          + capabilities 블록 (아래)
   ├─ capabilities.json     ★신규 harness.yaml의 기계 판독용 미러
   ├─ current-state.md
   ├─ capability-lock.json  (지연 생성)
   └─ mcp/desired.json      (지연 생성, 프로젝트 범위 MCP만)
```

`.ai/harness.yaml`에 추가되는 유일한 블록:

```yaml
capabilities:
  shared_runtimes:
    - capability_id: "google-workspace-local"
      runtime_id: "google-workspace"
      required: false          # true면 해석 실패 시 Doctor가 BLOCKED
  project_scope_default: true
min_harness_version: "3.0"     # 구버전 하네스가 명확히 거부할 수 있게
```

**여기에 없는 것이 중요하다:** command 경로 없음, tools_root 없음, OAuth 프로필 없음, 토큰 경로 없음.
macOS를 쓰는 팀원이 같은 저장소를 클론해도 자기 Layer B로 해석된다.

> 현재 `Install-ProjectMcp.ps1:67`은 `project_root = D:\projects\...`를 **커밋되는 락파일에 기록**한다. 이건 다른 모든 PC에서 틀린 값이다. v3.0에서 이 필드는 선택(optional)으로 내리고 기본은 기록하지 않는다.

## 3.4 왜 `POLICY_INDEX.compat.json`을 따로 두는가

`POLICY_INDEX.yaml`에 기계가 읽는 `compat` 블록을 넣자는 안이 자연스럽지만, **Windows PowerShell 5.1에는 YAML 파서가 없다.** 이 PC에도 `ConvertFrom-Yaml`이 없고 `powershell-yaml` 모듈도 없다(§12-H). 부트스트랩 첫 단계에서 PSGallery 설치를 요구하면 "클론 + 명령 하나"라는 약속이 깨진다.

**규칙: YAML은 사람만 읽는다. 스크립트가 읽는 계약은 전부 JSON.**
`POLICY_INDEX.compat.json`은 CI에서 YAML로부터 생성·검증한다.

---

# 4. 프로세스 흐름

## F1. PC 최초 설치 (PC당 1회)

```
[사용자]
  git clone https://github.com/<owner>/ai-harness.git "$env:LOCALAPPDATA\AI-Harness"
  powershell -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\AI-Harness\bootstrap\install.ps1"
        │
        ▼
[install.ps1] 멱등. 몇 번 실행해도 안전
  1  플랫폼/PS 에디션 감지. node<22 또는 npm/git 없으면 즉시 중단 (메시지는 ASCII만)
  2  HARNESS_ROOT = bootstrap/의 상위 디렉터리. 추측하지 않음
  3  TOOLS_ROOT 결정 (§3.2 탐색 순서, -ToolsRoot로 덮어쓰기 가능)
  4  로케이터 영속화
       Windows → User 환경변수 AI_HARNESS_ROOT / AI_HARNESS_TOOLS_ROOT
       Unix    → <config_home>/ai-harness/{harness-root,tools-root} 포인터 파일
       (양쪽 다 프로세스 스코프에도 설정해서 현재 셸에서 즉시 동작)
  5  TOOLS_ROOT / logs / clients/pending 생성, tools-root.id(GUID) 기록
  6  runtimes.json, clients.json 골격 생성 (BOM 없는 UTF-8)
  7  git config core.hooksPath .githooks   ← 비밀값 pre-commit 훅 활성화
  8  ★ adopt 패스: 각 CLI에 이미 등록된 MCP를 실제로 읽어 clients.json에 반영
        (이걸 안 하면 "이미 등록됨"을 원장이 모르는 상태로 시작한다 → §12-D)
  9  Test-HarnessRepo.ps1 -Quick
        스키마 파싱 / 정책 26개 매핑 / latest·와일드카드 핀 없음 / 추적된 비밀값 없음
        ※ git 저장소가 아니면 PASS가 아니라 UNENFORCED로 보고
 10  -Migrate (선택): 레거시 설치를 재설치 없이 채택 (§F9)
 11  다음 명령 2개만 출력하고 종료. 런타임은 하나도 설치하지 않는다  ← JIT 유지
```

**설계 판단:** 부트스트랩은 런타임을 설치하지 않는다. Google을 안 쓰는 사람이 Google MCP를 받을 이유가 없다. `CORE.md 1.13`(필요할 때만 Capability Acquisition)을 머신 계층에도 적용한 것이다.

## F2. 새 프로젝트 시작 (프로젝트당 1회)

```
cd D:\projects\new-project
claude   (또는 codex / agy)

  "%LOCALAPPDATA%\AI-Harness\PROJECT_INIT.md 를 읽고 이 프로젝트에 하네스를 초기화해줘"
        │
        ▼
[에이전트가 PROJECT_INIT.md를 따라 실행]
  1  HARNESS_ROOT 확인 → CORE/ROUTER/POLICY_INDEX/policies 존재 검사
  2  Project Root 식별 (.git, package.json, ... / 없으면 현재 디렉터리)
  3  기존 AGENTS.md / CLAUDE.md / GEMINI.md / .ai 보존 확인
  4  .ai/HARNESS.md, .ai/harness.yaml, .ai/current-state.md 생성 (그 외 생성 안 함)
  5  현재 CLI Adapter의 AI-HARNESS 관리 블록만 갱신
  6  ★ 공용 런타임 처리 (§17.1 재작성)
       0) PowerShell 호스트가 없으면 이 절 전체를 건너뛰고 PARTIAL 보고. 초기화는 계속한다
       1) harness.yaml capabilities.shared_runtimes 각 항목에 대해
            Resolve-HarnessRuntime.ps1 -RuntimeId <id> -Json   (읽기 전용)
       2) 없음 + required:false  → INFO 기록하고 통과
       3) 없음 + 사용자가 그 능력을 요청함 → 설치를 제안. 묻지 않고 실행하지 않음
       4) 있음 → 현재 클라이언트에만 등록 (-All 지정 시에만 전체)
       5) command 경로·토큰을 프로젝트에 절대 복사하지 않음. capability_id만 기록
  7  검증 후 보고 (INITIALIZED / PARTIALLY_INITIALIZED)
```

**결정적(deterministic) 대안** — 에이전트 추론 없이 파일 생성만:
```
harness project init D:\projects\new-project
```

## F3. 작업 중 능력이 부족할 때 — **"AI-Tools에서 찾아 쓰기"의 본체**

이것이 R2·R3에 대한 직접적인 답이다.

```
현재 작업에 능력이 부족하다고 판단
        │
        ▼
[1] 정말 부족한가?  (CAPABILITY_ACQUISITION §2)
     내장 도구로 가능? → 예: 중단, 설치하지 않음
     프로젝트의 기존 CLI/패키지로 가능? → 예: 중단
     .ai/capability-lock.json에 이미 검증된 도구가 있는가? → 예: 그것을 사용
        │ 아니오
        ▼
[2] ★ 이미 이 PC에 있는가?   ← 여기가 핵심
     Resolve-HarnessRuntime.ps1 -All -Json
        │
        ├─ found:true, state:verified
        │     → 현재 클라이언트에 등록만 하고 끝.
        │       설치 0회, 다운로드 0회, Google 로그인 0회.
        │       이것이 R2가 요구한 동작이다.
        │
        └─ found:false → [3]
        │
        ▼
[3] 카탈로그 검색
     Search-HarnessCapability.ps1 -Query "browser automation"
        → mcp-catalog.json + skill-catalog.json 에서 capability/domain 매칭
        │
        ▼
[4] install.kind 로 분기
     shared_runtime   → PC에 1회 설치 (§F6). 이후 모든 프로젝트가 재사용
     npm              → 프로젝트 devDependency, exact 버전 고정
     remote           → 프로젝트 클라이언트 설정에 URL. 토큰은 참조만
     registry_lookup  → ★ MCP 공식 레지스트리 API로 좌표 해석 후 위 셋 중 하나로 재분류
                          GET https://registry.modelcontextprotocol.io/v0.1/servers/{name}/versions/latest
                          (현재는 여기서 throw 하고 끝난다. 65개 중 53개가 이 상태 — §12-G)
     discovery_only   → 이름만으로 설치 금지. 공식 문서 재확인 + 사용자 확인 필요
        │
        ▼
[5] Risk Gate  (LOW / MEDIUM / HIGH / CRITICAL)
     HIGH 이상 → 최소 권한·허용 범위 고정, 사용자 승인 필요
     "설치 승인"과 "자격증명 연결 승인"과 "실제 실행 승인"은 서로 다른 권한
        │
        ▼
[6] 설치 → 등록 → 인증 → 검증  (§F6 또는 프로젝트 설치)
        │
        ▼
[7] 기록
     프로젝트 범위  → .ai/capability-lock.json (scope: project)
     머신 범위      → <tools_root>/runtimes.json + clients.json
                      .ai/harness.yaml에는 capability_id만
```

### 공용(machine) vs 프로젝트(project) 판단 기준

| 조건 | 범위 | 근거 |
|---|---|---|
| 사용자 계정 인증(OAuth)이 필요하고 프로젝트와 무관한 동일 자격증명 | **machine_user** | 프로젝트마다 재로그인은 낭비이자 토큰 사본 증가 |
| 설치 비용이 크고 프로젝트별로 달라질 이유가 없음 | **machine_user** | 예: Google Workspace |
| 프로젝트의 코드·스키마·배포 대상에 묶임 | **project** | 예: Supabase, Prisma, 프로젝트 DB |
| 버전이 프로젝트 의존성과 함께 움직여야 함 | **project** | 예: Playwright |
| 판단이 애매함 | **project** | 기본값. `CORE.md 1.13`, `CAPABILITY_ACQUISITION §1.4` |

**`machine_user`는 예외이며, 카탈로그 스키마가 `install.kind == "shared_runtime"`일 때만 허용한다.**

## F4. 지침(정책)을 추가·수정하고 배포 — R4의 "추후 추가 지침"

```
[작성자 PC]
  1  policies/P27-<주제>.md 추가            (또는 기존 정책 수정)
  2  POLICY_INDEX.yaml 에 P27 항목 추가
       id / file / purpose / triggers / normal_coding
  3  ROUTER.md 에 새 경계(boundary) 추가     (필요한 경우만)
  4  PATCH_NOTES.md 에 항목 추가
  5  git commit → pre-commit 훅
       비밀 글롭 / 절대경로 / 비ASCII .ps1 검사
  6  git push → CI (validate.yml)
       - POLICY_INDEX의 모든 file: 이 디스크에 실제로 존재하는가
       - policy_count 와 실제 파일 수 일치
       - 카탈로그·매니페스트 스키마 유효
       - latest / * / ^ / ~ 핀 없음
       - 추적된 비밀값 없음
  7  git tag v3.1.0 (MINOR: 정책 추가)

[사용하는 PC]
  8  git -C "$env:LOCALAPPDATA\AI-Harness" pull
  9  (선택) bootstrap/install.ps1 재실행 — 멱등

[프로젝트]
 10  아무것도 안 해도 된다. 프로젝트는 사본이 아니라 포인터를 갖고 있다.
     다음 작업에서 ROUTER가 트리거를 매칭하면 P27이 JIT로 로드된다.
```

**주의:** 정책 파일명을 바꾸면 `POLICY_INDEX.yaml`의 `file:` 값을 **같은 커밋에서** 반드시 함께 바꿔야 한다. 안 그러면 Fast Health Check는 HEALTHY를 보고하고(정책 수 26 통과, 디렉터리 존재 통과), 정작 그 정책을 열려는 순간 BLOCKED가 된다. → CI에 "26개 `file:` 전부 실제 해석" 검사를 넣는다.

## F5. MCP 정보 추가 — R4의 "MCP 추가 정보"

```
1  catalogs/mcp-catalog.json 의 entries[] 에 항목 1개 추가
     {"id":"...","status":"verified|discovery_only","publisher":"...","official":true|false,
      "capabilities":[...],"domains":[...],"risk":"low|medium|high|critical",
      "platforms":[...],"install":{"kind":"...", ...}}
2  git push → CI
     - id 중복 없음
     - status=verified 인데 install.kind 가 미확인 좌표면 실패
     - npm 계열은 exact 버전 필수
     - discovery_only 는 설치 좌표를 가질 수 없음
3  끝. 스크립트 수정 없음.
     Search-HarnessCapability 가 즉시 검색하고,
     Install-ProjectMcp 가 kind 로 분기 처리한다.
```

## F6. 새 공용 런타임 추가 (AI-Tools 재사용 대상) — R2·R3의 확장

```
[Layer A: 레포에 선언]
  1  runtimes/<id>.runtime.json 작성 (§6.1 스키마)
  2  catalogs/mcp-catalog.json 항목을 kind: "shared_runtime" 으로
       {"install":{"kind":"shared_runtime","runtime_id":"<id>",
                   "manifest":"runtimes/<id>.runtime.json"}}
       ★ 카탈로그에는 package/version 을 쓰지 않는다. 핀은 매니페스트에만 존재
  3  CI: 절대경로 0, 핀 exact, platforms 정직성, server.env 에 비밀값 없음
  4  git push

[Layer B: 각 PC에서 1회]
  5  harness runtime install <id>
       - node>=22 확인
       - <tools_root>/<id>/ 에 npm install --ignore-scripts (exact 버전)
       - runtimes.json 에 state: installed 기록
       - ★ 런처(.cmd)를 생성하지 않는다. npm 의 .bin shim 을 그대로 쓴다
  6  harness runtime auth <id>            (인증이 필요한 런타임만)
       - 비밀 파일이 git 워크트리 안이거나 tools_root 안이면 거부
       - credentials.storage 로 복사 후 매니페스트의 auth_command 실행
  7  harness runtime verify <id>
       - 실제 read-only 프로브. 구조화된 결과 필드로 판정
       - 성공해야만 state: verified 기록 (증거 포함)
  8  harness clients sync
       - 설치된 CLI 를 탐지해 각각에 1회 등록
       - 이미 같은 fingerprint 로 등록돼 있으면 no-op

[Layer C: 프로젝트]
  9  .ai/harness.yaml capabilities.shared_runtimes 에 capability_id 추가
```

**순서 주의:** `install → auth → verify → sync`. 
등록(sync)을 인증보다 먼저 하면, 이미 떠 있는 stdio 서버 프로세스가 나중에 쓰인 토큰을 모른다. 디스크는 인증됐는데 살아있는 세션은 인증 안 된 상태가 만들어진다. **인증을 바꾸면 모든 클라이언트 세션을 재시작해야 한다**는 것을 `SHARED_RUNTIME.md`에 명시한다.

## F7. 새 AI 클라이언트 추가 — R5

```
1  settings/clients/<id>.client.json 1개 추가 (§6.3 스키마)
     detect / argv(probe·register·remove) / env_flag_template
     probe_semantics / register_is_upsert / verified_on
2  실제로 왕복 검증: 등록 → probe 로 읽힘 → 제거 → probe 로 안 읽힘
3  git push
4  각 PC 에서 harness clients sync 실행 시 자동 포함

※ 공식 설정 형식을 확인할 수 없는 CLI
   → 임의 설정 파일을 만들지 않는다.
   → <tools_root>/clients/pending/<id>.mcp.json 에 이식 가능한 설정만 남기고 PARTIAL 보고.
   → 이것이 현재 PROJECT_INIT §17.1 의 원칙이며 v3.0 에서도 유지된다.
```

**현재 3개 CLI의 확인된 사실** (§12-I)

| CLI | 설정 위치 | 키 | scope | 비고 |
|---|---|---|---|---|
| Claude Code | `~/.claude.json` (user/local), `.mcp.json` (project) | `mcpServers` | `local`/`project`/`user` | `claude mcp add -s <scope>` |
| Codex CLI | `~/.codex/config.toml` | `mcp_servers` (**snake_case**) | scope 플래그 없음 = 항상 전역 | 프로젝트 `.codex/config.toml`은 신뢰된 프로젝트만, 수동 편집 |
| AGY (Antigravity) | `~/.gemini/config/mcp_config.json` | `mcpServers` | 전역 | 원격 키가 `serverUrl` |
| *(Gemini CLI, 미사용)* | `~/.gemini/settings.json` | `mcpServers` | `user`/`project` | 원격 키가 `httpUrl`/`url` |

> ⚠ **AGY ≠ Gemini CLI.** 현재 하네스가 쓰는 `~/.gemini/config/mcp_config.json`은 Antigravity 공식 경로가 맞다. 하지만 Gemini CLI는 이 경로를 읽지 않는다(소스에 `mcp_config` 문자열 0건). 나중에 Gemini CLI를 추가할 때 같은 파일을 재사용하면 동작하지 않는다. **원격 서버 키 이름도 서로 호환되지 않는다.**

## F8. 플러그인 정보 추가 — R4의 "플러그인 정보"

두 가지를 구분해야 한다.

**(a) 플러그인 "정보"를 카탈로그에 담는 경우** (다른 사람이 만든 플러그인을 기록)
```
1  catalogs/plugin-catalog.json 에 항목 추가
     {"id":"...","client":"claude-code","source":"owner/repo",
      "provides":["skills","commands","mcp"],"official":true|false,
      "status":"verified|discovery_only","risk":"..."}
2  git push. 끝.
```

**(b) 이 하네스 자체를 Claude Code 플러그인으로 배포하는 경우** (선택 사항)
```
1  레포 루트에 .claude-plugin/marketplace.json
     {"name":"ai-harness","owner":{"name":"..."},
      "plugins":[{"name":"ai-harness","source":"./plugins/ai-harness"}]}
2  plugins/ai-harness/ 에
     .claude-plugin/plugin.json
     skills/          하네스 절차(초기화·Doctor·Capability 획득)를 Skill 로
     commands/        /harness-init, /harness-doctor
     .mcp.json        ${CLAUDE_PLUGIN_ROOT} 사용. 절대경로 금지
3  사용자: /plugin marketplace add <owner>/ai-harness  →  /plugin install ai-harness
```

**중요:** 플러그인은 `PROJECT_INIT.md`를 **대체하지 않는다.** Codex와 AGY는 이 메커니즘이 없다.
플러그인은 "Claude Code 사용자만 한 단계 더 편해지는 추가 채널"이며, **정본은 항상 Layer A의 파일**이다.
플러그인이 정본이 되면 Codex/AGY 사용자가 뒤처지고 마스터가 또 둘로 갈라진다.

## F9. 마이그레이션 · 롤백 · 사고 대응

**레거시 채택 (재설치·재로그인 없이)**
```
harness bootstrap -Migrate
  1  매니페스트의 legacy_install_dirs 를 전부 탐색
       ★ ["google-workspace-mcp"] ← 실제 디렉터리명. runtime_id 와 다르다 (§12-E)
  2  찾으면 그 디렉터리를 install_dir 로 "있는 그대로" runtimes.json 에 등록
  3  레거시 로케이터 AI_HARNESS_GOOGLE_MCP_COMMAND 도 후보로 읽는다
  4  각 CLI 의 실제 등록 상태를 읽어 clients.json 을 seed
  5  경로만 다른 경우는 remove + add 로 자동 재등록 (claude/codex/agy 모두 안전)
```

**롤백**
```
설치 경로를 <tools_root>/<runtime_id>/<version>/ 로 두고
runtimes.json 의 command_rel 이 활성 버전을 가리킨다
  → 롤백 = 포인터 전환. 두 버전이 공존한다. 재다운로드 없음
```
> **토큰 스냅샷은 기본적으로 만들지 않는다 (v1.1 개정).** 초판은 버전 변경 전 `credentials.storage`를 `.auth-snapshots/`로 복사하자고 했으나, 이는 "비밀값 사본 최소화" 원칙과 정면 충돌한다. 사본 하나가 늘면 유출 표면이 하나 늘어난다.
> 대신: 버전별 설치 디렉터리로 롤백을 해결하고, 토큰 포맷이 실제로 바뀌는 런타임만 매니페스트에 `credentials.state_format_version`을 선언한다. 포맷이 맞지 않으면 `verified`를 쓰지 않고 **재인증을 명시적으로 요구**한다.
> 스냅샷이 꼭 필요하면 `-SnapshotAuth` 명시 플래그 + 강한 ACL + 복원 직후 삭제를 강제한다.

**사고 대응 (`Disconnect-HarnessRuntime.ps1`)**
```
1  Google 에 refresh token 폐기 요청
2  tokens.json / credentials.json 안전 삭제
3  clients.json 에 기록된 모든 클라이언트에서 등록 제거
4  state 를 installed 로 되돌림
```
> 현재는 이 동사가 없다. 사용자가 Google 콘솔에서 앱 권한을 취소해도 파일은 남아 있고, 파일 존재만 보는 resolver는 계속 `authenticated: true`를 보고한다. 실제로 위험한 실패 모드다.

---

# 5. 확장 가이드 — "기능을 넣으려면 무엇을 하나" (R4에 대한 직접 답)

## 5.1 한 장 요약

| 추가하려는 것 | 만드는 파일 | 코드 수정 | 검증 | 배포 | 소비 시점 |
|---|---|---|---|---|---|
| **지침(정책)** | `policies/P27-*.md` + `POLICY_INDEX.yaml` 항목 | ❌ | CI: 매핑·개수·트리거 | `git push` → PC `git pull` | ROUTER 트리거 매칭 시 JIT |
| **MCP 정보** | `catalogs/mcp-catalog.json` 엔트리 1개 | ❌ | CI: 스키마·ID중복·핀 | `git push` | 카탈로그 검색 시 |
| **Skill 정보** | `catalogs/skill-catalog.json` 엔트리 1개 | ❌ | CI: 스키마·ID중복 | `git push` | 카탈로그 검색 시 |
| **플러그인 정보** | `catalogs/plugin-catalog.json` 엔트리 1개 | ❌ | CI: 스키마 | `git push` | 카탈로그 검색 시 |
| **공용 런타임** | `runtimes/<id>.runtime.json` + 카탈로그 엔트리 | ❌ | CI + PC별 실제 설치·검증 | `git push` → PC별 1회 install | Resolve가 찾음 |
| **AI 클라이언트** | `settings/clients/<id>.client.json` | ⚠ `adapter_kind: argv_cli` 로 표현 가능하면 ❌ | 등록↔probe 왕복 실측 | `git push` | `clients sync` |
| **운영 절차 문서** | `workflows/<NAME>.md` + INDEX paths | ❌ | 링크 유효성 | `git push` | 참조 시 |
| **하네스 자체 플러그인화** | `.claude-plugin/marketplace.json` + `plugins/` | ❌ | 매니페스트 스키마 | `git push` | `/plugin marketplace add` |
| 새 `install.kind` | 스키마 + 설치 스크립트 분기 | ✅ | — | MINOR 릴리스 | — |
| 새 계층/새 상태 | 다수 | ✅ | — | MAJOR 릴리스 | — |

**마지막 두 줄이 아래로 내려갈수록 설계가 좋은 것이다.** 위 8개는 전부 데이터다.

⚠ **"클라이언트 = 파일 1개"는 조건부다 (v1.1 개정).** 공식 CLI 명령으로 등록·조회·제거가 되는 클라이언트(`adapter_kind: "argv_cli"`)만 디스크립터 1개로 끝난다. 다음 경우에는 새 `adapter_kind`와 그 구현 코드가 필요하다.
- 출력이 JSON이 아닌 복잡한 대화형 UI
- 등록 명령이 OAuth 브라우저 흐름을 시작함
- 설정 파일이 JSON/TOML이 아니거나 주석 보존이 필요함
- 기존 설정과 안전하게 병합해야 함
- CLI 버전마다 명령 인자가 달라짐

따라서 정확한 목표 진술은 **"일반적인 CLI는 descriptor 1개로 추가하고, descriptor 계약으로 표현할 수 없는 클라이언트만 새 adapter kind를 구현한다"** 이다.

## 5.2 확장 불변식 (이걸 어기면 확장이 무너진다)

1. **핀은 한 곳에만 존재한다.** 현재 `3.4.4`가 스크립트 상수·manifest·카탈로그 3곳에 있다. 업그레이드 때 둘만 고치면 조용히 어긋난다. → 공용 런타임의 버전은 **매니페스트에만** 둔다.
2. **비밀 글롭도 한 곳에만 존재한다.** `.gitignore`, pre-commit 훅, CI, Drive 동기화 스크립트가 각자 목록을 갖고 있으면 반드시 갈라진다. → `schemas/never-sync.generated.json`을 매니페스트들로부터 생성하고, 네 소비자가 모두 그 파일을 읽게 한다.
3. **절대경로는 Layer A에 존재할 수 없다.** 보간은 `${HOME}` `${CONFIG_HOME}` `${TOOLS_ROOT}` `${RUNTIME_DIR}` + 선언된 `parameters` 키로 닫힌 집합만 허용.
4. **`platforms`는 정직해야 한다.** 실제로 설치·검증한 플랫폼만 적고 `platforms_verified_on` 날짜를 남긴다. 검증 안 한 플랫폼을 열려면 `-AllowUnverifiedPlatform`으로 시도하고 결과를 기록해 승격한다. (증거 없이 못 여는 필드는 영구 차단이 된다.)
5. **스키마 버전은 아티팩트마다 따로 관리한다.** 하네스 버전과 묶으면 사소한 문서 수정에도 전 PC가 스키마 불일치로 뜬다.
6. **정책 파일명 변경은 INDEX 수정과 같은 커밋에서.**

## 5.3 실제 예시 — "Notion MCP를 쓰고 싶다"

```
① 카탈로그에 이미 있는지 본다
     harness search notion
     → id: notion / status: verified / install.kind: registry_lookup / risk: high

② registry_lookup 이므로 좌표를 해석한다
     GET https://registry.modelcontextprotocol.io/v0.1/servers/{name}/versions/latest
     → packages[0] = {registryType:"npm", identifier:"...", version:"x.y.z"}

③ 범위를 정한다 (§F3 표)
     Notion 은 계정 인증이 필요하고 프로젝트와 무관 → machine_user 후보

④ 공용 런타임으로 승격
     runtimes/notion.runtime.json 작성 (버전은 ② 에서 얻은 exact 값)
     카탈로그 항목을 kind: shared_runtime + runtime_id: notion 으로 변경
     git commit + push

⑤ PC 에서 1회
     harness runtime install notion
     harness runtime auth notion
     harness runtime verify notion
     harness clients sync

⑥ 프로젝트에서
     .ai/harness.yaml capabilities.shared_runtimes 에 notion 추가
     → 이후 모든 프로젝트/모든 CLI 에서 재설치·재로그인 없이 사용
```

**여기서 수정한 스크립트: 0개.**

---

# 6. 스키마

## 6.1 `runtimes/<id>.runtime.json` (Layer A)

```jsonc
{
  "schema_version": "2.0",
  "runtime_id": "google-workspace",
  "capability_id": "google-workspace-local",
  "server_name": "google-workspace",
  "display_name": "Google Workspace MCP (공용 머신 런타임)",
  "scope": "machine_user",
  "risk": "high",
  "platforms": ["windows"],
  "platforms_verified_on": "2026-08-23",
  "legacy_install_dirs": ["google-workspace-mcp"],
  "requires": { "node": ">=22", "npm": true },

  "install": {
    "kind": "npm_pinned",
    "package": "@dguido/google-workspace-mcp",
    "version": "3.4.4",
    "pinned_at": "2026-08-23",
    "npm_args": ["--ignore-scripts"],
    "bin_name": "google-workspace-mcp"
  },

  "server": {
    "transport": "stdio",
    "args": ["start"],
    "env": {
      "GOOGLE_WORKSPACE_SERVICES": "${services}",
      "GOOGLE_WORKSPACE_MCP_PROFILE": "${profile}",
      "GOOGLE_WORKSPACE_READ_ONLY": "${read_only}",
      "GOOGLE_WORKSPACE_TOON_FORMAT": "true"
    },
    "env_from": {}
  },

  "parameters": {
    "profile":   { "type": "string",  "default": "default" },
    "services":  { "type": "string",  "default": "drive,gmail,calendar,docs,sheets,slides" },
    "read_only": { "type": "boolean", "default": false }
  },

  "tool_policy": {
    "deny":   ["delete_email", "empty_trash", "batch_delete", "remove_permission"],
    "approve":["send_email", "share_file", "batch_share", "delete_item",
               "delete_event", "delete_contact", "create_filter", "delete_draft"],
    "note": "deny=노출 자체를 막는다(가능한 클라이언트에서). approve=노출하되 호출 직전 승인. 그 외는 자유 사용."
  },

  "credentials": {
    "storage": "${CONFIG_HOME}/google-workspace-mcp/profiles/${profile}",
    "required_files": ["credentials.json"],
    "auth_state_files": ["tokens.json"],
    "auth_command": { "bin": "google-workspace-mcp", "args": ["auth", "--profile", "${profile}"] },
    "never_sync": ["credentials.json", "tokens.json", "client_secret*.json"]
  },

  "verify": {
    "tool": "get_status",
    "assert": [
      { "json_path": "$.status", "equals": "ok" },
      { "json_path": "$.auth.token_status", "equals": "valid" }
    ]
  }
}
```

**설계 판단 3가지**

1. **런처(.cmd)를 생성하지 않는다.** 현재는 배치 파일을 만들어 등록하는데, 이것 하나가 네 가지 이식성 문제의 공통 원인이다. (ASCII 인코딩으로 비ASCII 경로 손상 / 유닉스 실행 불가 / 절대경로가 파일 내용에 박힘 / env 설정이 클라이언트에 안 보임) npm이 만드는 `node_modules/.bin/` shim을 그대로 쓴다.
2. **`services`·`read_only`·`tool_policy`를 파라미터/선언으로 올린다.** 지금은 7종 전부가 상수로 박혀 있어 OAuth 스코프도 전부 받는다.
   단 **`read_only`의 기본값은 `false`다.** 사용자는 Drive 업로드·Docs/Sheets 수정·Gmail 초안/발송·Calendar 생성을 실제로 원한다. 런타임 전체를 읽기 전용으로 잠그면 그 요구가 깨진다.
   위험은 범위가 아니라 **도구 단위**로 통제한다 → `tool_policy.deny`(영구 삭제 계열)와 `tool_policy.approve`(발송·공유·삭제·일정 변경). 이것이 §8-4의 실제 강제 지점이다.
   `services`에서 `contacts`만 뺀 것은 실사용 근거가 없기 때문이며, 필요하면 파라미터로 되돌린다.
3. **`verify`를 exit code가 아니라 구조화된 필드로 판정한다.** `get_status`는 문제가 있어도 성공한 도구 호출로 반환된다. 실제로 이 세션 중 같은 호출이 `[WARN] Issues: token_file` → `[OK] No issues detected`로 바뀌는 것을 관찰했다(§12-F). exit 0으로 `verified`를 쓰면 인증 안 된 런타임을 인증됐다고 기록하게 된다.

## 6.2 `<tools_root>/runtimes.json` (Layer B, git 금지)

```jsonc
{
  "schema_version": "2.0",
  "tools_root": "C:\\Users\\<사용자>\\AppData\\Local\\AI-Tools",
  "tools_root_id": "7f1c…",
  "harness_root_id": "b93a…",
  "harness_version_at_write": "3.0",
  "updated_at": "2026-08-23T05:11:04Z",
  "runtimes": {
    "google-workspace": {
      "runtime_id": "google-workspace",
      "capability_id": "google-workspace-local",
      "server_name": "google-workspace",
      "manifest_core_sha256": "sha256:…",
      "package": "@dguido/google-workspace-mcp",
      "declared_version": "3.4.4",
      "installed_version": "3.4.4",
      "install_dir": "google-workspace/3.4.4",
      "command_rel": "google-workspace/3.4.4/node_modules/.bin/google-workspace-mcp.cmd",
      "command_sha256": "sha256:…",
      "args": ["start"],
      "env": { "…": "…" },
      "parameters": { "profile": "default", "services": "drive,gmail,calendar", "read_only": true },
      "platform": "windows",
      "state": "verified",
      "installed_at": "…",
      "last_verified_at": "…",
      "verify_ttl_hours": 168,
      "last_verify_evidence": { "tool": "get_status", "status": "ok", "token_status": "valid", "at": "…" }
    }
  }
}
```

- 경로는 tools_root **상대**로 저장한다 → 루트가 옮겨져도 해석된다.
- `command_sha256`을 둔다 → 경로 문자열만 해싱하는 지문은 **실행 파일 교체를 탐지하지 못한다**(§8-1).
- `manifest_core_sha256`은 파일 전체가 아니라 `{install, server, parameters, credentials, verify}`만 정규화해 해싱한다 → 오탈자 수정에 전 PC가 drift로 뜨는 것을 막는다.
- `verify_ttl_hours` 경과 시 `verified` → `stale_verified`로 감쇠한다 → 몇 달 전 검증이 영원히 유효한 척하지 않는다.

## 6.3 `settings/clients/<id>.client.json` (Layer A)

```jsonc
{
  "schema_version": "1.0",
  "client_id": "claude",
  "display_name": "Claude Code",
  "detect": { "command": "claude" },
  "verified_on": "2026-08-23",
  "adapter_kind": "argv_cli",
  "config_home_env": null,
  "config_path_is_authoritative": false,
  "supports": { "scopes": ["local","project","user"], "env_flag": "-e", "drift_detection": true },
  "tool_policy_support": {
    "deny_reduces_context": "server_only",
    "deny_mechanism": { "file": ".claude/settings.json", "key": "permissions.deny",
                        "pattern": "mcp__{server_name}__{tool}" },
    "approve_mechanism": { "file": ".claude/settings.json", "key": "permissions.ask",
                           "pattern": "mcp__{server_name}__{tool}" },
    "per_project_disable": { "file": "~/.claude.json", "key": "disabledMcpServers" }
  },
  "argv": {
    "probe":    ["mcp","get","{server_name}"],
    "register": ["mcp","add","-s","{scope}","{env_flags}","{server_name}","--","{command}","{args}"],
    "remove":   ["mcp","remove","{server_name}","-s","{scope}"]
  },
  "env_flag_template": ["-e","{key}={value}"],
  "probe_parse": { "kind": "kv_text", "command_key": "Command:", "args_key": "Args:" },
  "register_is_upsert": false
}
```

**`adapter_kind`가 탈출구다.** `argv_cli`(공식 CLI 명령으로 등록)로 표현할 수 있는 클라이언트는 이 파일 하나로 끝난다. 그러나 **모든 클라이언트가 그렇지는 않다.** 대화형 UI만 제공하거나, 등록이 OAuth 브라우저 흐름을 시작하거나, 설정 파일이 주석 보존을 요구하거나, CLI 버전마다 인자가 달라지는 경우에는 `adapter_kind`를 새로 정의하고 그 kind의 코드를 구현해야 한다.
따라서 목표는 "모든 클라이언트가 파일 1개"가 아니라 **"일반적인 CLI는 파일 1개, 표현 불가능한 것만 새 adapter kind"** 다.

**`config_path_is_authoritative: false` 는 타협이 아니라 규칙이다 (v1.1 실측 반영).**
설정 파일 경로를 **절대 가정하지 않는다.** 상태의 유일한 권위는 CLI 자신의 probe 명령이다.
근거: 이 PC에서 Codex 의 `CODEX_HOME` 이 프로세스 범위로 `%APPDATA%\orca\codex-accounts\<uuid>\home` 으로 재정의돼 있었다(다계정 래퍼). `~/.codex/config.toml` 을 읽는 검사는 **영원히 틀린 답**을 준다. `codex mcp list --json` 만이 맞았다.
`config_home_env`(예: `"CODEX_HOME"`)는 사용자에게 실제 위치를 *안내*할 때만 쓰고, 판정에는 쓰지 않는다.

**`tool_policy_support`가 §8-4를 실행 가능하게 만든다.** Layer A의 매니페스트는 *의도*(이 도구는 위험하다)만 선언하고, 각 클라이언트의 네이티브 메커니즘으로 **번역**하는 책임은 디스크립터가 진다. 세 CLI의 실제 능력이 서로 다르기 때문에 이 분리가 필수다(§12-K).

**핵심:** `probe`는 "있다/없다"만 반환하면 안 되고 **실제 등록된 command를 읽어와야** 한다.
`claude mcp get`은 Command/Args/Environment를 출력한다(§12-D). 그것을 파싱한다.
읽을 수 없는 클라이언트는 `drift_detection: false`로 선언하고, Doctor는 OK가 아니라 **UNKNOWN**을 보고한다.

> 이게 없으면 원장(clients.json)은 "내가 등록했다고 믿는 것"만 기록하게 되고, 실제 클라이언트 상태와 갈라져도 영원히 "정상"이라고 보고한다.

## 6.4 카탈로그 변경

```jsonc
// mcp-catalog.json  policy 블록에 추가
"shared_runtime_requires_manifest": true,
"shared_runtime_dir": "runtimes",
"shared_runtime_version_source": "manifest"   // 카탈로그는 핀을 재기술하지 않는다

// 엔트리 레벨에 선택 필드 추가
"default_scope": "project" | "machine_user"   // machine_user 는 kind=shared_runtime 일 때만 허용
```

`Install-ProjectMcp.ps1`에 가드 추가:
```powershell
} elseif ($kind -eq 'shared_runtime') {
    throw "MCP '$Id' 는 공용 머신 런타임입니다. PC 당 1회 " +
          "Install-HarnessRuntime.ps1 -RuntimeId $($entry.install.runtime_id) 로 설치하고 " +
          ".ai/harness.yaml 에서 참조하세요. 프로젝트별로 설치하지 마세요."
}
```
이 가드가 없으면 기존 npm 분기가 Google 패키지를 아무 프로젝트에나 devDependency로 설치해서, 핀 없는 두 번째 사본과 두 번째 OAuth 표면을 만든다.

## 6.5 `capability-lock.schema.json` 1.0 → 1.1

| 필드 | 1.0 | 1.1 |
|---|---|---|
| `scope` | `const: "project"` | `enum: ["project","machine_user","client_user"]` |
| `project_root` | required | **optional** (기본 미기록 — 다른 PC에서 틀린 값이 됨) |
| `harness_version_at_write` | 없음 | 추가 |
| `min_harness_version` | 없음 | 추가 |

그리고 `Test-ProjectCapabilities.ps1:34`의 `scope -ne 'project' → FAIL`을 scope별 규칙으로 분리한다.
**현재 상태로는 공용 런타임을 기록하는 순간 Doctor가 영구 FAIL을 낸다.** (§12-C)

---

# 7. 버전·호환·업그레이드

## 7.1 네 개의 독립 축

| 축 | 위치 | 의미 |
|---|---|---|
| 하네스 교리 버전 | `POLICY_INDEX.yaml: harness_version` + git tag | MAJOR=계약 파괴 / MINOR=정책·카탈로그·런타임 추가 / PATCH=문구 |
| 계약 스키마 버전 | 각 `schemas/*.json` | 아티팩트마다 독립 |
| 런타임 패키지 핀 | `runtimes/<id>.runtime.json: install.version` | 한 곳에만 |
| 머신/프로젝트 상태 | `runtimes.json`, `.ai/harness.yaml` | 기록·비교만. 자동 마이그레이션 안 함 |

## 7.2 버전 바닥(floor) 검사 — **v3.0 릴리스 전에 2.2.1로 백포트해야 함**

```
Dev A: 하네스 3.0 으로 업그레이드 → .ai/harness.yaml 에 shared_runtimes 추가하고 커밋
Dev B: 아직 2.2 → 그 프로젝트에서 Test-ProjectCapabilities 실행
       현재 코드: scope != project 이므로 FAIL
       스키마 1.0: project_root required, additionalProperties:false 이므로 FAIL
       → "당신 하네스가 낡았다" 는 신호가 어디에도 없다. CI 만 빨개진다
```
**해결:** 모든 스크립트의 첫 동작을 버전 바닥 검사로 만들고, 전용 종료코드와 함께
`"이 프로젝트는 하네스 3.0 이상이 필요합니다. <harness_root> 에서 git pull 하세요"`를 출력한다.

**2.2.1 백포트는 조건부다 (v1.1 개정).**
현재 하네스는 git 저장소도 아니고 배포된 릴리스도 아니며 이 PC 한 대에서만 쓰인다. 2.2를 쓰는 다른 사본이 존재하지 않으므로 백포트할 대상이 없다.
```
단일 PC        → 현재 상태를 v2.2.0 태그로 보존하고 바로 v3.0 으로 간다. 2.2.1 불필요
다중 PC / 팀   → 2.2 를 쓰는 사본이 3.0 프로젝트를 먼저 열 수 있으므로 2.2.1 필요
```
어느 경우든 **버전 바닥 "검사" 자체는 v3.0 스크립트에 넣는다.** 비용이 거의 없고, 두 번째 PC가 생기는 시점에 이미 작동하고 있어야 하기 때문이다.

## 7.3 종료 코드 (현재 resolver는 "없음"과 "스크립트 실패"를 둘 다 `exit 1`로 낸다)

```
0  발견, 드리프트 없음
2  발견, 비긴급 드리프트 (manifest_changed 등 문서 수정)
3  발견, 조치 필요 드리프트 (version_drift, command_missing)
4  없음 (absent)  ← 오류가 아님
5  tools root / 인덱스 읽기 불가
1  스크립트 오류
```

---

# 8. 보안 규칙

## 8-1. 공용 도구 루트의 무결성

```
실측: (Get-Acl 'C:\AI-Tools').Access
  NT AUTHORITY\Authenticated Users    Modify, Synchronize    (C:\ 루트에서 상속)
```
`C:\` 바로 아래 만든 폴더라 이 ACL을 물려받았다. **관리자 권한 없이** 이 PC의 다른 계정이나 임의 프로세스가 MCP 실행 파일을 교체할 수 있고, 교체된 파일은 다음 `claude` 실행 때 사용자 권한으로 실행되면서 Gmail/Drive 토큰을 그대로 물려받는다.

**규칙**
1. tools root는 `%LOCALAPPDATA%\AI-Tools`로 이전하고 ACL을 소유자/SYSTEM/Administrators로 제한한다.
2. `Resolve`/`Register`/`Test`가 경로 신뢰성을 검사한다. 그 외 주체에게 쓰기 권한이 있으면 **경고가 아니라 거부**(exit 5).
3. **무결성 검증은 실행 파일 1개의 해시로는 부족하다 (v1.1 개정).**
   `node_modules/.bin/google-workspace-mcp.cmd`는 얇은 shim일 뿐이고 실제 페이로드는 `dist/index.js`다. shim이 그대로여도 JS가 변조되면 `command_sha256`은 통과한다.
   → 다음을 **함께** 적용한다.
   - `runtimes/<id>.lock.json` (npm shrinkwrap)을 **Layer A에 커밋**하고 설치는 `npm ci --ignore-scripts`로 한다. 직접 의존성 1개만 고정하고 전이 의존성을 매번 새로 해석하면 그것은 핀이 아니라 "그날 레지스트리가 준 것의 기록"일 뿐이다. (이 런타임은 전이 의존 디렉터리가 161개다.)
   - 매니페스트에 `install.integrity`(npm dist.integrity, sha512)를 기록하고 `risk: high`면 필수로 강제한다.
   - `runtimes.json`에 설치 디렉터리 전체의 파일 매니페스트 해시(트리 해시)를 기록하고, 불일치 시 `npm ci --ignore-scripts`로 복원을 제안한다.
   - `command_sha256`은 유지하되 **1차 방어선이 아니라 빠른 사전 검사**로만 취급한다.

## 8-2. 자격증명 위치

```
실측 SHA256 (동일):
  C:\AI-Tools\client_secret_720670798168-….json            12CFC33F7BBEF354…
  %USERPROFILE%\.config\…\profiles\default\credentials.json 12CFC33F7BBEF354…
```
AI-Tools 쪽 사본은 불필요하며, 8-1의 ACL 폴더 안에 있다. **읽히면** 사용자의 Google 계정이 이미 신뢰하는 Desktop OAuth 앱의 client_id/secret이 유출되고, **바꿔치기당하면** 다음 재인증 때 공격자의 OAuth 프로젝트로 토큰이 발급된다(사용자에게는 정상 동의 화면으로 보인다).

**규칙**
0. **기존 토큰은 복사하지 않고 그 자리에서 재사용한다.** 토큰 저장소는 `%USERPROFILE%\.config\...`에 있고 tools root 밖이므로, tools root를 옮겨도 **재인증이 필요 없다.** 이전 작업이 토큰을 건드리지 않는다는 점을 마이그레이션 절차에 명시한다.
1. `Connect-HarnessRuntimeAuth`는 소스 경로가 (a) git 워크트리 안 (b) tools_root 안 (c) 그룹/전체 쓰기 가능 중 하나라도 해당하면 **거부**한다. "git 밖이면 안전"은 보안 속성이 아니다.
2. 자격증명 sha256을 기록해 바꿔치기를 브라우저가 열리기 **전에** 탐지한다.
3. never_sync 글롭 검사를 `git ls-files`뿐 아니라 **tools_root 전체**에 대해서도 수행한다.

## 8-3. git 방어는 "프로젝트 저장소"에도 설치해야 한다

`.gitignore` + pre-commit + CI를 하네스 레포에만 두는 것은 **비밀값이 없는 곳을 지키는 것**이다. 실제로 client_secret이 떨어지는 곳은 사용자가 작업하는 프로젝트 저장소다.
→ `Test-ProjectCapabilities`가 프로젝트에서 `git ls-files` 검사를 수행한다. **CI를 1차 방어선으로 삼는다.**
→ 하네스 `.gitignore`의 `.ai/` 패턴을 **프로젝트로 복사하면 안 된다.** Layer C는 커밋되어야 한다.

⚠ **`core.hooksPath`를 프로젝트에서 자동으로 바꾸지 않는다 (v1.1 개정).**
기존 프로젝트가 이미 자체 훅(lint, 테스트, 서명 검사)을 쓰고 있을 수 있고, `core.hooksPath`를 덮어쓰면 **그 훅들이 조용히 사라진다.** 보안을 높이려다 프로젝트 방어를 낮추는 결과가 된다.
```
hooksPath 미설정            → 하네스 훅 디렉터리를 설치한다
hooksPath 이미 설정됨       → 건드리지 않는다. 기존 훅에 체인 추가를 "제안"만 한다
체인 방식을 확정할 수 없음  → Doctor 경고로 남기고 CI 검사에 의존한다
```
하네스 저장소(Layer A) 자체에는 부트스트랩이 훅을 설치해도 된다. 그건 하네스가 소유한 저장소다.

## 8-4. 위험도(risk) 태그에 실제 효력을 준다

현재 `risk: "high"`는 기록만 될 뿐 아무 동작도 바꾸지 않는다.

**규칙 (v1.1 개정 — 이전 판의 "project 범위로 전환" 권고는 철회한다)**

사용자의 원래 목표는 *"어느 AI의 어느 프로젝트에서도 Google 작업을 바로 사용한다"* 이다. 등록 범위를 project로 내리면 새 프로젝트마다 등록 절차가 생겨 이 목표와 정면 충돌한다.
따라서 **공용(user/global) 등록을 유지하고, 위험과 비용은 범위가 아니라 각 CLI의 네이티브 도구 통제 기능으로 해결한다.**

1. **공용 등록 유지.** 단 `risk: high` 런타임의 최초 공용 등록은 명시적 승인을 1회 요구하고 `clients.json`에 승인 사실을 기록한다.
2. **매니페스트가 `tool_policy: {deny:[], approve:[]}` 를 선언**하고, 클라이언트 디스크립터의 `tool_policy_support`가 각 CLI의 실제 메커니즘으로 번역한다(§6.3).
3. **CLI별 실제 능력이 다르므로 기대치를 다르게 잡는다** (§12-K 검증됨):

| CLI | 도구 단위 차단 | 컨텍스트 감소 | 승인 게이트 | 서버 단위 프로젝트별 비활성화 |
|---|---|---|---|---|
| **Claude Code** | `permissions.deny` = `mcp__srv__tool` | ❌ (스코프 룰은 실행만 차단) | `permissions.ask` | ✅ `/mcp` 토글 → `disabledMcpServers` |
| **Codex CLI** | `disabled_tools` / `enabled_tools` | ✅ (모델 목록 생성 **전에** 제거) | `default_tools_approval_mode = "writes"` | ❌ (scope 개념 없음) |
| **Gemini CLI** | `excludeTools` / `includeTools` | ✅ (discovery 단계에서 제거) | ❌ (`trust`는 확인을 *건너뛸* 뿐) | ✅ `mcp.excluded` |
| **AGY (Antigravity)** | **미검증** | 미검증 | 미검증 | 미검증 |

4. **Claude Code의 컨텍스트 비용은 서버 단위로만 조절된다.** `mcp__google-workspace` (bare) deny는 스키마를 컨텍스트에서 아예 제거하지만, `mcp__google-workspace__delete_email` (scoped) deny는 스키마를 남기고 실행만 막는다. 따라서 Claude Code에서 토큰을 줄이는 수단은 **① `services` 축소 ② 불필요한 프로젝트에서 `/mcp` 토글로 서버 비활성화** 둘뿐이다.
5. **중복 커넥터를 먼저 정리한다.** 이것이 가장 효과가 크다(아래 근거).

**근거 (실측)**
- 도구 88개 / 스키마 89,171바이트 ≈ **세션당 25,000 토큰**.
- `claude mcp list` 실측: `claude.ai Google Drive` / `claude.ai Gmail` / `claude.ai Google Calendar`가 `google-workspace`와 **동시에 Connected**. 이름이 정확히 같은 도구 15개(`delete_event`, `send_email`, `share_file`, `create_file`, `list_events`, `update_label` …)가 공존하며 **서로 다른 계정으로 인증**돼 있다. 모델이 40자 남짓한 설명으로 둘을 구분해야 하고, 잘못 고르면 엉뚱한 계정에 작업한다.
- `delete_email` 설명 = "Delete emails permanently (max 1000 IDs per request)". 휴지통이 아니라 **영구 삭제**이며, `delete_item`(휴지통) / `batch_delete`(휴지통) / `empty_trash`(영구)와 구분해야 한다. → `tool_policy.deny` 대상.

**권고 조합**
```
Claude Code : claude.ai Gmail/Drive/Calendar 커넥터 비활성화  ← 충돌 15건 + 중복 토큰 동시 제거
              google-workspace 는 user scope 유지 (목표 달성)
              permissions.ask 에 approve 목록, permissions.deny 에 deny 목록
              Google 과 무관한 프로젝트는 /mcp 토글로 서버 자체를 끈다
Codex CLI   : disabled_tools = deny 목록            ← 컨텍스트도 함께 감소
              default_tools_approval_mode = "writes" ← 읽기는 자유, 쓰기는 승인
AGY         : 메커니즘 확인 후 결정 (미검증)
```

**근거 (실측)**
- 도구 88개 / 스키마 89,171바이트 ≈ **세션당 25,000 토큰**. 정책 26개(1,100KB)를 JIT로 아끼는 설계인데 정책 2개 분량을 무조건 되돌려준다.
- claude.ai 내장 Gmail/Drive/Calendar 커넥터와 **이름이 정확히 같은 도구 15개**: `delete_event`, `send_email`, `share_file`, `create_file`, `list_events`, `update_label` 등. 둘은 **서로 다른 계정**으로 인증돼 있다. 모델이 잘못 고르면 엉뚱한 계정에 작업한다.
- `delete_email` 설명 = "Delete emails permanently (max 1000 IDs per request)". 휴지통이 아니라 영구 삭제이며, 40자 남짓한 설명으로 `delete_item`(휴지통), `batch_delete`(휴지통), `empty_trash`(영구)와 구분해야 한다.

## 8-5. 마스터는 하나

`sync-harness-to-drive.mjs`는 **삭제 패스가 없고**, 제외 목록이 `credentials|tokens|client_secret` 하드코딩 정규식이며, 업데이트 실패 시 `create_file`로 폴백해서 **같은 이름의 형제 파일**을 만든다.
→ v3.0의 리네임·삭제가 Drive에 반영되지 않아 옛 파일이 영구히 남는다. 3개월 뒤 Drive에서 옛 `manifest.json`을 읽고 옛 핀을 설치하는 사고가 난다.

**규칙**
- **GitHub를 유일 마스터로 한다.** Drive는 `/AI-Harness-snapshots/v3.0.0/` 형태의 읽기 전용 스냅샷으로 강등한다.
- 계속 동기화하려면 파일 목록을 파일시스템 walk가 아니라 `git ls-files`에서 뽑고, 추가/수정/**삭제**를 전부 반영하며, 실패 시 create 폴백을 하지 않고, 제외 목록을 `never-sync.generated.json`에서 읽어야 한다.

## 8-6. 인코딩은 보안 통제다

이 PC의 ANSI 코드페이지는 949이고 작업 디렉터리는 `C:\윈도우 세팅공간`이다.
`~/.codex/config.toml`을 인코딩 지정 없이 읽으면 `[projects."C:\\?덈룄???명똿怨듦컙"]`로 깨진다(명시적 UTF-8로 읽으면 정상).
경로가 깨지면 **자격증명을 어디서 읽고 어디에 쓰는지가 조용히 바뀐다.**

**규칙 (v1.1 개정 — "ASCII 전용"은 과도해서 철회)**

문제의 원인은 비ASCII 문자 자체가 아니라 **Windows PowerShell 5.1 + BOM 없는 UTF-8** 조합이다. 5.1은 BOM이 없으면 파일을 ANSI 코드페이지(여기서는 949)로 디코딩한다. **BOM이 있으면 정상 디코딩된다.**

- **`.ps1` 소스는 UTF-8 with BOM으로 통일한다.** 한글 메시지를 그대로 쓸 수 있다.
  CI 검사: 모든 추적된 `.ps1`이 `EF BB BF`로 시작하는지 원시 바이트로 확인.
  ⚠ `.gitattributes`로 BOM을 *부여*할 수는 없다(`working-tree-encoding=UTF-8`은 무의미). 하지만 BOM은 파일 **내용**이므로 BOM을 포함해 커밋하면 그대로 보존된다. → 강제는 `.gitattributes`가 아니라 **CI 바이트 검사**로 한다.
- **JSON은 BOM 없이 기록한다.** (`JSON.parse`와 npm이 선행 U+FEFF를 거부한다.)
- `Read-HarnessJson` / `Write-HarnessJson`을 만들고 맨몸 `Get-Content`를 lint로 금지한다.
  5.1의 `-Encoding utf8`은 **BOM 포함**, 7은 **BOM 없음** — 같은 코드가 PC마다 다른 바이트를 만든다. 그래서 `[IO.File]::ReadAllText/WriteAllText` + 명시적 `UTF8Encoding($false)`를 쓴다.
- 네이티브 CLI stdout을 캡처하는 스크립트는 `[Console]::OutputEncoding`을 UTF-8로 설정한다.
- 지문(fingerprint) 입력은 정규화된 전체 경로를 UTF-8 바이트로 해싱한다. 호스트 문자열을 그대로 해싱하면 비ASCII 경로에서 영구 드리프트가 난다.

---

# 9. 마이그레이션 계획 (2.2 → 3.0)

v1.1에서 순서를 보안 우선으로 재배열했다. **보안 결함이 실제로 확인된 상태이므로 tools root 이전(구 M7)을 v3.1로 미루지 않고 v3.0에 포함한다.**

| 단계 | 작업 | 되돌릴 수 있나 | 왜 이 순서인가 |
|---|---|---|---|
| **M0** | `C:\AI-Tools\client_secret_*.json` 사본 삭제 | ✅ (프로필에 동일본, SHA256 일치 확인) | 노출 시간 최소화 |
| **M1** | `Initialize-…ps1:56` 괄호 수정 | ✅ | 1줄. AGY 초기화가 죽는 원인 |
| **M2** | Codex 수동 등록 + `codex mcp get`으로 확인 | ✅ | 현재 **미등록 상태**(§12-D). "등록했다"와 "등록됐다"는 다르다 |
| **M3** | `C:\AI-Harness` → Private GitHub 저장소 (`.gitignore`/`.gitattributes`/pre-commit 포함) | ✅ | 이후 모든 변경이 되돌릴 수 있게 됨 |
| **M4** | 현재 상태를 `v2.2.0` 태그로 고정 | ✅ | 마이그레이션 시작점. 2.2.1 백포트는 불필요(§7.2) |
| **M5** | tools root를 `%LOCALAPPDATA%\AI-Tools`로 이전 + ACL 제한 | ⚠ 재등록 필요 | **보안 우선.** 토큰은 `%USERPROFILE%`에 있어 재로그인 없음 |
| **M6** | `_Harness.Common.ps1` + 기존 6개 스크립트 경로·인코딩 수정 | ✅ | 이후 모든 신규 스크립트의 기반 |
| **M7** | Layer A/B/C + `runtimes/` + resolver/installer/registrar, 핀 단일화, `npm ci` + lock | ✅ | R2·R3의 본체 |
| **M8** | 기존 OAuth 토큰을 **복사하지 않고** 그대로 재사용 확인 | ✅ | 사본 증가 방지(§8-2 규칙 0) |
| **M9** | Codex·Claude·AGY를 새 경로로 재등록 + 등록 후 재-probe 확인 | ✅ | 원장과 실제 상태 일치 |
| **M10** | 실제 읽기 작업 1건으로 검증 (`get_status` 아님 — 실 API 호출) | ✅ | `verified`의 근거 확보 |
| **M11** | 중복 커넥터 정리 + `tool_policy` 적용 (deny/approve) | ✅ | 충돌 15건 + 위험 도구(§8-4) |
| **M12** | Drive를 버전별 스냅샷 저장소로 전환 | ✅ | 마스터 이중화 제거 |
| **M13** | registry lookup / plugin catalog / CI 확장 | ✅ | 순수 확장 |
| **M14** | (선택) 정책 파일명 ASCII 리네임 + INDEX 동시 수정 | ⚠ Drive 정리 필요 | 크로스플랫폼. 급하지 않음(D4) |

**M0~M4는 나머지와 독립적이다.** 제안 검토 결과와 무관하게 먼저 해도 손해가 없다.

---

# 10. 결정이 필요한 항목 (추천안 포함)

| # | 결정 | 선택지 | **추천** | 이유 |
|---|---|---|---|---|
| D1 | 저장소 공개 범위 | Public / Private | **Private** | 정책 26개는 사용자 자산. 플러그인 마켓플레이스도 private 저장소에서 되는지는 **미검증**(§11 V7) |
| D2 | 저장소 개수 | 단일 / 하네스+툴 분리 | **단일 `ai-harness`** | 버전 정합을 태그 하나로 관리. 분리하면 두 축이 어긋남 |
| D3 | tools root 위치 | `C:\AI-Tools` 유지 / `%LOCALAPPDATA%` 이전 | **이전** | ACL(§8-1). 이전해도 재설치·재로그인 없음 |
| D4 | 정책 파일명 | 한글 유지 / ASCII 리네임 | **일단 유지, M11로 연기** | 지금 이득은 크로스플랫폼뿐인데 Windows 단독 사용 중. 리네임 시 Drive/INDEX 동시 처리 필요 |
| D5 | 스크립트 언어 / 플랫폼 약속 | PowerShell 유지 / Node 전환 | **PowerShell 유지 + `platforms: ["windows"]` 정직 선언 + `install.sh`를 v3.0 범위에서 제외** | 이 PC에 `pwsh` 없음. 초판은 `install.sh`를 두면서 D5는 Windows 전용이라 해 **모순**이었다. 유닉스 지원은 실제 요구가 생길 때 Layer C 스크립트만 Node로 전환 |
| D6 | Google Drive 마스터 | 유지 / 스냅샷 강등 / 폐기 | **스냅샷 강등** | 삭제 패스 없는 동기화는 반드시 갈라짐(§8-5). Codex도 동의 |
| **D7** | Google 등록 범위 | user 유지 / project 전환 | **user(공용) 유지** ← *v1.1에서 뒤집음* | project 전환은 "어느 프로젝트에서든 바로 사용"이라는 원래 목표와 충돌. 토큰·충돌은 범위가 아니라 각 CLI의 도구 통제 기능으로 해결(§8-4, §12-K) |
| **D8** | Google 쓰기 권한 | 전체 read-only / 쓰기 유지 + 도구별 통제 | **쓰기 유지 + `tool_policy`** ← *v1.1에서 뒤집음* | Drive 업로드·Docs 수정·메일 초안/발송·일정 생성은 실제 요구사항. 영구삭제 계열만 deny, 발송·공유·삭제·일정변경은 승인 게이트 |
| D9 | `capability-lock.json` 커밋 | 커밋 / 로컬 전용 | **커밋 (단 `project_root` 제거)** | 팀 공유가 목적. 머신 고유 값만 빼면 됨 |
| **D10** | v3.0 범위 | 전체 / 단계 분할 | **보안(M0~M5)을 v3.0에 포함** ← *v1.1에서 변경* | 보안 결함이 확인된 상태이므로 tools root 이전·ACL을 v3.1로 미루지 않는다 |
| **D11** | 중복 Google 커넥터 | claude.ai 커넥터 끄기 / google-workspace 끄기 / 둘 다 유지 | **Claude Code에서 claude.ai Gmail·Drive·Calendar 커넥터를 끈다** | 이름 충돌 15건 제거 + 계정 일원화 + 토큰 절감을 동시에 달성. google-workspace만 Docs/Sheets/Slides 편집을 제공 |
| **D12** | Google `services` 목록 | 7종 전부 / `contacts` 제외 / 3종 | **`drive,gmail,calendar,docs,sheets,slides`** | Docs/Sheets/Slides는 실사용 요구. `contacts`만 실사용 근거 없음 |
| **D13** | AGY 도구 통제 메커니즘 | — | **확인 후 결정 (현재 미검증)** | Antigravity의 도구 필터/승인 기능 유무를 확인해야 §8-4 표가 완성된다 |

---

# 11. 수락 기준 (구현 후 이걸로 검증한다)

| # | 검증 항목 | 통과 조건 |
|---|---|---|
| V1 | 깨끗한 Windows PC에서 클론 + 부트스트랩 | 명령 2개로 Layer B 골격 생성. 런타임 설치 0 |
| V2 | 새 빈 디렉터리에서 프로젝트 초기화 | `.ai/` 3개 파일 + Adapter 관리 블록. 소스 변경 0 |
| V3 | 공용 런타임 재사용 | 두 번째 프로젝트에서 설치 0회, 로그인 0회, 등록만 |
| V4 | 새 MCP 카탈로그 항목 추가 | 스크립트 수정 0. 검색·설치 분기 즉시 동작 |
| V5 | 새 클라이언트 디스크립터 추가 | 등록 → probe 로 읽힘 → 제거 → probe 로 사라짐 |
| V6 | 비밀값 커밋 시도 | pre-commit 차단 + CI 차단 (둘 다) |
| V7 | private 저장소 marketplace | `/plugin marketplace add` 성공 여부 — **미검증. 확인 필요** |
| V8 | 레거시 채택 | `-Migrate` 후 재다운로드 0, 재로그인 0, 세 CLI 전부 새 경로 |
| V9 | 드리프트 탐지 | 등록 command를 손으로 바꾸면 Doctor가 drift 보고 |
| V10 | verified 정합성 | 토큰 파일을 지우면 다음 verify가 `verified`를 쓰지 않음 |
| V11 | 인코딩 | 비ASCII 경로에서 재등록 반복 시 지문이 안정적 |
| V12 | 버전 바닥 | 2.2 하네스로 3.0 프로젝트를 열면 "업그레이드하라" 1건만 출력 |

---

# 12. 근거 — 실측으로 확인한 사실

각 항목은 재현 명령을 포함한다. **재현되지 않으면 그 항목에 의존한 설계를 재검토해야 한다.**

**A. 절대경로 하드코딩**
`scripts/Resolve-GoogleWorkspaceMcp.ps1:9` → `$candidates += 'C:\AI-Tools\google-workspace-mcp\google-workspace-mcp.cmd'` (유일한 폴백)
`settings/google-workspace/manifest.json:8` → `"default_tools_root": "C:\\AI-Tools"`

**B. PowerShell 파스 오류 (재현됨)**
```powershell
if (Test-Path -LiteralPath $x -and (Get-Item -LiteralPath $x).Length -gt 0) { }
# → A parameter cannot be found that matches parameter name 'and'.
```
`Initialize-GoogleWorkspaceMcp.ps1:56`. `$ErrorActionPreference='Stop'`이라 여기서 종료된다.
수정: `if ((Test-Path -LiteralPath $x) -and ((Get-Item -LiteralPath $x).Length -gt 0))`

**C. Doctor가 공용 범위를 거부함**
`Test-ProjectCapabilities.ps1:34` → `if ($capability.scope -ne 'project') { Add-Issue 'FAIL' 'NON_PROJECT_SCOPE' }`

**D. 클라이언트 등록 실제 상태** (2026-08-23 재확인, Codex 리뷰 이후)
```
> codex mcp list --json
[]

> codex mcp get google-workspace
Error: No MCP server named 'google-workspace' found.        exit=1

> type %USERPROFILE%\.codex\config.toml      (210 bytes)
[projects."C:\\윈도우 세팅공간"]
trust_level = "trusted"
[projects."C:\\Projects\\Active\\L1운영절차서"]
trust_level = "trusted"
[projects."C:\\Projects\\Active\\Ppumpie"]
trust_level = "trusted"
   → "mcp" 문자열 자체가 없음. [mcp_servers.*] 테이블 부재
   → 패치노트 §5 "Codex CLI: 등록 완료" 및 리뷰의 "이미 해소됨" 과 불일치

> claude mcp get google-workspace
  Scope: User config (available in all your projects)
  Status: ✔ Connected
  Command: C:\AI-Tools\google-workspace-mcp\google-workspace-mcp.cmd
  Args:            ← 비어 있음
  Environment:     ← 비어 있음 (env 는 .cmd 래퍼 내부에 있음)

> claude mcp list
  claude.ai Figma / Google Drive / Gmail / Google Calendar / Gamma / Canva  — 전부 Connected
  google-workspace                                                          — Connected
   → Google 계열 서버가 4개 동시 연결. 이름이 같은 도구 15개가 서로 다른 계정으로 공존
```
→ 래퍼를 없애는 설계라면, 재등록 없이 래퍼만 지우면 Claude/AGY가 즉시 깨진다.
→ **"등록 명령을 실행했다"와 "등록됐다"는 서로 다른 사건이다.** 이것이 §2 원칙 3(상태는 증명한다)과 `Register-HarnessRuntimeClient`의 등록 후 재-probe 요구가 존재하는 이유다.

**K. CLI별 도구 통제 능력** (문서·소스 확인, 2026-08-23)

| 항목 | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| 도구 지정 패턴 | `mcp__<srv>__<tool>` / `mcp__<srv>` / `mcp__<srv>__*` | `enabled_tools` / `disabled_tools` (정확한 이름, 글롭 불가) | `includeTools` / `excludeTools` (정확한 이름, 글롭 불가) |
| **컨텍스트 감소** | bare deny(`mcp__srv`)만 ✅ / scoped deny는 ❌ | ✅ 모델용 목록 생성 **전에** 제거 | ✅ discovery 단계에서 제거 |
| 승인 게이트 | `permissions.ask` | `default_tools_approval_mode` / `tools.<t>.approval_mode` = `auto\|prompt\|writes\|approve` | 없음 (`trust`는 확인을 건너뛸 뿐) |
| 프로젝트별 서버 on/off | ✅ `/mcp` 토글 → `~/.claude.json` `disabledMcpServers` | ❌ | ✅ `mcp.excluded` |
| 우선순위 | — | 도구별 > 서버 기본 > `auto` | `excludeTools` > `includeTools` |

- Codex `writes` 모드 = MCP 도구 주석의 `read_only_hint`가 true가 아니면 승인 요구. **"읽기는 자유, 쓰기는 승인"이 설정 한 줄로 구현된다.**
- Claude Code 내장 claude.ai 커넥터는 `/mcp` 토글로 개별 비활성화 가능하며 표시 이름(예: `claude.ai Gmail`)으로 `disabledMcpServers`에 기록된다.
- ⚠ **AGY(Antigravity)의 도구 통제 기능은 미검증이다.** 위 표의 Gemini CLI 열을 AGY에 적용하면 안 된다(§F7의 경고와 동일).

**E. 마이그레이션 디렉터리명**
`C:\AI-Tools`의 실제 내용은 `google-workspace-mcp\` (= 옛 manifest의 `runtime_subdirectory`).
`C:\AI-Tools\google-workspace`는 **존재하지 않는다.** `runtime_id`로 탐색하면 못 찾는다.

**F. `verified` 판정 불가**
같은 `get_status` 호출이 이 세션 중 `[WARN] … Issues: token_file` → `[OK] … No issues detected`로 변했다. **둘 다 exit 0이고 둘 다 성공한 도구 호출이다.** exit code로는 구분할 수 없다.

**G. 카탈로그 실효성**
```
mcp entries: 65
install kinds: registry_lookup=53, npm=6, remote_or_client=3, remote=1, docker_or_source=1, source_or_registry=1
```
`Install-ProjectMcp.ps1`은 `npm`/`remote`만 처리하고 나머지는 `throw` → **65개 중 7개만 설치 가능**.

**H. 실행 환경**
`git` `gh` `node`(24.19.0) `npm` `claude` `codex` `agy` 존재. **`pwsh` 없음** (Windows PowerShell 5.1 전용).
`ConvertFrom-Yaml` 없음, `powershell-yaml`/`yayaml` 미설치.
`C:\AI-Harness`는 git 저장소가 아니고 `.gitignore`/`.gitattributes`도 없다.

**I. 각 CLI 공식 설정 형식** (문서·소스 확인)
- Claude Code: `.claude-plugin/marketplace.json` → `/plugin marketplace add owner/repo`. 플러그인은 skills/agents/commands/hooks/`.mcp.json` 번들 가능, `${CLAUDE_PLUGIN_ROOT}` 지원. `claude mcp add --scope local|project|user`. `CLAUDE.md`는 `@path` import 지원(최대 4홉).
- Codex CLI: `~/.codex/config.toml`의 `[mcp_servers.<id>]` (**snake_case**). `codex mcp add <name> [--env K=V] -- <cmd>`. **scope 플래그 없음** = 항상 전역. 프로젝트 `.codex/config.toml`은 신뢰된 프로젝트만.
- AGY(Antigravity): `~/.gemini/config/mcp_config.json` (**공식**), 워크스페이스 `.agents/mcp_config.json`. 원격 키 `serverUrl`.
- Gemini CLI(별개 제품): `~/.gemini/settings.json`의 `mcpServers`. `gemini mcp add -s user|project`. 원격 키 `httpUrl`/`url`. **`mcp_config.json`을 읽지 않는다.**
- MCP 공식 레지스트리: `https://registry.modelcontextprotocol.io/v0.1/servers/{name}/versions/latest` (이름의 `/`는 `%2F` 인코딩). 인증 불필요. 검색은 이름 부분문자열 매칭.

**J. 규모**
정책 26개 / 합계 1,100KB / 평균 42KB / 최대 64KB. 하네스 전체 1.2MB.
Google MCP 도구 88개 / 스키마 89,171바이트 ≈ 세션당 25,000 토큰.

---

# 13. Codex에게 물어볼 질문

1. §1의 요구사항 정리가 실제 의도와 다른 부분이 있는가?
2. §2 원칙 1(3계층 분리)보다 더 단순하면서 R1~R5를 만족하는 구조가 있는가?
3. §5.1 표에서 "코드 수정 ❌"라고 적힌 8개 중, 실제로는 코드 수정이 필요해지는 것이 있는가?
4. §4의 흐름 중 **실패 경로가 빠진 곳**은 어디인가? (특히 F3의 `registry_lookup` 해석 실패, F6의 인증 실패)
5. §8-4의 "risk 태그에 효력 부여"를 세 CLI 중 어디에서 실제로 강제할 수 있는가? 도구 단위 게이트가 없다는 전제가 맞는가?
6. §7.2의 2.2.1 백포트가 정말 필요한가, 아니면 더 단순한 대안이 있는가?
7. §10 D5(PowerShell 유지 vs Node 전환)에 대한 반대 근거는?
8. §12의 실측 항목 중 재현되지 않는 것이 있는가?

---

# 14. 요약

| 질문 | 답 |
|---|---|
| **구조를 어떻게 하나** | Layer A(GitHub: 무엇을) / Layer B(AI-Tools: 어디에·누구로) / Layer C(프로젝트: 어떤 ID를). 이 셋을 파일 단위로 분리하고 검사로 강제 |
| **AI-Tools에서 찾아 쓰려면** | 카탈로그에 `install.kind: "shared_runtime"` 추가 → `runtimes/*.runtime.json`(레시피, git) + `runtimes.json`(실체, 머신) + 읽기 전용 resolver. 프로젝트는 capability_id만 |
| **기능을 추가하려면** | 선언 파일 1개 추가 + 스키마 검증 + `git push`. 8종류 전부 스크립트 수정 없음(§5.1) |
| **프로세스 흐름** | F1 PC설치 / F2 프로젝트초기화 / F3 능력획득 / F4 지침배포 / F5 MCP추가 / F6 런타임추가 / F7 클라이언트추가 / F8 플러그인 / F9 마이그레이션·롤백 |
| **지금 운용해도 되나** | 방향은 맞다. 단 §8의 보안 문제 2건(도구 루트 ACL, 자격증명 사본)과 §12-D의 사실 오류(Codex 미등록)를 먼저 고쳐야 한다. 전역 등록 자체는 **유지**하고 위험은 도구 단위로 통제한다 |

**이 문서는 제안이다. 승인 전에는 아무것도 변경하지 않는다.**

---

# 15. 개정 이력 — Codex 교차검증 처리 내역 (v1.0 → v1.1)

## 15.1 전면 수용 (설계를 바꿈)

| # | 지적 | 조치 | 반영 위치 |
|---|---|---|---|
| 1 | project scope 전환은 "어느 프로젝트에서든 바로 사용" 목표와 충돌 | **D7 권고를 뒤집음.** 공용(user) 등록 유지 | §8-4, D7 |
| 2 | 전체 read-only는 Drive 업로드/Docs 수정/메일/일정 요구와 충돌 | **D8 권고를 뒤집음.** `read_only: false` + `tool_policy` 도구 단위 통제 | §6.1, §8-4, D8 |
| 3 | "새 클라이언트 = 파일 1개"는 항상 성립하지 않음 | `adapter_kind` 탈출구 도입, 목표 진술 완화 | §5.1, §5.2, §6.3 |
| 4 | `.ps1` ASCII 전용 제한은 과도 | **UTF-8 BOM 통일 + CI 바이트 검사**로 대체. 한글 메시지 허용 | §8-6 |
| 5 | `command_sha256` 하나로는 무결성 부족 (`dist/index.js` 변조 미탐지) | `npm ci` + Layer A에 커밋한 lock + `install.integrity` + 트리 해시 | §8-1 규칙 3 |
| 6 | 인증 스냅샷은 비밀값 사본을 늘림 | **기본 미생성.** 버전별 설치 디렉터리로 롤백, 포맷 불일치는 명시적 재인증 | §F9 |
| 7 | 프로젝트의 `core.hooksPath`를 자동 변경하면 기존 훅이 사라짐 | 미설정일 때만 설치, 있으면 제안만, CI를 1차 방어선으로 | §8-3 |
| 8 | 보안 문제는 v3.1로 미루지 말고 v3.0에 포함 | 마이그레이션 순서를 보안 우선으로 재배열 | §9, D10 |

## 15.2 조건부 수용

| # | 지적 | 판단 |
|---|---|---|
| 9 | 2.2.1 백포트 불필요 | **단일 PC면 맞다.** 백포트 릴리스는 뺀다. 단 버전 바닥 **검사 코드**는 v3.0에 넣는다 — 두 번째 PC가 생기는 시점에 이미 작동해야 하므로 |

## 15.3 불수용

| # | 주장 | 재확인 결과 |
|---|---|---|
| 10 | "Codex 미등록은 이미 해소됨" | **해소되지 않았다.** `codex mcp list --json` → `[]`, `codex mcp get google-workspace` → not found(exit 1), `config.toml`에 `mcp` 문자열 부재. 근거는 §12-D |

## 15.4 보완 — Codex 리뷰의 "서버 분할" 제안에 대한 이견

리뷰는 토큰 비용 해소책으로 `google-workspace-read` / `google-workspace-write` 또는 서비스별 분할을 제안했다. **분할 자체는 성립하지만, 그것만으로는 비용이 줄지 않는다.**

- 분할된 서버를 **둘 다 공용 등록하면 모델이 보는 도구 총합은 동일**하다. 토큰 비용도 그대로다.
- 비용이 줄려면 하나만 공용 등록하고 나머지를 선택 등록해야 하는데, 그러면 리뷰가 반대한 "프로젝트별 등록"이 부분적으로 되돌아온다.
- 게다가 두 서버가 같은 OAuth 프로필을 쓰면 스코프는 두 서비스 집합의 **합집합**으로 발급되므로, 분할해도 토큰 권한은 축소되지 않는다.

**대안:** 범위를 건드리지 말고 각 CLI의 네이티브 도구 통제를 쓴다(§12-K 검증됨).
- Codex CLI / Gemini CLI: `disabled_tools` · `excludeTools`는 **모델용 목록 생성 전에** 도구를 제거하므로 컨텍스트가 실제로 줄어든다.
- Claude Code: 도구 단위로는 컨텍스트가 줄지 않는다. 대신 **중복된 claude.ai Google 커넥터를 끄는 것**이 가장 효과가 크다 — 충돌 15건 제거 + 계정 일원화 + 중복 스키마 제거가 한 번에 된다(D11).
- Google과 무관한 프로젝트는 `/mcp` 토글로 서버 자체를 끈다.

## 15.5 Codex 리뷰가 다루지 않아 그대로 유효한 항목

1. `get_status`는 문제 상황도 **성공한 도구 호출(exit 0)** 로 반환한다. exit code로 `verified`를 판정하면 인증 안 된 런타임을 인증됐다고 기록한다. → 구조화된 필드로 판정(§6.1 `verify.assert`)
2. resolver가 `authenticated`를 **파일 존재**로 판정하면 안 된다. 토큰은 만료·폐기될 수 있다. → resolver는 `auth_files_present`만 보고하고 `authenticated`는 `unknown`
3. 존재 여부만 반환하는 probe로는 **드리프트를 탐지할 수 없다.** `claude mcp get`은 Command/Args/Environment를 출력하므로 파싱해야 한다(§6.3)
4. Drive 동기화 스크립트는 update 실패 시 `create_file`로 폴백해 **같은 이름의 형제 파일**을 만든다. Drive는 동명 파일을 허용하므로 경로 해석이 모호해진다
5. `.ai/harness.yaml`·`capability-lock.json`에 `min_harness_version`이 필요하다(§7.2)
6. Claude Code에서 Google 계열 서버가 **4개 동시 연결**돼 있다(D11)

## 15.6 v1.1에서 새로 생긴 확인 항목

| # | 항목 |
|---|---|
| D13 | **AGY(Antigravity)의 도구 필터/승인 메커니즘 유무.** Gemini CLI의 `excludeTools`를 AGY에 적용하면 안 된다 — 별개 제품이고 설정 스키마도 다르다 |
| V13 | Claude Code에서 claude.ai 커넥터를 끈 뒤 실제 토큰 사용량과 도구 수가 줄어드는지 측정 |
| V14 | Codex `default_tools_approval_mode = "writes"`가 이 런타임의 도구 주석(`read_only_hint`)과 실제로 맞물리는지 확인 — 주석이 없는 서버면 전부 승인 대상이 된다 |
