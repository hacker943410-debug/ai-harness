# ADR-008 — AI가 아닌 Harness가 프로젝트 실행을 통제한다

- 결정일: 2026-10-29
- 상태: **승인된 제품 방향 / 아키텍처 설계 후보 / 구현 완료 아님**
- 대상: 기존 v7.0.0, v7.0.1 Draft PR #5, 외부 Skill 보안 Draft PR #6의 후속 통합
- 후보 릴리스: **v8.0.0** (신뢰 경계가 바뀌므로 minor 버전이 아닌 major 버전 권장)
- 정식 운영 브랜치 `main`, 기존 릴리스와 사용자 프로젝트는 변경하지 않는다.

## 1. 최상위 사용자 요구사항

**AI는 개발 작업자이며 Harness의 운영자나 판정자가 아니다. Harness가 AI의 실행을 관리한다.**

사용자가 Codex, Claude Code, AGY 중 실제 사용하는 **한 CLI**를 설치·선택하면, Harness는 작업 요청·작업 환경·허용 도구·승인·예산·최종 검증을 소유한다. AI가 정책을 무시하라고 지시받거나 Harness 파일 수정을 제안하더라도, 거부/승인 여부는 AI와 다른 신뢰 경계에서 결정해야 한다.

구분:
1. AI는 설계 규칙의 **내용을 볼 수 있다**. 지켜야 하는 품질·의미적 규칙을 완전히 숨기면 올바른 개발을 보장할 수 없다.
2. AI는 **규칙의 활성화/해제·판정·예산 예외·완료 승인 권한이 없다**.
3. Harness 정책은 AI가 변경 가능한 작업 트리 바깥의 보호된 저장소/스냅샷에 위치한다.
4. AI가 자신의 동작을 보고하는 것은 참고 정보이며, 검증 PASS를 결정하는 증거가 아니다.

### 1.1 현재 코드와의 차이 (2026-10-29 main/PR #5 기준)

- `AGENTS.md`, `CLAUDE.md`, `CORE.md`, `ROUTER.md`는 에이전트에게 읽기/정책 선택을 *지시*한다. 지시는 집행 경계가 아니다.
- `scripts/harness-guard-v6-2.mjs`의 주석과 결과에는 일반 대화형 Codex 세션이 **가로채지지 않음**이 명시돼 있다. `GUARDED_EXEC_ONLY`, `interactive_enforcement: NOT_INSTALLED`.
- 관리형 Guard의 실제 토큰 사용량은 완료된 턴 이벤트에서 수집한다. 도중의 사전 강제 차단 또는 모든 CLI에 대한 보장으로 간주하지 않는다.
- v7.0.1 PR #5는 3종 CLI의 정책 브리지/파일 관리 경로를 추가하지만 실제 각 CLI에서 동등한 권한 강제를 입증하지 않는다.
- v7.1 보안 PR #6은 외부 Skill 설치 원본의 해시와 일부 위험 명령을 검사하나 일반 CLI 실행 전체를 통제하지는 않는다.

따라서 기존 정적 회귀 테스트가 PASS여도 사용자 요구인 **외부 집행**은 NOT_IMPLEMENTED다.

## 2. 신뢰 경계 및 실행 흐름

### 2.1 신뢰 영역

| 구성요소 | 신뢰 영역 | 허용 동작 | 금지 동작 |
|---|---|---|---|
| 사용자 / 별도 관리자 UI | 관리 | 정책 변경, 승인, 버전 선택 | 비밀값을 AI 프롬프트로 주입 |
| Harness Supervisor | **신뢰 경계 내부** | 사전 분류, 승인, 정책 주입, 실행 제어, 기록, 검증 | 사용자 승인 없이 권한 확대 |
| Policy Store & Registry | **AI 작업 폴더 외부** | 잠금 버전, 무결성·출처 검증, 정책 조회 | 에이전트의 쓰기·삭제 |
| CLI Adapter (Codex/Claude/AGY) | 신뢰된 중개자 | 공식 SDK/프로토콜/Hook 기능 매핑, 세션·도구 이벤트 전달 | 모델 자체에 승인 결정 위임 |
| AI CLI 및 하위 에이전트 | **비신뢰 실행 주체** | 허용된 Tool 호출과 코드 변경 제안 | policy/approval/secret store 수정 |
| 격리된 Workspace / Tool Executor | **별도 제한 권한** | 허가된 파일·네트워크·명령 실행 | 보호된 정책 루트, 관리자 토큰, 호스트 임의 접근 |
| Independent Verifier | **신뢰 경계 내부** | 테스트·해시·범위 검사, 완료/릴리스 게이트 | 에이전트의 PASS 텍스트 신뢰 |

### 2.2 실행 순서 (Host-owned)

