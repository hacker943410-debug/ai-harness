# AI Harness Doctor

Document Version: 1.1
Harness Version Source: `POLICY_INDEX.yaml`의 `harness_version`
Mode: Read-only diagnostic by default
Scope: Global Harness와 Project Bridge의 운영 상태 진단

---

## 1. 역할과 호출

이 문서는 P01~P26과 별개인 운영 진단 계약이다. 새로운 전문 Policy가 아니며 Policy 수나 JIT Active Policy 수에 포함하지 않는다.

사용자가 다음처럼 요청하면 이 문서를 JIT로 읽고 Doctor를 수행한다.

```text
AI Harness 상태 점검해줘
Harness Doctor 실행해줘
```

특정 slash command, hook, import 문법 또는 CLI 기능이 실제로 확인되지 않았다면 존재한다고 가정하지 않는다.

Doctor는 기본적으로 진단만 수행한다. Application Source Code와 Business Logic을 수정하지 않는다. 안전한 Harness 설정 수정까지 사용자가 명시적으로 요청한 경우에만 좁고 명백한 Configuration 문제를 수정하며, 수정 전 대상과 근거를 확인하고 수정 후 Doctor를 다시 실행한다.

---

## 2. 대상 식별

먼저 다음을 Evidence로 구분한다.

- Global Harness Master: `CORE.md`, `ROUTER.md`, `POLICY_INDEX.yaml`, `policies/`가 있는 Harness Root
- Initialized Project: `.ai/HARNESS.md` 또는 `.ai/harness.yaml`이 있는 Project Root
- Combined: 현재 디렉터리가 두 역할을 모두 수행

Global Harness Master 자체에 Project Adapter가 없다는 이유만으로 Core Failure로 판정하지 않는다. Project 진단에서 Adapter가 설치되지 않은 CLI도 사용 대상이라는 Evidence가 없으면 `NOT INSTALLED` 정보로 보고하며 전체 실패로 만들지 않는다.

---

## 3. 진단 깊이

### FAST HEALTH CHECK

일반 Runtime 시작 시에는 다음 Metadata만 확인한다.

1. `HARNESS_ROOT` 접근 가능
2. `CORE.md` 존재 및 읽기 가능
3. `ROUTER.md` 존재 및 읽기 가능
4. `POLICY_INDEX.yaml` 존재 및 파싱 가능
5. `policy_count == 26`
6. Index가 지정한 `policies/` 디렉터리 존재

P01~P26 본문 전체를 읽지 않는다.

### FULL DOCTOR

Doctor 요청 시 아래 목록을 검사한다. 파일 존재·Metadata·참조 검증을 우선하며, 정책 전문은 의미 매핑 확인에 필요한 최소 범위만 읽는다.

---

## 4. Full Doctor Checklist

