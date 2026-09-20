# Optional Semantic Decision Engine

Document Version: 1.1
Harness Version Source: `POLICY_INDEX.yaml`의 `harness_version`
Default: disabled
Initial Mode: shadow

## 1. 목적

Jev를 일반 Coding Model이 아니라 제한된 선택지를 고르는 경량 Decision Model로 사용한다.

역할:

- Router
- Classifier
- Judge
- Guardrail
- Decision Advisor

Jev는 Runtime Core, JIT Loader, Agent Hierarchy, Model Hierarchy, Verification Policy를 대체하지 않는다.

## 2. Decision Hierarchy

```text
Deterministic Rule / Tool
        ↓ 의미 판단이 남은 경우
Optional Jev Decision
        ↓ 복잡한 Reasoning 또는 낮은 신뢰
Existing Router / Reasoning Model
```

Deterministic 대상:

- exit code
- 파일 존재
- JSON/Schema 파싱
- Test/Lint/Type Check 결과
- Git Diff 유무
- 고정된 숫자·문자열 비교

이런 값은 Jev에 묻지 않는다.

## 3. 적합한 Decision

후보 집합이 작고 미리 정의된 의미 분류에만 사용한다.

- 기존 Task / Phase / Risk / Boundary 분류
- 기존 Policy Bundle 후보 중 선택 보조
- 기존 Agent Role / Model Tier 후보 중 선택 보조
- 정형 검증 이후의 `continue | retry | stop | escalate` 보조
- 제한된 Semantic Quality / Completion 상태 보조

Jev가 처리하지 않는 것:

- 코드 작성
- Architecture 설계
- 복잡한 Root Cause 분석
- 대규모 Refactor 판단
- 복잡한 Debugging
- 일반 대화
- Permission·Budget·Provider Availability·Production Authorization 결정

## 4. Compact Input Contract

Jev에는 다음만 전달한다.

```text
decision_type
task_summary
current_phase
risk
candidate_values
active_constraints
available_capability_ids
```

전달하지 않는다.

- 전체 Repository
- 모든 Policy 전문
- 모든 Agent 문서
- 전체 대화 이력
- Secret·Credential
- 필요 이상의 Source Code
- 고객·사용자 민감 원문

## 5. Typed Output Contract

개념 출력:

```json
{
  "decision_type": "task_class",
  "value": "FEATURE",
  "confidence": null,
  "provider": "CONFIG_REQUIRED",
  "model": "CONFIG_REQUIRED",
  "latency_ms": null,
  "fallback_used": false
}
```

규칙:

- `value`는 입력 `candidate_values` 중 하나여야 한다.
- `confidence`는 Provider가 제공하고 의미가 확인된 경우에만 사용한다.
- confidence threshold는 실제 Calibration 전 `CONFIG_REQUIRED`다.
- 형식이 유효해도 판단이 틀릴 수 있으므로 Runtime Core가 최종 검토한다.

## 6. Feature Flag와 Mode

기본 Project 설정:

```yaml
decision_engine:
  engine: "jev"
  enabled: false
  mode: "shadow"
  provider: "CONFIG_REQUIRED"
  model: "CONFIG_REQUIRED"
  confidence:
    auto_accept: "CONFIG_REQUIRED"
    reasoning_review: "CONFIG_REQUIRED"
  fallback: "existing_router"
```

Mode:

- `disabled`: 호출하지 않는다. 기존 Router만 사용한다.
- `shadow`: 기존 Router가 실제 경로를 정하고 Jev 결과는 비교용 metadata만 기록한다.
- `advisory`: 허용된 낮은 위험 Decision에서만 Jev 추천을 사용하며 Runtime Core가 최종 통제한다.

Global 기본은 `enabled: false`, 최초 모드는 `shadow`다. `enabled: true`만으로 Provider 호출을 허용하지 않는다. Shadow 실행에는 Provider·Model·인증·응답 계약과 실제 실행 Evidence가 필요하다. Shadow는 실행 경로를 바꾸지 않으므로 Calibration 전 threshold를 `CONFIG_REQUIRED`로 유지할 수 있다. Advisory 또는 자동 수용에는 조정된 threshold가 추가로 필요하다.

## 7. Fallback

다음 상황은 모두 기존 Router 또는 Reasoning Model로 간다.