1. **Entry**: 사용자는 Harness가 관리하는 실행 진입점(런처/GUI)으로 요청한다. 연결되지 않은 일반 `codex`/`claude`/`agy` 명령은 **Harness 강제 적용을 보장하지 않는다**.
2. **Preflight**: Supervisor가 프로젝트/버전/상태/CLI 설치·허용 도구/권한/예산/보호 경로를 읽기 전용으로 조사한다.
3. **Route**: 결정론적 규칙과 신뢰된 메타데이터로 Task/Phase/Risk/Boundary 및 P01~P26의 *필수* 정책을 선택한다. AI의 분류 제안은 입력 후보일 뿐 실행 권한을 결정하지 않는다. 불확실·중대한 위험은 정해진 상위 규칙/사용자 승인을 요구한다.
4. **Launch**: 모델·계정·비용 설정을 확정하고 제한된 환경에서 선택한 CLI 하나를 실행한다. 다른 CLI 설치·구독은 필수가 아니다. 사전 정책은 Supervisor가 필요한 부분만 읽기전용으로 제공한다.
5. **Gate every privileged action**: Tool 요청/파일 변경/네트워크/외부 MCP/권한 승격에 대해 Adapter가 요청을 Supervisor에 전달한다. 가능한 범위에서 실행 전 **ALLOW/DENY/REQUIRE_APPROVAL**을 반환한다. Hook만으로 빠짐없이 포착되지 않는 도구는 독립 Tool Executor/OS Sandbox로 제한한다.
6. **Audit**: 결정·실행·변경 파일·버전·실제 토큰/호출·실패·재시도와 누락된 관측을 신뢰된 위치에 기록한다. 민감정보 값은 저장하지 않는다.
7. **Verify**: 에이전트가 '완료'를 선언해도 Supervisor의 별도 검증기가 현재 코드/테스트 결과를 확인한다. 실패·미관측·검증기 오류는 PASS가 아니다.
8. **Release**: 배포·Push·PR 병합·민감정보 외부 전송 등은 Harness 승인 정책과 사용자 권한 확인 후 별도 수행한다.

## 3. 권한/정책 계약

### 3.1 절대로 AI에게 위임하지 않는 결정

- 정책의 원본, 배포 버전, 활성화/해제 및 긴급 예외
- 승인자 식별·토큰/비용 상한 변경·보호 파일 접근 승인
- 외부 Skill 설치/업데이트 및 MCP 고위험 도구 등록
- PR 병합, 운영 배포, 권한 확장, 기밀 데이터 전송
- 테스트 완료 판정, release GO/NO-GO 판정

### 3.2 통제의 강도 등급 (보고에 반드시 명시)

- **ENFORCED**: OS/격리·실행기 또는 검증된 도구 게이트로 통제하며 실제 우회 시험에 통과.
- **GATED**: 관리형 경로의 특정 도구 호출만 사전 차단; 미포착 표면 존재.
- **ADVISORY**: AI 지침/후속 검사 중심이며 실행 전에 막는다는 증거 없음.
- **UNOBSERVED**: 적용 및 실행 확인 불가. 절대 ENFORCED로 보고하지 않는다.

모델 자체의 의도, 프롬프트 또는 같은 쓰기 권한의 Hook만으로 **ENFORCED**를 선언하지 않는다.

### 3.3 FAIL CLOSED

감사/승인/정책 버전/인증/툴 중개/파일 접근 검증이 실패하면 **권한이 필요한 실행을 중지**하고 사유를 남긴다. 안전한 읽기 전용 점검은 별도 조건에서만 허용한다. 승인 타임아웃을 자동 승인으로 해석하지 않는다.

## 4. 실제 OS/CLI 통합에서 해결해야 할 제약

### 4.1 CLI별 기능

- **Codex**: 공식 App Server/SDK의 세션·이벤트·승인 흐름과 Sandbox를 먼저 평가한다. 공식 SDK가 모든 명령을 외부에서 강제 중개하는지, 어떤 도구가 직접 실행되는지 실제 버전으로 검증한다.
- **Claude Code**: PreToolUse·PermissionRequest·Stop 등의 Hook은 후보 중개 표면이다. Hook 설정 파일이 AI와 동일한 쓰기 권한에 있다면 통제의 최종 권한으로 사용할 수 없다.
- **AGY**: CLI `PreToolUse` 등의 Hook과 실제 deny 지원을 버전별 검증한다. 앱/IDE와 CLI의 Hook 설정 경로 및 동작은 별개일 수 있다.

각 CLI의 기능이 다른 경우 Harness **정책 의미는 동일하게** 유지하지만, 강제 가능한 범위가 낮은 CLI는 미지원 고위험 동작을 **거부/비활성화**한다. 약한 클라이언트 때문에 전체 정책을 낮추지 않는다.

### 4.2 일반 CLI 직접 실행과 관리자 권한

사용자가 앱 외부에서 CLI 바이너리를 직접 실행하거나, 실행 AI가 Supervisor/Hook/Policy Store를 수정할 수 있는 같은 OS 권한을 얻으면 관리형 런처만으로 절대 강제를 보장할 수 없다. Windows에서는 별도 제한된 실행 계정/파일 ACL, 프로세스·네트워크 격리, 허용된 바이너리 경로 같은 **OS 소유 보호 장치**를 평가한다.

