---
description: 현재 프로젝트에 AI Harness 를 초기화한다 (최초 1회)
argument-hint: "[추가 지시 — 생략 가능]"
---

# AI Harness 초기화

하네스 정본(Layer A)은 이 플러그인의 상위 두 단계에 있다.

```
HARNESS_ROOT = ${CLAUDE_PLUGIN_ROOT}/../..
```

## 할 일

1. `${CLAUDE_PLUGIN_ROOT}/../../PROJECT_INIT.md` 를 읽는다.
2. 그 문서가 지시하는 대로 **현재 프로젝트**를 초기화한다.
   `HARNESS_ROOT` 는 위에서 계산한 경로다.
3. 사용자 추가 지시가 있으면 반영한다: $ARGUMENTS

## 지켜야 할 것

- **기존 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` 를 통째로 교체하지 않는다.**
  기존 내용은 보존하고 `<!-- AI-HARNESS:START -->` ~ `<!-- AI-HARNESS:END -->`
  마커 안쪽만 추가·갱신한다 (Idempotent Initialization).
- **26개 정책 원문을 프로젝트에 복사하지 않는다.** Adapter 는 `.ai/HARNESS.md` 를 가리키기만 한다.
  전체 preload 는 금지이며 필요한 정책만 JIT 로 읽는다.
- 프로젝트 `.ai/` 에는 **capability ID 와 참조 이름만** 적는다.
  API Key·Password·Token·Credential 실제 값은 절대 적지 않는다.
- 작은 프로젝트에 roadmap / DAG / ADR / maps 를 미리 만들지 않는다. 최소 구조만 만든다.

## 끝나면

`PROJECT_INIT.md` 의 설치 검증 항목을 확인하고, 통과하지 못한 것이 있으면 사유와 함께 보고한다.
실행하지 않은 것을 "완료"라고 보고하지 않는다.

이 명령은 프로젝트당 **최초 1회**다. 이후 작업은 `CORE + ROUTER + POLICY_INDEX + JIT Policy` 가 담당하며
`PROJECT_INIT.md` 를 다시 읽지 않는다.
