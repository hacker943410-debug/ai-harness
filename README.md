# AI Harness CLI — 사용자 설치·운영 설명서

Version: 2.2
구성: 26개 전문 정책 + CORE + ROUTER + POLICY_INDEX + PROJECT_INIT + HARNESS_DOCTOR
대상: Codex CLI, Claude Code, Gemini CLI 및 유사한 파일 기반 Coding Agent

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
AI_Harness_CLI_v2/
├─ README.md
│  └─ 사람이 읽는 설치/운영 설명서
│
├─ PROJECT_INIT.md
│  └─ 새 프로젝트에서 AI에게 최초 1회 읽히는 자동 초기화 지침
│
├─ CORE.md
│  └─ 모든 작업의 최소 공통 원칙
│
├─ ROUTER.md
│  └─ 필요한 전문 정책을 JIT로 고르는 Runtime Router
│
├─ POLICY_INDEX.yaml
│  └─ 26개 정책의 ID·목적·Trigger·Bundle 목록
│
├─ HARNESS_DOCTOR.md
│  └─ 요청 시 읽는 Read-only 운영 진단 계약(P27 아님)
├─ PATCH_NOTES.md
│  └─ Harness Version별 변경·설계 결정·검증 기록
├─ catalogs/
│  ├─ mcp-catalog.json
│  └─ skill-catalog.json
├─ workflows/
│  └─ CAPABILITY_ACQUISITION.md
├─ scripts/
│  └─ Capability 검색·프로젝트 설치·검증 도구
├─ schemas/
│  └─ 프로젝트 Capability Lock Schema
│
└─ policies/
   ├─ 01_....md
   ├─ ...
   └─ 26_....md
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
- `workflows/SHARED_RUNTIME.md` → 공용 런타임 수명주기 (install → auth → verify → sync → restart)
- `workflows/GOOGLE_WORKSPACE_MCP.md` → PC 공용 Google Workspace MCP 연결·권한 절차
- `policies/*.md` → 필요한 것만 JIT

---

## 3. Google Drive에서의 권장 위치

예:

```text
Google Drive/
└─ AI-Harness/
   ├─ README.md
   ├─ PROJECT_INIT.md
   ├─ CORE.md
   ├─ ROUTER.md
   ├─ POLICY_INDEX.yaml
   ├─ HARNESS_DOCTOR.md
   └─ policies/
      └─ 26개 정책
```

Google Drive는 **MASTER**로 사용한다.

CLI가 읽는 경로는 Google Drive Desktop 등으로 로컬 파일시스템에 동기화된 경로를 권장한다.

예:

```text
G:\내 드라이브\AI-Harness\
```

또는 별도 Runtime 복사본:

```text
C:\AI-Harness\
```

개념:

```text
Google Drive = MASTER
Local filesystem = RUNTIME
```

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
G:\내 드라이브\AI-Harness\PROJECT_INIT.md를 읽고
현재 프로젝트에 AI Harness를 초기화해줘.
```

또는:

```text
C:\AI-Harness\PROJECT_INIT.md를 읽고
현재 프로젝트에 AI Harness를 초기화해줘.
```

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

Google Drive에 Harness Master를 보관하면 된다.

새 PC:

1. Google Drive 동기화
2. Harness 경로 확인
3. 해당 프로젝트에서 `PROJECT_INIT.md` 최초 실행
4. `.ai/harness.yaml`에 현재 Harness Root가 반영됨
5. 정상 작업 시작

경로가 바뀌었다면 프로젝트 Adapter 전체를 다시 작성할 필요 없이 Harness Root 연결만 갱신하면 된다.

---

## 16. Harness 업데이트

26개 정책 또는 CORE/ROUTER/INDEX를 수정한 경우:

```text
Drive MASTER 수정
↓
로컬 동기화
↓
다음 Task부터 새 Runtime 파일 사용
```

프로젝트마다 26개를 다시 복사하지 않는다.

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
