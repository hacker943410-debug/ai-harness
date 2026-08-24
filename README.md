# AI Harness — 사용자 설치·운영 설명서

Version: 3.0 (Canonical Source: `POLICY_INDEX.yaml` 의 `harness_version`)
구성: 26개 전문 정책 + CORE + ROUTER + POLICY_INDEX + PROJECT_INIT + HARNESS_DOCTOR
      + 공용 런타임 / 클라이언트 계약 / 스키마 / 설치·진단 스크립트
대상: Claude Code, Codex CLI, Antigravity(AGY) 및 유사한 파일 기반 Coding Agent

정본은 **GitHub 저장소**다. Google Drive 는 정본이 아니라 **불변 스냅샷**이다.

---

## 0. 3계층 — 이 저장소가 무엇이고 무엇이 아닌가

무엇을 / 어디에 / 어떤 ID를 **절대 한 곳에 섞지 않는다.**
같은 사실을 세 군데에 적으면 언젠가 서로 달라지고, 그때 어느 쪽이 맞는지 판정할 방법이 없다.

| 계층 | 위치 | 담는 것 | git |
|---|---|---|---|
| **A 하네스** | 이 저장소 (`C:\AI-Harness` 등) | 정책·카탈로그·**레시피**(무엇을, 어떤 버전으로) | ✅ |
| **B 머신** | `%LOCALAPPDATA%\AI-Tools` | **실체**(어디에 설치, 누구로 인증), 토큰, 저널 | ❌ |
| **C 프로젝트** | `<프로젝트>\.ai\` | **capability ID 만** | ✅ |

따라서:

- 이 저장소에 **설치 경로·토큰·머신 상태를 적지 않는다.** 적는 순간 다른 PC 에서 깨진다
- 프로젝트 `.ai/` 에 **실제 비밀값을 적지 않는다.** 이름(참조)만 적는다
- Layer B 의 `runtimes.json` / `clients.json` / `tools-root.id` 는 **커밋 대상이 아니다.**
  `.githooks/pre-commit` 이 경로 이름으로 차단한다

**확장은 코드가 아니라 데이터다.** 새 정책·MCP·런타임·클라이언트·플러그인을 추가할 때
스크립트를 고쳐야 한다면 그것은 설계 실패로 간주한다. 선언 파일 1개 추가 + 스키마 검증 통과로 끝나야 한다.

**상태는 주장하지 않고 증명한다.** `installed ≠ registered ≠ authenticated ≠ verified`.
실제 API 를 한 번 호출한 증거가 있는 것만 `verified` 로 인정한다.

---

## 1. 이 파일은 누가 읽는가?

`README.md`는 **사람이 읽는 설명서**다.

일반 작업 때 AI에게 매번 읽힐 필요가 없다.

새 프로젝트를 AI가 자동으로 세팅하게 할 때는 `README.md`가 아니라:

```text
PROJECT_INIT.md
```

를 딱 한 번 읽히면 된다.

공식 초기화 파일명은 항상 `PROJECT_INIT.md`다. `BOOTSTRAP.md`를 설치나 Runtime의 공식 이름으로 사용하지 않는다. 기존 파일이 있다면 사용 여부를 확인한 뒤 Migration하며 임의 삭제하지 않는다.

---

## 2. 각 파일의 역할

```text
ai-harness/                          ← Layer A. 이 저장소가 전부다
├─ README.md                         사람이 읽는 설치/운영 설명서 (AI 는 읽지 않는다)
├─ PROJECT_INIT.md                   새 프로젝트에서 AI 에게 최초 1회 읽히는 초기화 지침
├─ CORE.md                           모든 작업의 최소 공통 원칙          ← Runtime 상시
├─ ROUTER.md                         필요한 정책을 JIT 로 고르는 Router  ← Runtime 상시
├─ POLICY_INDEX.yaml                 26개 정책의 ID·목적·Trigger·Bundle  ← Runtime 상시
│                                    harness_version 의 Canonical Source
├─ HARNESS_DOCTOR.md                 요청 시 읽는 Read-only 진단 계약 (P27 아님)
├─ PATCH_NOTES.md                    Version별 변경·설계 결정·검증 기록
│
├─ policies/                         26개 전문 정책 — 전체 preload 금지, JIT 로만
│  ├─ 01_....md  …  26_....md
│
├─ catalogs/                         필요할 때 검색하는 Metadata
│  ├─ mcp-catalog.json
│  └─ skill-catalog.json
│
├─ runtimes/                         공용 런타임 "레시피" — 무엇을 어떤 버전으로
│  ├─ google-workspace.runtime.json     설치 위치는 담지 않는다 (그건 Layer B)
│  └─ _TEMPLATE.runtime.json
│
├─ settings/clients/                 AI 클라이언트별 등록 방식·제약 선언
│  └─ claude / codex / agy .client.json
│
├─ schemas/                          기계가 읽는 계약. Test-HarnessRepo 가 매번 검증한다
│  └─ runtime-manifest / runtime-index / client-descriptor / client-index /
│     change-plan / capability-lock
│
├─ scripts/                          진단·설치·등록·인증·검증
│  └─ 적용하는 스크립트는 Install-Harness.ps1 하나뿐이다 (§21)
│
│
├─ workflows/                        절차서 — 필요할 때만 읽는다
│  ├─ HARNESS_INSTALL.md             PC 환경별 최초 설치
│  ├─ SHARED_RUNTIME.md              런타임 수명주기 install→auth→verify→sync→restart
│  ├─ CAPABILITY_ACQUISITION.md      Capability 가 부족할 때의 획득 절차
│  └─ GOOGLE_WORKSPACE_*.md          Google 연결·권한 절차
│
├─ proposals/                        v3 설계 근거와 인수인계
│  ├─ HANDOFF.md                     이어서 작업할 때 가장 먼저 읽는 문서
│  └─ HARNESS_V3_PROPOSAL.md
│
├─ .claude-plugin/marketplace.json   (선택) Claude Code 플러그인 마켓플레이스 진입점
├─ plugins/ai-harness/               (선택) Claude Code 전용 편의 계층 — §22
└─ .githooks/pre-commit              비밀값·머신 상태 커밋 차단
```

핵심:

- `README.md` → 사람용
- `PROJECT_INIT.md` → 프로젝트 최초 설치용, 1회성
- `CORE.md` → Runtime 상시
- `ROUTER.md` → Runtime 상시
- `POLICY_INDEX.yaml` → Runtime 상시
- `HARNESS_DOCTOR.md` → 요청 시 진단용, 기본 Read-only
- `PATCH_NOTES.md` → 버전별 변경 기록
- `catalogs/*` → 필요할 때 검색하는 MCP/Skill Metadata
- `workflows/CAPABILITY_ACQUISITION.md` → Capability가 부족할 때만 읽는 획득 절차
- `runtimes/*.runtime.json` → 공용 런타임 선언 (무엇을 어떤 버전으로. 설치 위치는 담지 않는다)
- `settings/clients/*.client.json` → AI 클라이언트별 등록 방식과 제약 선언
- `schemas/*.schema.json` → 위 선언들의 기계가 읽는 계약. `Test-HarnessRepo.ps1` 이 매번 검증한다
- `workflows/SHARED_RUNTIME.md` → 공용 런타임 수명주기 (install → auth → verify → sync → restart)
- `workflows/GOOGLE_WORKSPACE_MCP.md` → PC 공용 Google Workspace MCP 연결·권한 절차
- `policies/*.md` → 필요한 것만 JIT

---

## 3. 정본은 어디에 있는가 (v2.2 에서 바뀐 부분)

```text
GitHub  = 정본 (CANONICAL)
Local   = 런타임 (RUNTIME)      git clone 으로 받는다
Drive   = 불변 스냅샷 (SNAPSHOT) 읽기 전용 사본. 정본이 아니다
```

v2.2 는 Google Drive 를 MASTER 로 썼다. **v3 에서 강등됐다.**

이유는 단순하다. Drive 동기화 폴더는 **되돌릴 수 없고, 누가 언제 무엇을 왜 바꿨는지 남지 않는다.**
두 PC 가 같은 파일을 만지면 조용히 충돌 사본이 생기고, 그 순간 정본이 둘이 된다.

그래서:

- **정본** — `https://github.com/<owner>/ai-harness` (Private). 이력·되돌리기·검사가 붙는다
- **런타임** — 이 저장소를 clone 한 로컬 경로. 예: `C:\AI-Harness`
- **스냅샷** — `Publish-HarnessSnapshot.ps1` 이 Drive 에 발행하는 **불변** 폴더.
  예: `/AI-Harness-snapshots/v3.0.0`. 갱신하지 않는다. 다음 스냅샷은 **새 라벨**로 만든다.
  추적 파일만 올라가며 `never_sync` 대상은 제외된다

Drive 스냅샷은 "git 을 쓸 수 없는 상황에서 내용을 열람"하기 위한 것이지 작업 사본이 아니다.
**스냅샷을 고쳐서 정본으로 되돌리지 않는다.**

---

## 4. 새 프로젝트를 자동으로 세팅하는 가장 간단한 방법

아무것도 없는 프로젝트:

```text
D:\projects\new-project\
```

에서 사용하는 CLI를 실행한다.

그 다음 한 줄만 요청한다.

### Windows 예시

```text
C:\AI-Harness\PROJECT_INIT.md를 읽고
현재 프로젝트에 AI Harness를 초기화해줘.
```

Claude Code 를 쓰고 플러그인을 설치했다면 이 한 줄 대신 `/harness-init` 만 쳐도 된다 (§22).
어느 쪽이든 **읽히는 파일은 같은 `PROJECT_INIT.md`** 다.

### macOS / Linux 예시

```text
~/.ai-harness/PROJECT_INIT.md를 읽고
현재 프로젝트에 AI Harness를 초기화해줘.
```

`PROJECT_INIT.md`는 자신이 위치한 디렉터리를 기본 `HARNESS_ROOT`로 취급하도록 설계돼 있다.

---

## 5. 그러면 AI가 무엇을 하는가?

`PROJECT_INIT.md`를 읽은 Agent는 현재 프로젝트를 조사한 뒤 최소한 다음을 수행한다.

```text
현재 프로젝트 확인
        ↓
기존 지침 파일 확인
        ↓
기존 내용을 덮어쓰지 않음
        ↓
.ai/ Harness Bridge 생성
        ↓
현재 CLI용 얇은 Adapter 생성/병합
        ↓
CORE / ROUTER / POLICY_INDEX 연결
        ↓
26개 전문 정책 전체 preload 금지 설정
        ↓
필요 정책만 JIT Load하도록 설정
        ↓
설치 검증
        ↓
결과 보고
```

---

## 6. 프로젝트에 실제로 생기는 구조

권장 최소 구조:

```text
project/
├─ AGENTS.md       # Codex를 쓰는 경우
├─ CLAUDE.md       # Claude Code를 쓰는 경우
├─ GEMINI.md       # Gemini CLI를 쓰는 경우
│
└─ .ai/
   ├─ HARNESS.md
   ├─ harness.yaml
   └─ current-state.md
```

모든 파일이 반드시 생성되는 것은 아니다.

`PROJECT_INIT.md`가 현재 CLI와 기존 프로젝트 구조를 보고 필요한 Adapter만 생성한다.

현재 CLI를 신뢰성 있게 구분할 수 없고 여러 CLI를 함께 사용할 가능성이 높다면, 기존 내용을 보존한 상태에서 여러 개의 얇은 Adapter를 만들 수 있다.

---

## 7. `.ai/HARNESS.md`가 중요한 이유

프로젝트별 Adapter 파일에 26개 정책 내용을 복제하지 않는다.

각 Adapter는 아주 짧게:

```text
이 프로젝트는 .ai/HARNESS.md를 따른다.
```

라고 연결하는 역할만 한다.

실제 프로젝트용 Harness Bridge는:

```text
.ai/HARNESS.md
```

가 담당한다.

그래서 도구를 바꿔도:

```text
AGENTS.md
CLAUDE.md
GEMINI.md
       │
       └──→ .ai/HARNESS.md
                    │
                    └──→ Global AI Harness
```

구조를 유지할 수 있다.

---

## 8. 정상 Runtime에서는 무엇을 읽는가?

매 작업 시작:

```text
.ai/HARNESS.md
        ↓
CORE.md
ROUTER.md
POLICY_INDEX.yaml
```

까지만 기본으로 사용한다.

그 후 Task를 분류한다.

예:

```text
"버튼 글자를 수정해줘"
```

이면 보통:

```text
P04 변경 범위
P06 검증
P26 코드베이스 실행
```

정도만 JIT로 읽는다.

---

## 9. 26개를 매번 읽지 않는다

절대 권장하지 않는 구조:

```text
AGENTS.md
  → 정책 01
  → 정책 02
  → ...
  → 정책 26
```

또는:

```text
GEMINI.md
@policies/01...
@policies/02...
...
@policies/26...
```

이렇게 하면 Harness의 JIT 목적이 사라진다.

---

## 10. 작업 중 전문 정책이 추가되는 방식

예:

초기 Feature 변경:

```text
P04
P06
P10
P21
P26
```

분석 도중 새 DB Column이 필요하다고 확인:

```text
DATABASE boundary detected
```

그때만:

```text
+ P16 Migration / Rollback
```

을 읽는다.

Permission까지 필요:

```text
+ P17 Security / Permission
```

External SDK 도입:

```text
+ P15 Dependency / External Contract
```

---

## 11. `PROJECT_INIT.md`는 매번 읽는가?

아니다.

정상 흐름:

```text
새 프로젝트
    ↓
PROJECT_INIT.md  ← 최초 1회
    ↓
프로젝트 Adapter / .ai Bridge 생성
    ↓
초기화 완료
    ↓

이후 작업
    ↓
PROJECT_INIT.md 읽지 않음
    ↓
CORE + ROUTER + POLICY_INDEX
    ↓
JIT Policies
```

프로젝트 Harness 연결 구조가 깨졌거나, Harness 설치 방식을 업그레이드할 때만 다시 실행한다.

---

## 12. 이미 AGENTS.md / CLAUDE.md / GEMINI.md가 있으면?

`PROJECT_INIT.md`는 기존 파일 전체를 교체하도록 설계하지 않았다.

기존 내용은 유지한다.

Harness가 관리하는 부분만 다음 Marker 내부에 추가/갱신한다.

```text
<!-- AI-HARNESS:START -->
...
<!-- AI-HARNESS:END -->
```

따라서 다시 초기화하더라도 Marker 내부만 갱신할 수 있다.

이것을 **Idempotent Initialization** 원칙으로 사용한다.

---

## 13. 프로젝트 고유 규칙과 Global Harness를 섞지 않는다

Global:

```text
AI-Harness/
└─ policies/
   └─ 공통 26개
```

Project:

```text
project/.ai/
├─ current-state.md
├─ active-spec.md        # 필요할 때
├─ active-plan.md        # 필요할 때
├─ roadmap.md            # 장기 프로젝트일 때
├─ maps/                 # 필요할 때
├─ decisions/            # 필요할 때
└─ learning/             # 필요할 때
```

Project별 정보는 Global 26개 정책에 넣지 않는다.

---

## 14. 작은 프로젝트에서는 `.ai`를 크게 만들지 않는다

처음부터 다음을 전부 만들 필요는 없다.

```text
roadmap
DAG
ADR registry
lessons database
maps
migration state
```

`PROJECT_INIT.md`는 최소 구조만 만든다.

전문 구조는 실제 Task가 필요로 할 때 해당 정책에 따라 생성한다.

---

## 15. 다른 PC에서도 사용하려면?

Layer A 만 받아오면 된다. Layer B 는 그 PC 에서 새로 만든다.

```powershell
git clone https://github.com/<owner>/ai-harness.git C:\AI-Harness
git -C C:\AI-Harness config core.hooksPath .githooks    # 비밀값 커밋 차단 활성화
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AI-Harness\scripts\Test-HarnessRepo.ps1'
```

그다음 순서는 `workflows/HARNESS_INSTALL.md` 가 소유한다. 요약하면:

1. 저장소 clone + `Test-HarnessRepo.ps1` 통과 확인 — **Layer A**
2. `Get-HarnessEnvironment.ps1` 로 이 PC 상태 진단 (읽기 전용)
3. 계획 파일 생성 → 검토 → `Install-Harness.ps1` 로 적용 — **Layer B** 가 여기서 생긴다
4. `Connect-HarnessRuntimeAuth.ps1` 로 인증, `Test-HarnessRuntime.ps1` 로 실제 호출 검증
5. 프로젝트에서 `PROJECT_INIT.md` 최초 1회 실행 — **Layer C**

**토큰과 설치 경로는 따라오지 않는다.** 그건 Layer B 이고 PC 마다 다르다.
경로가 바뀌었다면 Adapter 를 다시 쓰지 말고 `.ai/harness.yaml` 의 Harness Root 만 갱신한다.

---

## 16. Harness 업데이트

26개 정책 또는 CORE/ROUTER/INDEX를 수정한 경우:

```text
브랜치에서 수정 → Test-HarnessRepo.ps1 통과 → 커밋 → push (정본 갱신)
↓
각 PC 에서 git pull
↓
다음 Task부터 새 Runtime 파일 사용
```

프로젝트마다 26개를 다시 복사하지 않는다.

Drive 스냅샷이 필요하면 `Publish-HarnessSnapshot.ps1` 로 **새 라벨**을 발행한다.
기존 스냅샷 폴더는 고치지 않는다 (§3).

---

## 17. 설치 검증

초기화 후 확인할 것:

- `.ai/HARNESS.md` 존재
- `.ai/harness.yaml` 존재
- 현재 CLI의 Adapter 존재 또는 기존 Adapter에 Managed Block 존재
- Adapter에 26개 원문이 복사되어 있지 않음
- HARNESS_ROOT가 유효
- CORE / ROUTER / POLICY_INDEX를 읽을 수 있음
- `policies/`에 26개가 존재
- Policy Index의 26개 파일 참조가 실제 파일과 일치
- 프로젝트 기존 지침을 삭제하지 않음
- `PROJECT_INIT.md`의 Doctor basic check 통과 또는 미통과 사유 보고

---

## 18. 운영 안정성 계약

### Policy Precedence

충돌의 상세 기준은 `ROUTER.md`가 소유한다. 운영자는 대략 다음 순서로 이해하면 된다.

```text
System / Platform / Safety
→ 현재 사용자 요청·금지사항
→ 더 구체적이고 확정된 Project Rule / Locked Spec
→ Security / Data Loss / Destructive Guard
→ 현재 Task의 JIT Policy
→ CORE
→ Agent 선호·추론
```

더 구체적인 Project Rule을 우선 검토하되 Secret Protection, Security Boundary, Data Loss 방지를 자동 약화하지 않는다. 실제 Source / Runtime / Test Evidence는 오래된 Map이나 AI 기억보다 우선하며, 해결되지 않는 중요한 충돌은 Agent가 조용히 임의 결정하지 않는다.

### Runtime Fast Health Check

Runtime 시작 시 다음 Metadata만 가볍게 확인한다.

- HARNESS_ROOT 접근
- CORE / ROUTER 존재 및 읽기
- POLICY_INDEX YAML 파싱
- `policy_count == 26`
- `policies/` 디렉터리 존재

일반 Task마다 26개 정책 본문 전체를 검사하지 않는다. 파일 매핑·Adapter·버전·참조까지 보는 상세 검사는 Doctor가 담당한다.

### Policy Load Trace

기본 모드는 `record_only`다. `.ai/current-state.md`에는 필요한 경우 Active Policy ID, Load Reason, 새 Boundary Trigger, Released Policy ID만 남긴다. 정책 전문은 복사하지 않으며, 사용자 요청 또는 Harness Debug / Doctor / Router 분석에서만 표시한다.

### Harness Version

Global Version의 Canonical Source는 `POLICY_INDEX.yaml`의 `harness_version`이다. Project의 `.ai/harness.yaml`에는 현재 `version`과 설치 또는 마지막 구조 Migration에 사용한 `initialized_with`를 구분해 기록한다.

두 값이 다르다는 사실만으로 오류는 아니다. Doctor가 구조와 경로를 함께 확인해 Compatibility 판단 필요 여부를 보고한다.

### Risk-aware Fail-safe

- `HEALTHY`: 핵심 Runtime과 현재 필요한 JIT 연결이 검증됨
- `DEGRADED`: 비핵심 결함이 있지만 현재 Task를 안전하게 제한 수행 가능
- `BLOCKED`: 핵심 Runtime을 신뢰할 수 없거나 현재 Task의 Critical Policy가 없음

예를 들어 Migration Task에서 P16이 없거나 Security Task에서 P17이 없으면 정상 Harness인 것처럼 계속하지 않는다. 현재 Task와 무관한 결함은 근거를 밝히고 `DEGRADED`로 제한 수행할 수 있다.

### Secret Protection

`.ai/current-state.md`, Plan, Spec, Decision, Map, Learning, Trace, Checkpoint, Handoff에는 API Key, Password, Token, Private Key, Database Password, Credential JSON, Session Cookie 같은 실제 값을 저장하지 않는다.

필요하면 `OPENAI_API_KEY`, `DATABASE_URL`, `AWS_PROFILE`, `GITHUB_TOKEN` 같은 참조 이름이나 “approved secret store를 통해 제공됨”만 기록한다. 상세 Security 정책은 P17이 소유한다.

---

## 19. Harness Doctor

다음처럼 자연어로 요청한다.

```text
AI Harness 상태 점검해줘
Harness Doctor 실행해줘
```

Doctor는 `HARNESS_DOCTOR.md`를 요청 시 JIT로 읽는 운영 기능이며 P27이 아니다. 기본 동작은 Read-only 진단이고 Application Source Code나 Business Logic을 수정하지 않는다.

주요 검사 범위는 Global Root와 Version, Project `initialized_with`, CORE/ROUTER/INDEX, P01~P26 매핑, Adapter와 Managed Block, JIT/Full Preload, 경로·참조, Version/Bridge mismatch, `.ai`의 명백한 Secret 값 흔적이다. Secret은 값 자체를 보고서에 출력하지 않는다.

문제는 먼저 `Suggested Fix`로 제시한다. 다음처럼 명시한 경우에만 기존 사용자 내용을 보존하면서 좁고 안전한 Harness Configuration 수정까지 수행한다.

```text
Harness Doctor 실행하고 안전하게 고칠 수 있는 것까지 수정해줘.
```

Global Harness Master 저장소에 Project Adapter가 없는 것은 Core Failure가 아니다. CLI 기능·import·hook·slash command는 현재 환경의 Evidence 없이 지원된다고 가정하지 않는다.

---

## 20. 한 문장 사용법

새 프로젝트에서:

```text
<AI-Harness 경로>/PROJECT_INIT.md를 읽고 현재 프로젝트를 초기화해줘.
```

**이 한 번이면 된다.**

그 뒤부터 `PROJECT_INIT.md`는 설치 설명서 역할을 끝내고, 실제 Runtime은 `CORE + ROUTER + POLICY_INDEX + 필요한 JIT Policy`가 담당한다.

---

## 21. 바꾸는 문은 하나다

Layer B(이 PC 의 실체)를 바꾸는 경로는 **하나뿐**이다.

```text
  Get-HarnessEnvironment.ps1  ─┐
                               ├─> 계획 파일 ─> Install-Harness.ps1
  Sync-HarnessClients.ps1     ─┘  (harness-change-plan v1.0)   확인 → 적용 → 롤백 저널
                                   사용자가 enabled 를 편집한다
```

계획을 **만드는** 스크립트는 여럿이어도 좋다. **적용하는** 스크립트는 하나여야 한다.
둘이 되는 순간 확인 절차를 우회하는 샛길이 생긴다.

```powershell
# 1) 계획 — 아무것도 바꾸지 않는다
powershell ... -File '...\Sync-HarnessClients.ps1' -SavePlan .\plan.json
# 2) 사용자가 enabled 를 편집
notepad .\plan.json
# 3) 실행될 명령만 확인
powershell ... -File '...\Install-Harness.ps1' -Plan .\plan.json -DryRun
# 4) 확인 후 적용
powershell ... -File '...\Install-Harness.ps1' -Plan .\plan.json
# 되돌리기
powershell ... -File '...\Install-Harness.ps1' -Rollback <저널경로>
```

진단 스크립트(`Get-HarnessEnvironment` / `Sync-HarnessClients` / `Resolve-HarnessRuntime`)는
**전부 읽기 전용**이다. 마음 놓고 돌려도 된다.

### 제약 고지

하네스가 **강제할 수 없는 것**은 최초 설치 시점에 선택지와 함께 제시한다.
등록한 뒤에 뜨는 경고는 사용자가 *이미 노출된 상태에서* 읽는 것이므로 정보이지 선택이 아니다.

제약은 `settings/clients/<id>.client.json` 의 `limitations` 에 **데이터로** 선언한다.
각 제약은 `what` / `why` / `consequence` / `options` 를 갖고, `options` 는 2개 이상,
`recommended` 는 정확히 1개다. `Test-HarnessRepo.ps1` 이 이것을 강제한다.
`severity: high` 는 `Install-Harness.ps1` 이 적용 전에 동의를 따로 받고, 거부하면 아무것도 적용되지 않는다.

---

## 22. (선택) Claude Code 플러그인

Claude Code 사용자는 같은 하네스를 **플러그인 채널**로도 쓸 수 있다.

```text
/plugin marketplace add <owner>/ai-harness
/plugin install ai-harness@ai-harness
```

그러면 다음이 생긴다.

```text
/harness-init      PROJECT_INIT.md 를 읽고 현재 프로젝트를 초기화
/harness-doctor    HARNESS_DOCTOR.md 를 읽고 Read-only 진단
/harness-status    저장소·이 PC 상태를 읽기 전용으로 점검
Skill: harness-runtime      공용 런타임 수명주기
Skill: harness-capability   Capability 가 부족할 때의 획득 절차
```

**중요 — 플러그인은 정본이 아니다.**

- 플러그인은 `PROJECT_INIT.md` 를 **대체하지 않는다.** 같은 파일을 가리키는 얇은 진입점일 뿐이다
- Codex 와 AGY 에는 이 메커니즘이 없다. 플러그인이 정본이 되면 그 사용자들이 뒤처지고
  마스터가 또 둘로 갈라진다. **정본은 항상 Layer A 의 파일이다**
- 플러그인 안에 정책 원문을 복사하지 않는다. 경로만 넘긴다

### `.mcp.json` 을 넣지 않는 이유

플러그인으로 MCP 서버를 등록할 수도 있지만 **이 하네스는 그렇게 하지 않는다.**

공용 런타임의 실체는 Layer B(`%LOCALAPPDATA%\AI-Tools`)에 있고 그 경로는 PC 마다 다르다.
플러그인 `.mcp.json` 에 그 경로를 적으려면 절대경로가 필요하고, 적지 않으면 서버가 뜨지 않는다.
게다가 등록 경로가 `Register-HarnessRuntimeClient.ps1` 과 플러그인 둘로 갈라져
**§21 의 "문은 하나" 규칙이 깨진다.**

그래서 등록은 계속 하네스 스크립트가 담당하고, 플러그인은 절차를 부르는 역할만 한다.