- Engine disabled
- Provider/Model 미설정
- Tool/Runtime capability 없음
- timeout
- unavailable / rate limit / provider outage
- authentication failure
- invalid response / unsupported schema
- 후보 밖 value
- confidence 없음 또는 기준 미달
- 복잡한 Reasoning 필요
- Security / Authorization / Secret / Production / Destructive boundary

Jev 실패는 Task 실패가 아니다. 기존 흐름이 Fallback의 정본이다.

## 8. Security Authority

Jev는 Risk를 분류할 수 있지만 다음을 승인할 수 없다.

- 파괴적 명령
- Production 배포
- Credential 접근
- Secret 노출
- Database 삭제
- Permission 상승
- Security Policy 우회
- 되돌릴 수 없는 외부 작업

Jev 출력의 `approved`, `allow`, `safe` 같은 필드는 실행 권한으로 해석하지 않는다. System/Platform Guard, Project Rule, Runtime Core, 사용자 승인 순서를 그대로 따른다.

## 9. JIT 연결

```text
Compact Task Representation
→ Deterministic Classification 가능한 부분 확정
→ 필요하고 사용 가능한 경우만 Jev가 남은 후보 분류
→ Runtime Core가 결과 검토·override
→ POLICY_INDEX 후보 선택
→ Materiality Filter
→ 선택된 Policy만 JIT Load
```

모든 Policy·Agent 문서를 먼저 읽고 Jev를 호출하지 않는다.

## 10. Verification 연결

먼저 실제 Test, Lint, Type Check, Schema, Exit Code를 확인한다.

Semantic 판단이 남아 있고 후보가 제한된 경우에만 Jev를 Judge로 사용할 수 있다. 복잡한 품질 평가, 원인 분석, 최종 Critical Review는 기존 Reasoning Model과 Verification Policy가 담당한다.

## 11. Decision Trace

기록 후보:

```text
decision_type
decision_value
confidence
provider
model
latency
fallback_used
existing_route
final_route
agreement
override_reason
```

기록 금지:

- Secret·Credential·API Key
- 민감한 전체 Prompt
- 전체 Source Code
- 고객·사용자 민감정보

초기 Shadow 단계에서는 별도 영구 로그 저장소를 만들지 않는다. 저장 위치와 보존 기간이 확정되기 전에는 현재 Task의 짧은 Evidence로만 유지한다.

## 12. Provider Reference

사용자가 제공한 참고 정보이며 Runtime 분기 로직이 아니다.

| 경로 | Model identifier | 상태 |
|---|---|---|
| TypeSafe AI direct | Jev | Provider 계약 확인 필요 |
| Vercel AI Gateway | `typesafe-ai/jev` | Shadow 검증 완료 — 공식 v4 typed 응답 계약·R0 실제 Canary 확인 |
| Cloudflare Workers AI | `typesafe/jev` | Provider 계약 확인 필요 |

현재 실행기는 `scripts/jev-decision.mjs`, 인증 참조는 `AI_GATEWAY_API_KEY`다. `zero_data_retention: false`인 환경에서는 `non_sensitive` 합성·축약 입력만 허용한다.

참고 Context Window: 32K.

참고 가격은 약 `$0.04~0.042 / 1M input tokens`, direct reference `$42 / 1B input tokens`로 제공됐다. 가격은 변경될 수 있으므로 Runtime Logic이나 threshold에 사용하지 않는다.

## 13. 단계식 도입

1. Phase 0 — Architecture / Documentation
2. Phase 1 — Disabled by default
3. Phase 2 — Shadow Routing
4. Phase 3 — Low-risk advisory Routing
5. Phase 4 — 일부 Continue / Retry / Stop 실험
6. Phase 5 — 실제 데이터 기반 JIT / Context 최적화

다음 단계는 이전 단계의 실제 Evidence와 사용자 승인을 요구한다.

## 14. 현재 구현 상태

- Phase 0: 적용
- Phase 1: 선언 계약 적용, Global 기본 비활성
- Phase 2: `scripts/jev-decision.mjs` 실행기와 `scripts/test-jev-scenarios.mjs` 검사기 적용
- 실제 Provider 호출: Vercel AI Gateway `typesafe-ai/jev` 비민감 합성 Canary 3건으로 연결·typed 응답 확인
- Shadow 비교 실행: 검증된 프로젝트가 명시적으로 opt-in할 수 있으며 기존 Router가 실제 경로를 계속 결정
- 검증: R1 오프라인 22/22와 추가 반례 2/2 통과, Calibration 전 threshold는 `CONFIG_REQUIRED`
- 기존 Router Fallback: 항상 유지