1. `HARNESS_ROOT`가 존재하고 접근 가능한가
2. `POLICY_INDEX.yaml`의 Global `harness_version`을 읽을 수 있는가
3. Project `.ai/harness.yaml`의 `initialized_with`를 읽을 수 있는가
4. `CORE.md`가 존재하고 읽기 가능한가
5. `ROUTER.md`가 존재하고 읽기 가능한가
6. `POLICY_INDEX.yaml`이 안전하게 파싱되는가
7. `policy_count == 26`인가
8. Index의 ID가 P01~P26으로 연속되고 중복·누락이 없는가
9. Index의 각 `file`과 실제 `policies/` 파일이 일치하고, 파일 선두 제목이 해당 ID의 `purpose`와 명백히 어긋나지 않는가
10. `policies/`에 예상치 못한 추가 Pxx 파일이나 누락 파일이 없는가
11. Project `.ai/HARNESS.md`가 존재하고 읽기 가능한가
12. Project `.ai/harness.yaml`이 존재하고 파싱 가능한가
13. 현재 CLI Adapter 연결 상태가 Evidence로 확인되는가
14. `AGENTS.md`의 AI-HARNESS Managed Block 상태가 정상인가
15. `CLAUDE.md`의 AI-HARNESS Managed Block 상태가 정상인가
16. `GEMINI.md`의 AI-HARNESS Managed Block 상태가 정상인가
17. Adapter별 Managed Block이 중복되거나 Marker가 불균형하지 않은가
18. Harness 내부 경로와 Project Bridge가 가리키는 경로가 존재하는가
19. 공식 초기화 이름이 `PROJECT_INIT.md`인가
20. 공식 설치·Runtime 경로에 오래된 `BOOTSTRAP.md` 참조가 남아 있지 않은가
21. `preload_all_policies`가 `false`인가
22. Adapter가 26개 정책을 직접 import/load하도록 만들지 않았는가
23. 각 Policy에 `purpose`와 비어 있지 않은 `triggers`가 있는가
24. Global `harness_version`과 Project `initialized_with` 차이가 있는가
25. Project Bridge의 Global Harness 경로와 `.ai/harness.yaml`의 `harness.root`가 일치하는가
26. `.ai` 상태·계획·명세·결정·Map·Learning·Trace·Checkpoint·Handoff에 명백한 Secret 값 흔적이 있는가
27. 구현 가능한 범위에서 Markdown 경로와 Harness 내부 Reference가 깨지지 않았는가
28. Index, Bundle, Boundary Escalation, Runtime 문서의 Policy ID가 P01~P26을 가리키며 중복 선언이 없는가
29. Fast Check 결과에 따른 Runtime Health 상태는 무엇인가
30. `use_jit_policy_loading == true`이고 JIT Routing에 필요한 연결이 사용 가능한가
31. `catalogs/mcp-catalog.json`과 `catalogs/skill-catalog.json`이 존재하고 JSON 파싱 가능한가
32. Catalog ID가 각 Catalog 안에서 중복되지 않는가
33. `workflows/CAPABILITY_ACQUISITION.md`와 Capability Script가 존재하는가
34. Project `.ai/capability-lock.json`이 있으면 모든 항목이 `scope: project`인가
35. Local Package MCP Version에 `latest`, wildcard, caret, tilde 범위가 남아 있지 않은가
36. `.ai/mcp/desired.json`의 MCP ID가 중복되지 않고 Secret 실제 값이 없는가
37. 설치 기록의 `verified` 상태가 실제 Smoke Test Evidence 없이 부여되지 않았는가
38. `runtimes/*.runtime.json`이 유효하고 `scripts/Resolve-HarnessRuntime.ps1`이 선언된 런타임의 command를 찾는가 (exit 4 = 미설치이며 오류가 아니다)
39. Google OAuth credential/token이 Harness, 프로젝트 또는 Drive 동기화 설정 폴더에 복제되지 않았는가
40. 현재 설치된 MCP 지원 AI 클라이언트에 `google-workspace`가 사용자/전역 범위로 등록되어 있는가
41. Index가 가리키는 `workflows/DECISION_ENGINE.md`가 존재하고 읽기 가능한가
42. Global Decision Engine 기본값이 `enabled: false`이며 Project 활성화가 명시적 opt-in인가
43. Decision Engine Fallback이 기존 Router를 보존하는가
44. Shadow Mode에서 기존 Router가 실제 경로를 계속 결정하는가
45. Shadow 활성화를 주장하는 경우 Provider·Model·인증·응답 계약과 실제 실행 Evidence가 있으며, Advisory 또는 자동 수용을 주장하는 경우 Threshold도 `CONFIG_REQUIRED`가 아닌가
46. Jev에 Permission·Security·Budget·Production·Destructive Operation 승인 권한이 부여되지 않았는가
47. Decision Trace에 Secret, Credential, 전체 Prompt, 전체 Source Code가 기록되지 않는가
48. 가격이나 근거 없는 confidence 숫자가 Runtime 분기에 Hard Coding되지 않았는가

Policy Reference 검사는 YAML과 명시적인 Routing 표기처럼 구조적으로 정책을 가리키는 위치를 대상으로 한다. 성능 지표의 `P95` 같은 일반 용례를 정책 ID 오류로 오인하지 않는다.

---

## 5. 판정 규칙

개별 항목:

- `PASS`: 확인 Evidence가 있고 정상
- `WARNING`: 비핵심 결함, 선택 설치 항목 부재, Version 차이 또는 추가 확인 필요
- `FAIL`: 필수 구조·파싱·연결·정책 매핑 실패
- `NOT INSTALLED`: 현재 대상에 설치할 필요가 확인되지 않은 Adapter