**관리형 실행을 사용하지 않은 세션은 'UNMANAGED', 강제 통제 성공으로 보고 금지**한다.

보안 목표는 사용자가 자신 PC의 관리자 권한을 행사하는 것까지 막는 것이 아니라, **AI 실행 주체가 자신의 권한으로 통제 계층을 우회하지 못하도록 하는 것**이다.

## 5. 정책·Skill·모델 처리

- P01~P26는 기존 Source of Truth로 재사용하되, 규범성 내용의 자동 준수와 외부 Gate가 가능한 조항을 기계적으로 구분한다.
- JIT 정책 로딩은 Supervisor가 *필수 정책 후보를 선택*하고 실행 로그에 선택과 실제 전달을 기록한다. AI는 필요 추가 자료를 요청할 수 있지만 필수 정책을 임의 제외할 수 없다.
- Jev/소형 분류 모델은 비강제 참고 판단으로만 사용; 최종 정책 권한은 Supervisor.
- Skill Broker는 번들 우선·허용목록·커밋/해시 고정·외부 데이터/패키지 실행 감사·정책 격리. PR #6을 보안 입력으로 활용한다.
- Model Router는 실제 사용 가능한 계정/모델/추론비용을 점검하되 모델이 임의로 결제 수단/허용 제공자를 변경하지 못하게 한다. GPT-6.1 Terra는 실험 후보이며 API 요금과 CLI 구독 사용량을 혼동하지 않는다.
- 토큰 예산은 CLI가 제공하는 실제 계측 범위와 시점에 따라 **preflight estimate / streamed actual / post-run actual / unknown**을 구분한다. 모든 구독형 CLI의 정확한 과금액을 통일해 사전 차단할 수 있다고 주장하지 않는다.

## 6. 단계별 구현 계획

**Phase 0 — Trust-boundary inventory (최우선)**
- 기존 `scripts/harness-v6.mjs`, Guard, CLI Descriptor, Project Plan/Apply, Skill Installer에서 AI가 결정/수정 가능한 경로 전수 확인.
- 26개 정책 각각을 HOST_ENFORCEABLE / POST_VERIFIABLE / MODEL_GUIDANCE_ONLY / UNSUPPORTED로 매핑.
- 실제 선택한 CLI의 일반 대화형 우회 경로를 기록. 결과물: 현황 표 및 실패하는 기준 테스트.

**Phase 1 — Supervisor 최소 프로토타입**
- 프로젝트 바깥 Trust Store와 **읽기 전용 프리플라이트·권한 결정 서비스** 구현.
- 실행 API: `prepare` → `launch` → `authorize_tool` → `observe` → `verify` → `close`.
- 프로세스/실행기와 분리된 사용 권한; 권한 없는 코드의 정책 파일 쓰기 불가.
- 허용/거부/승인 대기/타임아웃/재시작을 상태 머신으로 구현.

**Phase 2 — 실제 사용 CLI 하나를 먼저 연결**
- 현재 이용하는 CLI 하나로 제한된 작업 공간에서 정책 로딩과 사전 차단/종료 후 검증을 E2E.
- 하위 Agent·MCP·Shell·작업 폴더 변경·호스트 네트워크를 각각 시험한다.
- 추가 Claude/AGY 어댑터는 동일 계약을 제공하지 못하는 기능은 UNSUPPORTED로 명시한다. 3개 구독을 요구하지 않는다.

**Phase 3 — 기존 v7 기능 통합**
- PR #5 정책 파일 브리지, PR #6 외부 Skill 설치 보호, 26개 JIT 정책, Phase Engine, Guard/토큰 측정, Roblox MCP 등을 Supervisor 하위 모듈로 통합한다.
- 문서와 테스트 결과만으로 완료 선언 금지; 사용자의 운영 프로젝트를 직접 변경하지 않는다.

**Phase 4 — Windows Control Center**
- 비개발자 대상 GUI의 '현재 CLI / 감독 여부 / 정책·보안 등급 / 예산 / 허용된 Skill / 실행 중 / 테스트·롤백' 화면.
- 모든 상태 표시는 관측 데이터에 연동한다. 프로그램 버튼으로 정책을 변경하려면 사용자 인증과 감사 기록을 요구한다.

## 7. 설계 참조

- 현재 저장소: `AGENTS.md`, `CORE.md`, `ROUTER.md`, `scripts/harness-guard-v6-2.mjs`, `docs/v7_0/CLI_TRIAD_COMPATIBILITY.md`.
- OpenAI Codex App Server/SDK 및 실행 소유권: https://developers.openai.com/blog/codex-as-a-platform
- OpenAI 안전 경계: https://developers.openai.com/api/docs/guides/agents/sandboxes
- Anthropic Claude Hooks: https://claude.com/blog/how-to-configure-hooks
- Google AGY CLI Hooks: https://www.agy.dev/docs/hooks/

본 ADR은 **방향과 위협 모델을 확정한 설계 문서**이다. 구현·OS 통제·실제 E2E를 완료했다는 증거가 아니다.
