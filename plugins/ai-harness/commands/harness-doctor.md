---
description: AI Harness 상태를 Read-only 로 진단한다 (Harness Doctor)
argument-hint: "[안전하게 고칠 수 있는 것까지 수정 — 생략 시 진단만]"
---

# Harness Doctor

```
HARNESS_ROOT = ${CLAUDE_PLUGIN_ROOT}/../..
```

## 할 일

1. `${CLAUDE_PLUGIN_ROOT}/../../HARNESS_DOCTOR.md` 를 읽는다.
2. 그 문서가 정의한 진단 계약대로 현재 프로젝트와 하네스 연결을 점검한다.
3. 사용자 추가 지시: $ARGUMENTS

## 기본 동작은 Read-only 다

Doctor 는 P27 이 아니라 **요청 시 읽는 운영 기능**이다.
Application Source Code 나 Business Logic 을 수정하지 않는다.

문제는 먼저 `Suggested Fix` 로 제시한다.
사용자가 "안전하게 고칠 수 있는 것까지 수정해줘" 라고 **명시한 경우에만**
기존 사용자 내용을 보존하면서 좁고 안전한 Harness Configuration 수정까지 수행한다.

## 점검 범위

- Global Root 와 Version, 프로젝트 `.ai/harness.yaml` 의 `initialized_with`
- `CORE.md` / `ROUTER.md` / `POLICY_INDEX.yaml` 읽기, `policy_count == 26`
- P01~P26 파일 매핑이 실제 디스크와 일치하는지
- Adapter 존재와 Managed Block, **26개 원문이 복사돼 있지 않은지**
- JIT 설정이 살아 있는지 (전체 preload 흔적이 없는지)
- 경로·참조, Version / Bridge mismatch
- `.ai/` 안의 명백한 Secret 값 흔적 — **값 자체는 보고서에 출력하지 않는다**

## 판정

- `HEALTHY` — 핵심 Runtime 과 현재 필요한 JIT 연결이 검증됨
- `DEGRADED` — 비핵심 결함이 있으나 현재 Task 를 안전하게 제한 수행 가능
- `BLOCKED` — 핵심 Runtime 을 신뢰할 수 없거나 현재 Task 의 Critical Policy 가 없음

Global Harness 저장소 자체에 Project Adapter 가 없는 것은 Core Failure 가 아니다.
CLI 기능·import·hook·slash command 는 현재 환경의 증거 없이 지원된다고 가정하지 않는다.