전체 상태:

- `HEALTHY`: 핵심 Runtime과 현재 필요한 JIT 연결이 검증됨
- `DEGRADED`: 일부 Warning/비핵심 Failure가 있으나 현재 작업을 안전하게 제한 수행 가능
- `BLOCKED`: Core/Router/Index를 신뢰할 수 없거나 현재 Task의 Critical Policy·Bridge가 누락됨

Version mismatch만으로 오류라고 단정하지 않는다. 현재 Global Version과 `initialized_with`를 함께 보고하고 Compatibility 판단이 필요한지 설명한다.

동기화 중 일부 파일 누락, Index 파싱 실패, 정책 매핑 불일치가 있으면 Harness가 정상이라고 보고하지 않는다. 결함이 현재 Task와 무관한 경우에만 근거를 남기고 `DEGRADED`로 제한 수행한다. Migration의 P16, Security의 P17처럼 현재 Task의 Critical Policy가 없으면 `BLOCKED`다.

---

## 6. Secret 검사와 보고

Secret 검사는 API Key, Password, Access/Refresh Token, Private/Secret Key, Database Password, Credential JSON, Session Cookie, 운영 계정 인증정보의 명백한 값 패턴을 찾는다.

- 실제 값을 출력·복사·요약하지 않는다.
- 보고에는 파일명과 가능한 경우 줄 위치, Credential 종류만 기록한다.
- 환경변수명(`OPENAI_API_KEY`, `DATABASE_URL`, `AWS_PROFILE`, `GITHUB_TOKEN`) 또는 승인된 Secret Store를 사용한다는 참조는 실제 값으로 취급하지 않는다.
- 발견 시 노출 확대를 피하고 회수·교체 필요성을 Suggested Fix로 제시한다.

---

## 7. Repair Mode

기본 Doctor는 파일을 수정하지 않는다. 결과에 `Suggested Fix`만 제시한다.

사용자가 “Harness Doctor 실행하고 안전하게 고칠 수 있는 것까지 수정해줘”처럼 명시한 경우에만 다음 조건을 모두 만족하는 Harness 설정 수정이 가능하다.

1. 대상이 Harness 또는 Project Bridge Configuration으로 한정됨
2. 기존 사용자 작성 내용을 삭제하지 않음
3. Adapter 전체가 아니라 정확히 하나인 Managed Block만 갱신함
4. 중복·불균형 Marker는 임의 삭제하지 않고 Warning으로 남김
5. Application Source Code와 Business Logic은 수정하지 않음
6. Secret 실제 값을 읽어 보고서나 다른 상태 파일로 옮기지 않음

수정 후 동일 검사를 다시 실행하고 변경 항목과 남은 Warning을 보고한다.

---

## 8. Report Contract

```text
AI Harness Doctor

Target Type: GLOBAL_MASTER | PROJECT | COMBINED
Harness Root: ...
Project Root: ... | NOT APPLICABLE
Global Version: ...
Project initialized_with: ... | NOT APPLICABLE

Core: PASS | WARNING | FAIL
Router: PASS | WARNING | FAIL
Policy Index: PASS | WARNING | FAIL
Policies: 26 / 26 PASS | ...

Adapters:
- AGENTS.md: PASS | WARNING | FAIL | NOT INSTALLED
- CLAUDE.md: PASS | WARNING | FAIL | NOT INSTALLED
- GEMINI.md: PASS | WARNING | FAIL | NOT INSTALLED

JIT Loading: PASS | WARNING | FAIL
Full Policy Preload: NOT DETECTED | WARNING | FAIL
Secrets: PASS | WARNING | FAIL (값은 표시하지 않음)
Capability Catalogs: PASS | WARNING | FAIL
Project Capabilities: PASS | WARNING | FAIL | NOT INSTALLED
Broken References: ...
Runtime Health: HEALTHY | DEGRADED | BLOCKED

Overall: HEALTHY | DEGRADED | BLOCKED
Suggested Fixes: ...
```

보고서에는 실제로 확인한 Evidence만 사용한다. 확인하지 못한 항목은 `PASS`나 `HEALTHY`로 꾸미지 않는다.
