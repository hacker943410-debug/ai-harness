# AI Harness v6.0 Final Upgrade Instruction V3
## Beginner-Safe · Evidence-Driven · Token-Aware · Full SDLC · Maintenance-Safe Harness

> **문서 용도**
>
> 이 문서는 기존 AI Harness v5.x를 분석한 뒤 **AI Harness v6.0으로 실제 업그레이드하도록 Codex/AI Agent에게 전달하는 실행 지침서**다.
>
> v6.0의 최우선 목표는 단순히 숙련자의 생산성을 높이는 것이 아니다.
>
> **개발 경험이 적은 사용자도 Harness를 설치하고, Harness가 제공하는 질문·가이드·검증 절차를 순서대로 따라가기만 하면 설계부터 배포·운영까지 성공 가능성을 높일 수 있는 시스템**을 구축하는 것이 핵심이다.
>
> 따라서 v6.0은 다음을 동시에 수행해야 한다.
>
> - 개발 절차 강제
> - 초보자 안내
> - 중요한 의사결정 설명
> - 자동 검증
> - AI 역할 분리
> - Token / Context 비용 제어
> - Evidence 기반 완료 판정
> - Harness 자체 Benchmark
> - 배포 후 검증
> - 실패 경험의 Harness 규칙 승격

---

# 0. 최상위 실행 명령

현재 저장소의 **AI Harness v5.x 전체 구조, Runtime, AGENTS.md, JIT Policy, Skills, Project Init, Build Log, Patch Notes 및 관련 문서**를 먼저 조사하라.

그 후 본 문서를 기준으로 **AI Harness v6.0 업그레이드**를 수행하라.

다음 원칙은 선택사항이 아니라 **v6.0 필수 요구사항**이다.

1. 기존 Harness를 먼저 조사한다.
2. 이미 구현되어 있는 기능을 중복 구현하지 않는다.
3. 기존 구조의 좋은 부분은 최대한 유지한다.
4. v5와 v6 요구사항의 차이를 Gap Analysis로 먼저 작성한다.
5. 큰 구조 변경은 바로 실행하지 말고 사용자에게 설명한다.
6. 사용자가 초보자라고 가정하고 개발 과정 전체를 지속적으로 브리핑한다.
7. 중요한 선택지가 발생하면 사용자의 첫 지시를 그대로 기계적으로 수행하지 않는다.
8. 선택지별 장점·단점·주의점·향후 영향을 설명한 후 사용자가 결정하도록 한다.
9. 단, 되돌리기 쉽고 영향이 작은 구현 세부사항은 AI가 합리적인 기본값으로 처리한다.
10. 구현 전에 Acceptance Criteria와 Verification Method를 정의한다.
11. 구현한 Agent와 검증하는 Agent의 역할을 논리적으로 분리한다.
12. Evidence 없이 완료 상태로 변경하지 않는다.
13. 테스트 실패 상태에서 다음 Phase로 넘어가지 않는다.
14. UI 변경은 가능한 경우 실제 Browser Rendering을 확인한다.
15. 배포 성공만으로 작업을 완료 처리하지 않는다.
16. Production Verification을 통과해야 최종 완료로 본다.
17. 모든 주요 작업에서 Token / Time / Retry / Human Intervention을 측정 가능하게 한다.
18. Harness 자체도 Benchmark를 통해 이전 버전과 비교한다.
19. Token 절약을 이유로 품질 검증을 생략해서는 안 된다.
20. 품질 향상을 이유로 무조건 최고 모델·최고 Reasoning·전체 Context를 사용하는 것도 금지한다.

---

# 1. v6.0의 제품 목표

AI Harness v6.0은 단순한 Prompt 모음이 아니다.

다음 6가지 기능을 가진 **AI Development Operating System**으로 동작해야 한다.

## 1.1 Development Orchestrator

사용자의 요구사항을 분석하고 다음 개발 단계로 안내한다.

## 1.2 Beginner Guide

사용자가 현재 무엇을 하고 있는지 이해할 수 있도록 지속적으로 설명한다.

## 1.3 Guardrail

AI가 검증되지 않은 구현을 완료 처리하거나 중요한 단계를 건너뛰지 못하게 한다.

## 1.4 Decision Assistant

선택지가 존재할 때 단순 질문만 하지 않고 각 선택의 장단점과 위험을 설명한다.

## 1.5 Verification Harness

코드가 만들어졌다는 사실이 아니라 실제로 동작한다는 Evidence를 확보한다.

## 1.6 Evaluation Harness

속도, Token 사용량, 완성도, 회귀율, 재시도 횟수 등을 측정하여 Harness 자체를 개선한다.

---

# 2. Beginner Mode를 기본값으로 설정

Harness 최초 설치 및 신규 프로젝트 초기화 시:

```text
BEGINNER_MODE = ON
```

을 기본값으로 한다.

사용자가 명시적으로 Expert Mode를 요청하는 경우에만 축약된 브리핑을 사용할 수 있다.

---

# 3. Beginner Success Path

초보자는 Harness가 다음 순서대로 자동 안내해야 한다.

```text
INSTALL
  ↓
ENVIRONMENT DIAGNOSIS
  ↓
PROJECT INITIALIZATION
  ↓
GOAL INTERVIEW
  ↓
REQUIREMENTS GUIDE
  ↓
ARCHITECTURE DECISIONS
  ↓
ACCEPTANCE CRITERIA
  ↓
UX / UI FLOW
  ↓
VERTICAL SLICE
  ↓
FEATURE DEVELOPMENT
  ↓
AUTOMATED VERIFICATION
  ↓
INDEPENDENT REVIEW
  ↓
RELEASE CHECK
  ↓
DEPLOY
  ↓
PRODUCTION CHECK
  ↓
RETROSPECTIVE
  ↓
HARNESS BENCHMARK
```

초보자가 개발 순서를 직접 기억할 필요가 없어야 한다.

Harness가 다음 행동을 제시해야 한다.

---

# 4. 설치 직후 자동 진단

Harness 설치 또는 프로젝트 연결 직후 다음을 확인한다.

```text
Git
Runtime
Package Manager
Required CLI
Environment Variables
Repository Access
Build Command
Test Command
Lint Command
Type Check Command
Dev Server Command
Production Build Command
Deployment Target
Database
Migration Tool
Browser Test Capability
```

결과는 다음 형태로 사용자에게 보여준다.

```text
환경 진단 결과

Git                PASS
Node.js            PASS
Package Manager    PASS
Build              PASS
Test               NOT CONFIGURED
E2E                NOT CONFIGURED
Deployment         UNKNOWN

현재 개발 시작은 가능하지만,
자동 E2E 테스트가 구성되어 있지 않습니다.

권장:
Playwright 구성

이유:
화면 기능을 실제 브라우저에서 검증할 수 있기 때문입니다.
```

환경 문제를 발견하면 기능 개발보다 먼저 해결한다.

---

# 5. Project Initialization Wizard

신규 프로젝트 또는 Harness가 처음 적용된 프로젝트에서는 질문형 초기화를 실행한다.

초보자에게 한 번에 많은 질문을 하지 않는다.

다음 순서로 필요한 질문만 한다.

## 5.1 프로젝트 목적

```text
무엇을 만들고 싶은가?
누가 사용하는가?
가장 중요한 기능은 무엇인가?
```

## 5.2 운영 조건

```text
개인용 / 내부용 / 고객용
예상 사용자 수
모바일 필요 여부
로그인 필요 여부
결제 여부
민감정보 여부
외부 API 여부
```

## 5.3 배포 목표

```text
로컬 테스트만
사내 배포
인터넷 공개
Cloudflare
AWS
Azure
Vercel
기타
```

모르는 항목은 사용자가 억지로 결정하게 하지 않는다.

Harness가 적절한 기본값을 추천하고 이유를 설명한다.

---

# 6. Mandatory Development Lifecycle

기존의 단순한:

```text
설계
→ 화면 디자인
→ 기능 구축
```

흐름을 다음으로 확장한다.

```text
00 INTAKE
   ↓
01 DISCOVERY
   ↓
02 REQUIREMENTS
   ↓
03 ARCHITECTURE
   ↓
04 ACCEPTANCE
   ↓
05 UX / UI DESIGN
   ↓
06 VISUAL VERIFICATION
   ↓
07 VERTICAL SLICE
   ↓
08 FEATURE IMPLEMENTATION
   ↓
09 AUTOMATED VERIFICATION
   ↓
10 INDEPENDENT REVIEW
   ↓
11 RELEASE VERIFICATION
   ↓
12 DEPLOY
   ↓
13 PRODUCTION VERIFICATION
   ↓
14 RETROSPECTIVE
   ↓
15 HARNESS BENCHMARK / LEARNING
```

각 단계는 상태를 가져야 한다.

```text
NOT_STARTED
READY
IN_PROGRESS
WAITING_USER
BLOCKED
VERIFYING
FAILED
PASS
DEPLOYED
VERIFIED_PRODUCTION
```

---

# 7. Phase Enforcement

다음 원칙을 강제한다.

```text
이전 Gate FAIL
→ 다음 Phase 진행 금지

Acceptance Criteria 없음
→ 구현 시작 금지

Verification 실패
→ 완료 선언 금지

Critical Review Finding 존재
→ Release 금지

Production Verification 실패
→ 최종 완료 금지
```

단순 작업에서는 Phase를 합칠 수 있지만 검증 책임은 유지한다.

---

# 8. 모든 Phase의 표준 계약

각 Phase는 최소 다음 구조를 사용한다.

```text
GOAL
INPUT
SCOPE
NON_GOALS
CONSTRAINTS
DEPENDENCIES
DECISIONS
IMPLEMENTATION_PLAN
ACCEPTANCE_CRITERIA
VERIFICATION_METHOD
EXPECTED_EVIDENCE
RISKS
ROLLBACK
STOP_CONDITIONS
OUTPUT
HANDOFF
```

특히 다음 네 가지가 없으면 PASS 처리하지 않는다.

```text
GOAL
ACCEPTANCE_CRITERIA
VERIFICATION_METHOD
EVIDENCE
```

---

# 9. Continuous Beginner Briefing Protocol

Harness는 긴 작업 동안 사용자를 방치해서는 안 된다.

다음 시점에 간단한 브리핑을 제공한다.

```text
Phase 시작
중요한 결정 직전
사용자 선택 필요
주요 구현 완료
검증 결과 발생
오류 또는 Block 발생
배포 직전
배포 직후
```

기본 형식:

```text
[현재 단계]
현재 무엇을 하고 있는가

[왜 필요한가]
이 단계가 필요한 이유

[현재 상태]
진행 중 / 완료 / 실패 / 선택 필요

[다음 작업]
다음에 무엇을 할 것인가

[주의할 점]
초보자가 알아야 할 위험 또는 영향
```

브리핑은 짧고 이해하기 쉬워야 한다.

---

# 10. Choice / Decision Gate

중요한 선택지가 존재할 경우 AI가 임의로 고르거나 사용자의 최초 요청을 무조건 실행하지 않는다.

다음 상황에서는 Decision Gate를 실행한다.

```text
Architecture 변경
DB Schema 변경
Migration
Authentication
Authorization
Breaking API Change
Deployment 구조
Cloud Provider
외부 서비스
비용 차이
성능 Trade-off
보안 Trade-off
데이터 삭제
되돌리기 어려운 변경
장기 유지보수 비용 변화
```

---

# 11. Decision Briefing 형식

사용자에게 단순히:

```text
A와 B 중 무엇을 선택하시겠습니까?
```

라고 묻지 않는다.

다음 구조로 설명한다.

```text
선택지 A

장점
-

단점
-

주의점
-

장기 영향
-

적합한 경우
-

--------------------------------

선택지 B

장점
-

단점
-

주의점
-

장기 영향
-

적합한 경우
-

--------------------------------

현재 프로젝트 기준 추천 방향
-

추천 이유
-

최종 결정은 사용자가 선택
```

---

# 12. Safe Default Policy

모든 선택에서 사용자를 멈춰 세우면 초보자가 오히려 개발을 진행하지 못한다.

따라서 다음은 AI가 기본값을 선택할 수 있다.

```text
쉽게 되돌릴 수 있음
보안 영향 없음
비용 영향 거의 없음
Architecture 영향 없음
데이터 손실 없음
장기 유지보수 영향 미미
```

이 경우:

```text
기본값으로 진행한 내용
이유
변경 방법
```

을 짧게 알려준다.

---

# 13. Discovery Gate

코드를 수정하기 전에 다음을 조사한다.

```text
Repository Structure
Architecture
Database
API
Authentication
State Management
Design System
Dependencies
Tests
Build
Deployment
CI/CD
Existing Harness Rules
```

Discovery 단계에서는 원칙적으로 코드를 수정하지 않는다.

---

# 14. Requirements Gate

다음이 정의되어야 한다.

```text
Functional Requirements
Non-functional Requirements
User Flow
Edge Cases
Constraints
Non-goals
Operational Requirements
Security Requirements
```

모호한 요구사항을 AI가 조용히 가정하지 않는다.

중대한 모호성은 사용자에게 질문한다.

---

# 15. Architecture Gate

최소 다음을 검토한다.

```text
Frontend Boundary
Backend Boundary
API Contract
Data Model
State Management
Authentication
Authorization
Validation
Error Handling
Logging
Observability
Deployment
Rollback
```

---

# 16. Acceptance-First Development

기능 구현 전에 완료 기준을 정의한다.

나쁜 예:

```text
로그인 기능 구현
```

좋은 예:

```text
정상 로그인 성공
잘못된 비밀번호 처리
존재하지 않는 사용자 처리
세션 유지
로그아웃
Token 만료
비인가 접근 차단
새로고침 후 상태 확인
```

Acceptance Criteria는 테스트 작성의 기준이 된다.

---

# 17. UX / UI Gate

정상 화면만 설계하지 않는다.

각 화면에서 필요한 상태를 확인한다.

```text
Default
Loading
Empty
Error
Success
Disabled
Permission Denied
Offline
Mobile
Tablet
Desktop
```

---

# 18. Visual Verification

UI를 수정했다면 가능한 경우 실제 Browser Rendering을 확인한다.

표준 루프:

```text
Render
→ Screenshot
→ DOM Inspect
→ Compare
→ Fix
→ Re-render
```

가능한 도구:

```text
Playwright
Browser Automation
Chrome DevTools
Screenshot Diff
Figma Reference
```

UI를 보지 않은 상태에서 UI 완료를 선언하지 않는다.

---

# 19. Mandatory Vertical Slice

중대형 프로젝트에서는 전체 화면을 먼저 만든 뒤 Backend 전체를 만드는 방식을 기본값으로 사용하지 않는다.

먼저 핵심 Flow 하나를 실제 end-to-end로 완성한다.

예:

```text
로그인
→ 목록 조회
→ 상세 보기
→ 수정
→ API
→ DB 저장
→ 화면 반영
```

Vertical Slice에서 확인한다.

```text
UI
API
DB
Auth
Validation
Error Handling
Test
Deployment Compatibility
```

Vertical Slice가 PASS한 뒤 기능을 확장한다.

---

# 20. Implementation Strategy

작업은 가능한 한 작은 완료 단위로 나눈다.

좋은 작업 단위:

```text
1 User Flow
1 API
1 DB Migration
1 Component Group
1 Bug Fix
1 Refactor Scope
```

다음과 같은 요청을 하나의 Agent에게 그대로 주지 않는다.

```text
전체 앱 완성
전체 시스템 리팩터링
모든 화면 구현
전체 테스트 작성
```

먼저 분해한다.

---

# 21. Agent Role Model

v6.0에서는 다음 역할을 논리적으로 분리한다.

```text
Orchestrator
Explorer
Architect
Builder
Test Agent
Reviewer
Release Verifier
Documentation Agent
```

작은 프로젝트에서는 한 AI가 여러 역할을 순차 수행할 수 있다.

그러나 **Builder 역할의 결과를 Reviewer 역할이 독립적으로 다시 검증하는 과정**은 유지한다.

---

# 22. Orchestrator Rules

Orchestrator의 역할:

```text
Requirement Interpretation
Task Breakdown
Phase Management
Agent Routing
Decision Gate
Beginner Briefing
Progress Tracking
Evidence Collection
Final Handoff
```

Orchestrator는 가능한 한 다음을 직접 장기 보관하지 않는다.

```text
거대한 Tool Log
전체 Test Log
불필요한 Source Dump
반복 Debug Output
```

Worker는 요약된 결과를 반환한다.

---

# 23. Worker Handoff Contract

Worker는 상위 Agent에게 다음 형식으로 보고한다.

```text
STATUS
SUMMARY
FILES_CHANGED
DECISIONS
TEST_RESULTS
RISKS
BLOCKERS
EVIDENCE
NEXT_RECOMMENDATION
```

---

# 24. Independent Review

Reviewer는 가능하면 Builder와 다른 Context에서 동작한다.

Reviewer 검사 항목:

```text
Requirement Compliance
Architecture Violation
Regression
Security
Error Handling
Edge Cases
Unnecessary Complexity
Code Duplication
Test Gaps
Performance
Maintainability
```

Critical Finding이 존재하면 Release Gate를 통과시키지 않는다.

---

# 25. Verification Pyramid

프로젝트에 해당되는 검증을 사용한다.

```text
Static
Type
Unit
Integration
E2E
Visual
Security
Performance
Operational
```

---

# 26. 기본 검증 예시

## Static

```bash
npm run lint
npm run format:check
```

## Type

```bash
npm run typecheck
```

또는:

```bash
tsc --noEmit
```

## Unit

```bash
npm run test
```

## Production Build

```bash
npm run build
```

실제 명령은 Repository를 조사하여 사용한다.

존재하지 않는 명령을 임의로 생성하여 실행했다고 기록하지 않는다.

---

# 27. Evidence-Driven Completion

다음은 Evidence가 아니다.

```text
테스트했습니다.
정상입니다.
문제 없습니다.
```

다음 형태를 사용한다.

```text
Command:
npm run test

Result:
PASS

Tests:
28 / 28

Timestamp:
...

Relevant Output:
...
```

---

# 28. Build Log

기본 파일:

```text
harness/build-log.md
```

Build Log에는 계획보다 **실제로 일어난 결과**를 기록한다.

예:

```text
## Phase 08 — Leave Request

Status: PASS

Files Changed
- ...

Verification
- lint: PASS
- typecheck: PASS
- unit: 28/28 PASS
- integration: PASS
- E2E: 6/6 PASS

Reviewer
- PASS

Known Limitations
- none

Evidence
- ...
```

---

# 29. Release Gate

배포 전 다음을 확인한다.

```text
Requirements            PASS
Architecture            PASS
Acceptance              PASS
Unit                    PASS
Integration             PASS
E2E                     PASS
Visual                  PASS
Security                PASS
Production Build        PASS
Migration               PASS
Independent Review      PASS
Rollback                READY
```

해당되지 않는 항목은:

```text
N/A + 이유
```

로 기록한다.

---

# 30. Production Verification Gate

배포 명령 성공만으로 완료하지 않는다.

확인 항목:

```text
Application Health
Critical User Flow
API Health
Database
Migration State
Environment Variables
Error Logs
Monitoring
Authentication
```

통과하면:

```text
VERIFIED_PRODUCTION
```

상태로 변경한다.

---

# 31. Beginner Failure Recovery

초보자에게 긴 Stack Trace만 보여주지 않는다.

실패 시 다음 형식으로 설명한다.

```text
무엇이 실패했는가
-

왜 발생했을 가능성이 높은가
-

현재 프로젝트에 미치는 영향
-

자동으로 복구 가능한가
-

사용자 선택이 필요한가
-

다음에 할 작업
-
```

가능하면 AI가 먼저 안전한 복구를 시도한다.

---

# 32. Token Policy — 핵심 원칙

v6.0은 Token을 명시적인 운영 자원으로 관리한다.

목표는:

```text
최소 Token
```

이 아니라:

```text
필요한 품질을 유지하면서 불필요한 Token을 최소화
```

이다.

---

# 33. Token Budget Model

각 Phase에 Token Budget 개념을 도입한다.

정확한 절대 Token 수는 사용 모델과 프로젝트 크기에 따라 달라지므로 Runtime이 조정할 수 있게 한다.

기본 등급:

```text
TINY
SMALL
MEDIUM
LARGE
CRITICAL
```

예:

```text
Discovery              MEDIUM
Requirements           SMALL
Architecture           MEDIUM
Routine Implementation MEDIUM
Major Debugging        LARGE
Independent Review     MEDIUM
Release Audit          MEDIUM
Documentation          SMALL
```

---

# 34. Token Soft Limit / Hard Limit

각 작업은 다음 두 경계를 가진다.

```text
SOFT_LIMIT
HARD_LIMIT
```

SOFT_LIMIT 도달 시:

1. 현재 진행상황 요약
2. 불필요한 Context 제거
3. 반복 탐색 중단
4. 이미 읽은 파일 재탐색 방지
5. 필요하면 Context Compaction
6. 다음 작업 단위를 더 작게 분리

HARD_LIMIT 접근 시:

1. 새로운 대규모 탐색 금지
2. 현재 Evidence와 상태 저장
3. 작업을 안전한 checkpoint로 종료
4. 다음 Phase 또는 새 Context로 Handoff

품질 검증을 Token 때문에 생략하지 않는다.

---

# 35. JIT Context Policy

모든 문서를 항상 읽는 것을 금지한다.

필요한 정책만 로드한다.

예:

```text
DB 변경
→ DB Policy

UI 변경
→ UI Policy

Security 변경
→ Security Policy

Deploy
→ Deployment Policy

Review
→ Review Policy
```

---

# 36. Progressive Disclosure

Harness 문서는 다음 계층으로 구성한다.

```text
AGENTS.md
→ Router

Runtime Policy
→ 현재 Phase 제어

Skill
→ 작업별 실행 방법

Reference
→ 필요한 세부 정보
```

Root Context를 최소화한다.

---

# 37. AGENTS.md 최소화

AGENTS.md에는 다음만 남긴다.

```text
Harness Version
Core Invariants
Mandatory Workflow
Phase Gate
Decision Gate
Beginner Briefing
Verification Requirement
JIT Router
Agent Router
Forbidden Behaviors
```

세부 문서는 필요할 때만 읽는다.

---

# 38. Context Reuse

이미 조사한 사실을 이유 없이 반복해서 탐색하지 않는다.

다음 정보를 Cache/Context Note로 유지한다.

```text
Repository Map
Build Commands
Test Commands
Architecture Decisions
DB Schema Summary
API Contracts
Deployment Target
Known Constraints
```

단, 오래되었을 가능성이 있으면 재검증한다.

---

# 39. Context Compaction

다음 시점에 Context 정리를 수행할 수 있다.

```text
Phase 완료
Milestone 완료
대규모 Debug 종료
긴 Test Log 발생
새로운 독립 기능 시작
```

반드시 보존:

```text
Goal
Decisions
Acceptance Criteria
Architecture
Known Risks
Evidence
Remaining Tasks
```

---

# 40. Tool Output Policy

상위 Context에 다음을 그대로 반복 누적하지 않는다.

```text
수천 줄 Build Log
전체 node_modules 오류
반복 Stack Trace
전체 Source File
동일한 Search 결과
```

필요한 부분만 요약한다.

Raw Evidence는 파일 또는 별도 Artifact에 저장한다.

---

# 41. Model Routing Policy

모든 작업에 가장 비싼/강한 모델을 사용하지 않는다.

모델 이름보다 역할 등급을 사용한다.

```text
FAST
BALANCED
STRONG
MAX
```

권장:

```text
File Search             FAST
Repository Discovery    FAST / BALANCED
Routine Edit            FAST / BALANCED
Test Writing            BALANCED
UI Implementation       BALANCED
Architecture            STRONG
Complex Debugging       STRONG
Security Review         STRONG
Independent Review      STRONG
Release Audit           STRONG
Exceptional Problem     MAX
```

실제 모델명은 Runtime에서 현재 사용 가능한 모델에 매핑한다.

---

# 42. Reasoning Routing

```text
LOW
- Search
- File Discovery
- Mechanical Edit

MEDIUM
- Normal Coding
- Test Writing
- UI Work

HIGH
- Architecture
- Complex Debug
- Review
- Security
- Migration

MAX
- HIGH로 해결하지 못한 문제
- 실패 비용이 매우 큰 핵심 결정
- Benchmark에서 효과가 확인된 경우
```

---

# 43. Escalation Rule

다음 순서로 비용을 증가시킨다.

```text
FAST / LOW
   ↓ 실패 또는 불확실
BALANCED / MEDIUM
   ↓ 실패 또는 복잡
STRONG / HIGH
   ↓ 여전히 해결 불가
MAX
```

처음부터 MAX 사용 금지.

---

# 44. Parallel Agent Policy

병렬화는 독립성이 높은 작업에 사용한다.

좋음:

```text
Frontend
Backend
Testing
Documentation
Research
```

주의:

```text
같은 DB Schema
같은 API Contract
같은 File
Architecture Decision
```

초기 기본 동시 실행 Agent 수는 적게 유지하고 Benchmark 결과로 조정한다.

---

# 45. Git Worktree

병렬 Agent가 실제 코드를 수정하는 경우 Worktree를 고려한다.

예:

```text
worktree/frontend
worktree/backend
worktree/tests
```

원칙:

```text
독립 실행
동일 파일 충돌 최소화
Merge 전 Full Verification
Conflict 자동 강제 해결 금지
```

---

# 46. Harness Benchmark — 필수 기능

v6.0부터 Harness 변경 자체를 감으로 평가하지 않는다.

다음을 기록한다.

```text
Task Success Rate
First Pass Success Rate
Verification Pass Rate
Human Intervention Count
Token Usage
Wall Clock Time
Tool Call Count
Retry Count
Files Touched
Regression Count
Reviewer Findings
Post-Merge Defects
```

---

# 47. 추가 Benchmark 지표

```text
Context Load Size
Average Phase Duration
Repair Loop Count
Build Failure Rate
E2E Failure Rate
Visual Regression Count
Architecture Violation Count
Decision Gate Count
User Clarification Count
Rollback Count
Escalation Count
High-Reasoning Usage
```

---

# 48. Beginner Success Metrics

v6.0에는 초보자 관점의 지표도 추가한다.

```text
Guided Completion Rate
User Decision Error Recovery
Unexplained Failure Count
Required Manual Command Count
Required External Knowledge Count
Blocked-by-Environment Count
Successful First Deployment Rate
Production Verification Success Rate
```

특히 다음 값을 중요하게 본다.

```text
초보자가 별도 개발 지식 없이
Harness 안내만 따라가며
프로젝트를 성공적으로 완료할 수 있는가?
```

---

# 49. Benchmark Test Set

최소 다음 Case를 만든다.

```text
01 Small Bug Fix
02 UI Feature
03 API Feature
04 DB Migration
05 Full-stack Vertical Slice
06 Refactoring
07 Security Fix
08 Performance Improvement
09 Documentation Change
10 Deployment Change
11 Beginner New Project
12 Beginner Existing Project Modification
13 Failed Build Recovery
14 Production Deployment Recovery
```

---

# 50. v5 vs v6 비교

가능하면 동일한 Task를 사용하여 비교한다.

예:

```text
Harness           v5        v6

Success           PASS      PASS
First Pass        FAIL      PASS
Tokens            100       72
Time              100       78
Retries           4         1
Human Input       5         2
Regression        1         0
Reviewer Finding  3         1
```

절대값뿐 아니라 상대 변화도 기록한다.

---

# 51. Composite Score

다음 개별 점수를 계산할 수 있다.

```text
QUALITY
EFFICIENCY
STABILITY
AUTONOMY
BEGINNER_SUCCESS
```

하나의 종합 점수만으로 판단하지 않는다.

---

# 52. Benchmark Regression Gate

Harness 변경 후 다음이 발생하면 자동으로 개선으로 인정하지 않는다.

```text
Token 크게 증가
성공률 감소
회귀 증가
Human Intervention 증가
First Pass 감소
Beginner Completion 감소
```

Trade-off가 발생하면 PATCH_NOTES에 명시한다.

---

# 53. Retrospective

Milestone 종료 후 기록한다.

```text
What Worked
What Failed
Repeated AI Mistakes
Human Intervention Reason
Token Waste
Tool Call Waste
Missing Test
Missing Rule
Obsolete Rule
Skill Candidate
```

---

# 54. Harness Learning Loop

```text
Build
↓
Verify
↓
Review
↓
Deploy
↓
Production
↓
Failure / Human Correction
↓
Retrospective
↓
Rule / Test / Skill Update
↓
Benchmark
↓
Harness Improvement
```

반복 실수는 Prompt로만 해결하지 않는다.

가능하면 다음으로 승격한다.

```text
Test
Lint Rule
Architecture Rule
Skill
Reference
AGENTS Invariant
CI Gate
```

---

# 55. Recommended v6 Directory Structure

기존 v5 구조를 먼저 조사하고 호환성을 유지하면서 필요한 부분만 추가한다.

목표 구조 예:

```text
/
├─ AGENTS.md
├─ HARNESS_VERSION
├─ PROJECT_INIT.md
├─ PLANS.md
│
├─ harness/
│  ├─ runtime/
│  │  ├─ orchestrator.md
│  │  ├─ phase-engine.md
│  │  ├─ decision-gate.md
│  │  ├─ briefing-protocol.md
│  │  ├─ beginner-mode.md
│  │  ├─ token-policy.md
│  │  └─ model-router.md
│  │
│  ├─ policies/
│  │  ├─ architecture.md
│  │  ├─ coding.md
│  │  ├─ testing.md
│  │  ├─ security.md
│  │  ├─ ui-verification.md
│  │  ├─ deployment.md
│  │  └─ context-jit.md
│  │
│  ├─ agents/
│  │  ├─ explorer.md
│  │  ├─ architect.md
│  │  ├─ builder.md
│  │  ├─ tester.md
│  │  ├─ reviewer.md
│  │  ├─ release-verifier.md
│  │  └─ documentation.md
│  │
│  ├─ phases/
│  │  ├─ 00-intake.md
│  │  ├─ 01-discovery.md
│  │  ├─ 02-requirements.md
│  │  ├─ 03-architecture.md
│  │  ├─ 04-acceptance.md
│  │  ├─ 05-design.md
│  │  ├─ 06-visual-verification.md
│  │  ├─ 07-vertical-slice.md
│  │  ├─ 08-implementation.md
│  │  ├─ 09-verification.md
│  │  ├─ 10-review.md
│  │  ├─ 11-release.md
│  │  ├─ 12-deploy.md
│  │  ├─ 13-production-verify.md
│  │  └─ 14-retrospective.md
│  │
│  ├─ benchmark/
│  │  ├─ README.md
│  │  ├─ benchmark-schema.md
│  │  ├─ baseline/
│  │  ├─ cases/
│  │  └─ results/
│  │
│  ├─ context/
│  ├─ build/
│  └─ build-log.md
│
├─ skills/
└─ docs/
```

기존 구조가 더 적합한 경우 무조건 재배치하지 않는다.

---

# 56. Forbidden Behaviors

다음을 명시적으로 금지한다.

```text
검증 없이 완료 선언
테스트 실패 상태에서 다음 Phase 진행
Acceptance Criteria 없이 구현 시작
Discovery 없이 대규모 코드 수정
사용자에게 알리지 않은 Breaking Change
사용자에게 알리지 않은 파괴적 Migration
UI 확인 없이 UI 완료 선언
실행하지 않은 Command를 실행했다고 주장
존재하지 않는 Test Result 생성
Critical Review Finding 무시
중대한 선택을 사용자 설명 없이 독단 결정
모든 Context를 항상 로드
모든 작업에 최고 모델 사용
모든 작업에 MAX Reasoning 사용
모든 기능을 한 Agent에게 몰아주기
Raw Log를 Main Context에 무제한 누적
Token 절약을 위해 Verification 생략
초보자에게 설명 없이 Terminal 명령만 제시
Error 발생 후 이유 설명 없이 반복 재시도
```

---

# 57. Beginner Briefing Example

```text
현재는 데이터 구조를 결정하는 단계입니다.

이 단계에서 DB 구조가 결정되면
이후 API와 화면 구현 방식에도 영향을 주기 때문에
바로 코딩하지 않고 먼저 구조를 확정하고 있습니다.

현재 두 가지 방법이 있습니다.

A. 현재 상태만 사용자 테이블에 저장

장점
- 구조가 단순함
- 개발이 빠름

주의점
- 상태 변경 이력을 나중에 확인하기 어려움

B. 별도 상태 이력 테이블 사용

장점
- 변경 기록 추적 가능
- 운영 및 감사에 유리

주의점
- 테이블과 로직이 조금 더 복잡함

현재 프로젝트가 장기간 운영되는 업무 시스템이라면 B가 더 적합합니다.
MVP 속도가 최우선이라면 A도 가능합니다.

선택하시면 해당 방식으로 다음 설계를 진행하겠습니다.
```

---

# 58. Verification Briefing Example

```text
기능 구현은 끝났지만 아직 완료 상태는 아닙니다.

현재 검증 결과:

Lint          PASS
Type Check    PASS
Unit Test     PASS
Integration   PASS
E2E           5 / 6 PASS

실패 항목:
모바일 화면에서 저장 후 Loading 상태가 해제되지 않습니다.

현재 상태:
VERIFYING

다음 작업:
해당 문제를 먼저 수정한 뒤 E2E 전체를 다시 실행합니다.

기능 확장은 아직 진행하지 않습니다.
```

---

# 59. Token Briefing Example

초보자에게 Token도 이해할 수 있게 설명한다.

```text
현재 작업은 Repository 전체를 다시 읽을 필요가 없습니다.

이미 확인한 구조 정보를 재사용하고,
이번 기능에 필요한 API와 UI 관련 파일만 추가로 읽겠습니다.

이렇게 하면:
- 불필요한 Token 사용 감소
- 응답 속도 개선
- 이전 로그로 인한 Context 혼잡 감소

품질 검증에 필요한 테스트는 그대로 수행합니다.
```

---

# 60. v5 → v6 Migration Procedure

## Step 1 — Inventory

현재 Harness를 조사한다.

출력:

```text
Existing Files
Existing Runtime
Existing Policies
Existing Agents
Existing Skills
Existing JIT Logic
Existing Token Logic
Existing Verification
Existing Benchmark
Existing Beginner Guidance
```

---

## Step 2 — Gap Analysis

각 항목을 다음으로 분류한다.

```text
ALREADY_IMPLEMENTED
PARTIAL
MISSING
CONFLICTING
DEPRECATED
```

---

## Step 3 — Reuse First

이미 구현된 기능은 유지하고 필요한 부분만 확장한다.

중복 파일을 만들지 않는다.

---

## Step 4 — Migration Plan

파일별 변경 계획을 작성한다.

예:

```text
AGENTS.md
- 설명서 역할 축소
- Router / Invariant 중심으로 변경

runtime/core.md
- Phase Engine 연동
- Beginner Briefing 연결
- Decision Gate 추가

JIT_POLICY.md
- Phase / Task 기반 Context Routing 강화

token-policy.md
- 신규 추가

benchmark/
- v5 baseline 및 v6 비교 구조 추가
```

---

## Step 5 — Decision Review

다음 변경이 있으면 사용자에게 먼저 설명한다.

```text
Directory 대규모 재편
기존 Skill 삭제
기존 Runtime Logic 제거
호환성 깨짐
새로운 필수 Dependency
CI/CD 변경
```

---

## Step 6 — Implementation

작은 Patch 단위로 수행한다.

각 Patch 후 최소 검증한다.

---

## Step 7 — Harness Validation

다음을 검사한다.

```text
Broken Reference
Missing File
Duplicate Rule
Conflicting Rule
Circular Instruction
Dead Link
Broken Routing
Version Mismatch
Phase Deadlock
Decision Gate Deadlock
Beginner Flow Dead End
```

---

## Step 8 — Beginner Simulation

반드시 최소 한 번 다음 시나리오를 실행한다.

```text
사용자는 개발 초보자다.
새로운 간단한 웹 서비스를 만들고 싶다.
기술 스택을 정확히 모른다.
배포 방법도 모른다.
```

Harness가:

```text
질문
→ 추천
→ 주의점
→ 선택
→ 설계
→ 구현
→ 검증
→ 배포
```

까지 안내 가능한지 확인한다.

---

## Step 9 — Token Simulation

동일 작업에서 다음을 측정한다.

```text
Context Loaded
Tool Calls
Repeated Reads
Reasoning Escalations
Total Tokens
Retries
```

JIT Context 및 Model Routing이 실제 Token 절약에 기여하는지 확인한다.

---

## Step 10 — Benchmark

대표 Case를 실행하고 v5 baseline과 비교한다.

---

## Step 11 — Documentation

최소 다음을 갱신한다.

```text
README.md
HARNESS_VERSION
PATCH_NOTES.md
MIGRATION_NOTES.md
CHANGELOG.md
PROJECT_INIT.md
```

---

# 61. v6.0 Definition of Done

다음 조건을 모두 만족해야 v6.0 업그레이드를 완료 처리한다.

```text
[ ] v5 Inventory 완료
[ ] Gap Analysis 완료
[ ] Mandatory Lifecycle 구현
[ ] Phase Gate 구현
[ ] Beginner Mode 구현
[ ] Continuous Briefing 구현
[ ] Decision Gate 구현
[ ] Acceptance-first 구현
[ ] Vertical Slice 단계 구현
[ ] Verification Pyramid 반영
[ ] Independent Review 반영
[ ] Release Gate 구현
[ ] Production Verification 구현
[ ] Token Policy 구현
[ ] JIT Context 강화
[ ] Model Routing 구현
[ ] Reasoning Escalation 구현
[ ] Benchmark Framework 구현
[ ] Beginner Benchmark 추가
[ ] v5 Baseline 비교 가능
[ ] Build Log / Evidence 체계 구현
[ ] README 갱신
[ ] PATCH_NOTES 갱신
[ ] MIGRATION_NOTES 갱신
[ ] Harness Validation PASS
[ ] Beginner Simulation PASS
```

---

# 62. PATCH_NOTES.md 필수 요약

v6.0 Patch Notes에는 최소 다음을 포함한다.

```text
AI Harness v6.0

Major Changes

- Full SDLC Phase Engine
- Beginner Mode
- Guided Development Briefing
- User Decision Gate
- Acceptance-First Workflow
- Mandatory Vertical Slice
- Independent Builder / Tester / Reviewer Roles
- Evidence-Driven Completion
- Visual Verification
- Release Gate
- Production Verification
- Token Budget Policy
- JIT Context Loading
- Model / Reasoning Routing
- Context Compaction
- Harness Benchmark Framework
- Beginner Success Benchmark
- Regression Learning Loop
```

---

# 63. 최종 사용자 경험 목표

AI Harness v6.0을 설치한 초보자는 다음을 외우지 않아도 되어야 한다.

```text
어떤 순서로 개발해야 하는지
무엇을 먼저 설계해야 하는지
어떤 테스트가 필요한지
언제 배포해야 하는지
어떤 기술을 선택해야 하는지
어떤 명령을 실행해야 하는지
어떤 오류가 위험한지
언제 완료라고 판단해야 하는지
```

Harness가 단계별로 안내해야 한다.

사용자의 역할은 주로:

```text
목표 설명
중요한 선택 결정
결과 확인
```

이어야 한다.

AI의 역할은:

```text
조사
설계
선택지 분석
구현
검증
수정
리뷰
배포 지원
운영 확인
증거 기록
Benchmark
```

이어야 한다.

---

# 64. 최종 원칙

AI Harness v6.0의 성공 기준은:

> **AI가 많은 코드를 생성했는가가 아니다.**

다음이 진짜 성공 기준이다.

> **초보자가 Harness의 안내를 따라가면서도 잘못된 Architecture, 검증 누락, 배포 실패, Token 낭비를 최소화하고 실제 동작하는 제품까지 도달할 수 있는가?**

그리고 Harness는 매 프로젝트 이후:

```text
더 안전하게
더 적은 Token으로
더 빠르게
더 적은 사용자 개입으로
더 높은 검증 수준으로
```

진화해야 한다.

---

# 65. Codex에게 주는 최종 실행 지시

이 문서를 단순 참고문서로 취급하지 말라.

현재 AI Harness v5.x를 실제로 조사하고:

1. Inventory를 작성한다.
2. Gap Analysis를 작성한다.
3. 기존 구현을 최대한 재사용한다.
4. v6.0 Migration Plan을 작성한다.
5. 큰 선택만 사용자 Decision Gate로 올린다.
6. 승인 불필요한 안전한 변경은 계속 수행한다.
7. Phase Engine을 구현한다.
8. Beginner Mode와 지속 브리핑을 구현한다.
9. Acceptance / Verification / Evidence Gate를 구현한다.
10. Token / Context / Model Routing 정책을 구현한다.
11. Harness Benchmark 체계를 구현한다.
12. Beginner Simulation을 실행한다.
13. Harness Validation을 수행한다.
14. v5 대비 Benchmark 결과를 가능한 범위에서 작성한다.
15. README / PATCH_NOTES / MIGRATION_NOTES / CHANGELOG를 갱신한다.

최종 보고에는 반드시 다음을 포함한다.

```text
변경한 파일
새로 만든 파일
삭제한 파일
기존 기능 중 재사용한 부분
주요 Architecture 변경
Beginner Mode 동작 방식
Token Policy 동작 방식
Verification 결과
Benchmark 결과
Known Limitations
남은 위험 요소
향후 개선 권장사항
```

Evidence 없이 `AI Harness v6.0 완료`라고 선언하지 말라.

---

# 66. Project Mode Router — 운영 프로젝트 대응 필수

AI Harness v6.0은 모든 프로젝트에 동일한 절차를 강제하지 않는다.

작업 시작 시 현재 작업을 반드시 다음 4개 Project Mode 중 하나로 분류한다.

```text
GREENFIELD
- 신규 프로젝트
- 신규 서비스
- 신규 제품

MAINTENANCE
- 기존 프로젝트 기능 추가
- 일반 버그 수정
- 개선
- 소규모 리팩터링

HOTFIX
- 운영 장애
- 긴급 보안 수정
- 즉시 배포가 필요한 결함

MIGRATION
- Harness 버전 업그레이드
- Framework / Runtime 대규모 업그레이드
- DB Migration
- Architecture Migration
- Cloud / Deployment 구조 이전
```

모드가 확실하지 않으면 AI가 임의로 선택하지 말고 다음을 설명한 뒤 사용자에게 확인한다.

```text
현재 변경의 성격
추천 Project Mode
다른 Mode를 선택할 경우 달라지는 검증 범위
위험
배포 방식
Rollback 필요성
```

---

# 67. Project Mode 자동 판별 규칙

## GREENFIELD

```text
기존 Production 사용자가 없음
기존 데이터 보존 요구가 없음
기존 API 호환성 요구가 없음
기존 배포 환경에 대한 Regression 위험이 없음
```

## MAINTENANCE

```text
기존 사용자가 존재
기존 기능이 정상 동작 중
변경 범위가 제한적
Backward Compatibility가 중요
```

## HOTFIX

```text
현재 Production 장애
보안 사고
서비스 사용 불가
데이터 손상 위험
업무 중단
정상 절차를 모두 기다리기 어려운 긴급 상황
```

## MIGRATION

```text
대규모 의존성 변경
Runtime 변경
DB Schema 구조 변경
Framework major version 변경
Harness major version 변경
Deployment platform 변경
Architecture boundary 변경
```

---

# 68. Existing Behavior is a Contract

운영 중인 프로젝트에서는 다음을 기본 원칙으로 한다.

> 기존에 정상적으로 동작하는 기능과 외부 계약은 보호 대상이다.

따라서 기존 코드를 새로운 Harness 규칙에 자동으로 소급 적용하지 않는다.

다음 변경은 사용자 승인 또는 명시적 Migration Decision 없이 수행하지 않는다.

```text
대규모 Folder 구조 재편
Public API Signature 변경
DB Column 삭제
DB 데이터 변환
Authentication 방식 변경
Authorization 정책 변경
Build Tool 교체
Framework 교체
Deployment 구조 교체
환경변수 이름 변경
대규모 코드 스타일 정리
프로젝트 전체 리팩터링
```

---

# 69. No Retroactive Rule Application

다음 규칙을 강제한다.

```text
NEW HARNESS RULES MUST NOT BE
RETROACTIVELY APPLIED TO EXISTING CODE
WITHOUT AN EXPLICIT MIGRATION DECISION.
```

새로운 Harness 규칙은 기본적으로 다음 범위에 적용한다.

```text
신규 코드
신규 파일
이번 변경 범위
```

기존 코드 전체에 적용하려면:

```text
Migration Benefit
Migration Cost
Regression Risk
Required Test
Rollback
User Decision
```

을 먼저 작성한다.

---

# 70. Maintenance Workflow

기존 프로젝트의 일반 패치 및 업데이트는 다음 흐름을 사용한다.

```text
CURRENT STATE BASELINE
        ↓
CHANGE REQUEST
        ↓
DELTA DISCOVERY
        ↓
IMPACT ANALYSIS
        ↓
REGRESSION SCOPE
        ↓
PATCH PLAN
        ↓
ACCEPTANCE DELTA
        ↓
IMPLEMENTATION
        ↓
TARGETED VERIFICATION
        ↓
REGRESSION VERIFICATION
        ↓
INDEPENDENT REVIEW
        ↓
RELEASE CHECK
        ↓
DEPLOY
        ↓
PRODUCTION VERIFY
        ↓
OBSERVATION
        ↓
PATCH RETROSPECTIVE
```

---

# 71. Current State Baseline

기존 프로젝트 변경 전 반드시 Baseline을 기록한다.

```text
Current Git Commit
Current Branch
Application Version
Harness Version
Build Status
Test Status
Lint Status
Type Check Status
Critical E2E Status
Production Status
Database Schema Version
Migration Version
Deployment Version
Known Existing Issues
Known Failing Tests
```

가능하면 변경 전 다음을 실제 실행한다.

```text
lint
typecheck
unit test
critical integration test
production build
critical E2E
```

기존 실패가 있으면 반드시 기록한다.

변경 후 발생한 문제와 기존 문제를 혼동하지 않는다.

---

# 72. Delta Discovery

Maintenance Mode에서는 Repository 전체를 무조건 다시 읽지 않는다.

먼저 다음만 조사한다.

```text
변경 대상
직접 의존 파일
직접 API
직접 DB
직접 UI
직접 Test
관련 Config
관련 Deployment
```

영향 범위가 확대되는 경우에만 Context를 확장한다.

이 원칙은 Maintenance Mode의 Token 절약 핵심 정책이다.

---

# 73. Impact Analysis

코딩 전에 변경의 영향을 작성한다.

```text
CHANGE TARGET
-

DIRECT IMPACT
-

INDIRECT IMPACT
-

DATA IMPACT
-

API IMPACT
-

AUTH IMPACT
-

UI IMPACT
-

DEPLOYMENT IMPACT
-

REGRESSION RISK
-

ROLLBACK COMPLEXITY
-
```

영향을 확인하지 못한 영역은 `UNKNOWN`으로 기록하고 확인 후 진행한다.

---

# 74. Regression Scope

Maintenance Mode에서는 다음 두 가지를 동시에 정의한다.

```text
Acceptance Criteria
Regression Criteria
```

예:

```text
Requested Change
- 승인 후 상태가 APPROVED

Regression
- 반려 정상
- 승인 취소 정상
- 승인 후 수정 정상
- Calendar 반영 정상
- Notification 정상
- Dashboard 집계 정상
```

Patch 자체가 성공해도 Regression이 실패하면 완료가 아니다.

---

# 75. Minimum Necessary Change

Maintenance Mode의 기본 변경 원칙:

```text
MINIMUM NECESSARY CHANGE
```

금지 예:

```text
버그 하나 수정 중
→ 관련 Service 전체 리팩터링

UI 한 화면 수정 중
→ 전체 Design System 교체

Dependency 한 개 수정 중
→ Package 전체 최신화
```

별도 Refactor 승인 없이 요청 범위를 넘어선 정리는 하지 않는다.

---

# 76. Maintenance Change Classification

Maintenance 작업 시작 시 변경 유형을 분류한다.

```text
PATCH
FEATURE
REFACTOR
DEPENDENCY
DATA
SECURITY
INFRA
HARNESS
HOTFIX
```

각 유형에 따라 검증 강도를 다르게 한다.

---

# 77. Risk Level Classification

각 변경은 다음 위험 등급을 가진다.

```text
R0 — Cosmetic
R1 — Low
R2 — Medium
R3 — High
R4 — Critical
```

예:

```text
R0
- 문구
- 색상
- 단순 CSS

R1
- 제한된 UI 동작

R2
- 일반 API / Logic

R3
- Auth
- Payment
- DB Schema
- Deployment

R4
- Data Migration
- Security Incident
- Production Architecture
- Irreversible Operation
```

검증 강도와 사용자 Decision Gate는 위험도에 비례한다.

---

# 78. Risk-Based Verification

예:

```text
R0
- lint
- visual

R1
- lint
- type
- targeted unit
- visual

R2
- lint
- type
- unit
- integration
- affected E2E

R3
- full relevant verification
- independent review
- rollback test
- production smoke

R4
- migration rehearsal
- backup verification
- independent review
- staged rollout
- rollback rehearsal
- production observation
```

프로젝트 특성에 맞게 조정한다.

---

# 79. Maintenance Token Policy

Maintenance Mode에서는 Token 사용 순서를 다음처럼 제한한다.

```text
Global Project Summary
        ↓
Change Scope
        ↓
Dependency Map
        ↓
Affected Files
        ↓
Only if needed:
Expanded Repository Context
```

금지:

```text
작은 Patch에 Repository 전체 재독
관련 없는 정책 파일 로드
이미 확인한 Architecture 반복 조사
전체 Test Log를 Main Context에 누적
```

---

# 80. Before / After Evidence

Patch Build Log에는 반드시 다음을 분리한다.

```text
BEFORE
AFTER
REGRESSION
```

예:

```text
BEFORE
- build PASS
- unit 120/120 PASS
- E2E login PASS

AFTER
- build PASS
- unit 124/124 PASS

REGRESSION
- login PASS
- logout PASS
- password reset PASS
```

---

# 81. Maintenance Definition of Done

다음이 모두 충족되어야 한다.

```text
[ ] Requested Change PASS
[ ] Existing Baseline 확인
[ ] Impact Analysis 완료
[ ] Regression Scope 정의
[ ] Targeted Test PASS
[ ] Required Regression Test PASS
[ ] Build PASS
[ ] Independent Review PASS
[ ] Release Check PASS
[ ] Deploy PASS
[ ] Production Smoke PASS
[ ] Rollback Ready
```

---

# 82. HOTFIX Mode

Hotfix는 정상 Workflow를 삭제하는 것이 아니다.

긴급 상황에서는 일부 단계를 압축하거나 사후 수행할 수 있다.

```text
INCIDENT
↓
IMPACT / SEVERITY
↓
MINIMUM ROOT CAUSE ANALYSIS
↓
MINIMAL SAFE FIX
↓
CRITICAL VERIFICATION
↓
DECISION TO DEPLOY
↓
DEPLOY
↓
PRODUCTION CHECK
↓
FULL REGRESSION
↓
ROOT CAUSE ANALYSIS
↓
RETROSPECTIVE
↓
FOLLOW-UP PATCH
```

---

# 83. HOTFIX 최소 검증

긴급 상황에서도 다음은 기본적으로 생략하지 않는다.

```text
수정 파일 확인
Syntax / Type 확인
Critical Path Test
Production Build 가능 여부
Rollback 준비
배포 후 Smoke Test
```

데이터 손상 또는 Security 관련 Hotfix는 가능한 경우:

```text
Backup
Snapshot
Migration Rehearsal
```

도 수행한다.

---

# 84. HOTFIX 사용자 브리핑

초보자에게 다음을 명확히 설명한다.

```text
현재 장애 영향
긴급 수정이 필요한 이유
정상 절차 중 생략/후순위 처리되는 단계
즉시 수행할 검증
배포 위험
Rollback 방법
배포 후 반드시 수행할 추가 검증
```

---

# 85. HOTFIX 금지사항

```text
긴급하다는 이유로 전체 리팩터링
원인을 모른 채 반복 배포
Rollback 없이 Production 변경
Production에서 직접 무기록 수정
실패한 Hotfix를 다시 검증 없이 재배포
```

---

# 86. MIGRATION Mode

Migration은 일반 Patch보다 높은 검증 수준을 사용한다.

대상:

```text
Harness Upgrade
Framework Upgrade
Runtime Upgrade
Database Migration
Authentication Migration
Infrastructure Migration
Architecture Migration
```

흐름:

```text
INVENTORY
↓
BASELINE
↓
TARGET STATE
↓
GAP ANALYSIS
↓
COMPATIBILITY ANALYSIS
↓
MIGRATION PLAN
↓
BACKUP / ROLLBACK PLAN
↓
DRY RUN
↓
STAGING VALIDATION
↓
REPRESENTATIVE TASK TEST
↓
REGRESSION
↓
BENCHMARK
↓
USER DECISION
↓
ACTIVATION
↓
PRODUCTION VALIDATION
↓
OBSERVATION
↓
MIGRATION RETROSPECTIVE
```

---

# 87. Harness Upgrade Mode

Harness major upgrade는 일반 문서 덮어쓰기로 처리하지 않는다.

예:

```text
AI Harness v5
→ AI Harness v6
```

필수 단계:

```text
Existing Harness Inventory
Existing Custom Rules
Existing Skills
Existing Runtime
Existing JIT Policy
Existing Token Policy
Existing Project-specific Overrides
↓
v6 Gap Analysis
↓
Compatibility Analysis
↓
Conflict Analysis
↓
Migration Plan
↓
Dry Run
↓
Harness Validation
↓
Representative Project Task
↓
Benchmark
↓
Activation
```

---

# 88. Harness Upgrade Compatibility Matrix

다음 형식으로 기록한다.

```text
Component | Current | Target | Compatibility | Action | Risk
```

예:

```text
AGENTS.md | v5 | v6 router | PARTIAL | merge | MEDIUM
JIT Policy | v5 custom | v6 enhanced | COMPATIBLE | reuse + extend | LOW
Skill X | custom | v6 | CONFLICT | manual decision | HIGH
```

---

# 89. Harness Upgrade Rule

Harness 업그레이드 시 다음을 보존한다.

```text
프로젝트 고유 규칙
이미 검증된 Build Command
이미 검증된 Test Command
Custom Skill
Deployment Constraints
Domain Knowledge
Security Constraints
```

새 Harness가 이를 임의 삭제하지 않는다.

---

# 90. Harness Version Pinning

각 프로젝트는 가능한 경우 Harness Version을 명시한다.

```text
HARNESS_VERSION=6.0.0
```

또는:

```yaml
harness:
  version: 6.0.0
  mode: maintenance
```

현재 프로젝트의 기록된 버전과 현재 설치 버전이 다르면:

```text
HARNESS MIGRATION DETECTED
```

를 표시하고 Migration Mode를 제안한다.

---

# 91. Framework / Dependency Migration

Major Dependency 변경은 다음을 확인한다.

```text
Breaking Changes
Deprecated APIs
Peer Dependencies
Build Tool Compatibility
Runtime Compatibility
Type Compatibility
Test Compatibility
Deployment Compatibility
Security Impact
```

자동으로 모든 Package를 최신화하지 않는다.

---

# 92. Database Migration Safety

DB 변경 시 반드시 분류한다.

```text
Additive
Transformative
Destructive
```

## Additive

```text
새 Column
새 Table
새 Index
```

## Transformative

```text
Data Backfill
Column Split
Format Change
```

## Destructive

```text
Column Drop
Table Drop
Data Delete
Type Narrowing
```

Transformative 또는 Destructive 변경은 높은 Risk Level로 처리한다.

---

# 93. DB Migration Gate

필수 확인:

```text
Backup
Forward Migration
Backward Compatibility
Rollback
Data Validation
Dry Run
Row Count
Null / Constraint
Performance
Lock Time
```

대규모 운영 DB에서는 Migration 실행시간도 검증한다.

---

# 94. API Compatibility Gate

기존 API 변경 시 확인한다.

```text
Request Compatibility
Response Compatibility
Field Removal
Field Rename
Type Change
Status Code Change
Error Contract
Client Dependency
Versioning
```

Breaking Change이면 반드시 사용자에게 설명한다.

---

# 95. Auth / Security Migration Gate

다음 변경은 자동 진행하지 않는다.

```text
JWT 정책
Session 정책
Password 정책
MFA
Role / Permission
OAuth Provider
Secret Rotation
Encryption
```

사용자 선택 전에 다음을 설명한다.

```text
기존 사용자 영향
로그인 유지 여부
강제 재로그인 여부
데이터 영향
Rollback 가능 여부
보안 개선 효과
```

---

# 96. Staged Rollout

위험도가 높은 변경은 가능한 경우 다음 중 하나를 사용한다.

```text
Feature Flag
Canary
Blue / Green
Small User Group
Staging
Shadow Traffic
Read-only Validation
```

즉시 전체 Production 전환을 기본값으로 하지 않는다.

---

# 97. Observation Window

배포 직후 성공 여부를 즉시 확정하지 않는다.

프로젝트 특성에 따라 다음을 확인한다.

```text
Error Rate
Latency
Critical API
DB Error
Authentication Failure
Queue / Job Failure
User Report
Resource Usage
```

Observation 기간은 변경 위험도에 따라 결정한다.

---

# 98. Rollback Classification

각 변경의 Rollback 가능성을 기록한다.

```text
EASY
MODERATE
HARD
IRREVERSIBLE
```

`HARD` 또는 `IRREVERSIBLE`이면 Decision Gate를 강화한다.

---

# 99. Project Mode별 사용자 개입 수준

## GREENFIELD

```text
제품 방향
중요 Architecture 선택
비용 / 보안 / 운영 선택
```

## MAINTENANCE

```text
기존 동작 변경
Breaking Change
범위 확대
Refactor
Migration
```

일 때 질문한다.

## HOTFIX

질문 수를 최소화하되:

```text
배포 위험
데이터 영향
Rollback
```

은 명확히 브리핑한다.

## MIGRATION

중요 변경마다 Decision Gate를 적극 사용한다.

---

# 100. Project Mode별 Token 우선순위

```text
GREENFIELD
- Architecture 이해에 충분한 Context 허용

MAINTENANCE
- Delta-first
- affected scope 우선

HOTFIX
- Critical path 우선
- 탐색 최소화
- Evidence 보존

MIGRATION
- Compatibility Context 우선
- 과거 / 현재 / 목표 상태 비교
```

---

# 101. Project Mode별 Benchmark

Benchmark에는 Mode를 반드시 기록한다.

```text
mode=GREENFIELD
mode=MAINTENANCE
mode=HOTFIX
mode=MIGRATION
```

동일 Mode끼리 비교한다.

---

# 102. Maintenance Benchmark 지표

```text
Regression Escape Rate
Unrelated Files Changed
Patch Size
Affected Test Coverage
Baseline Drift
Rollback Success
Post-Deploy Incident
```

---

# 103. HOTFIX Benchmark 지표

```text
Time to Mitigation
Critical Verification Time
Rollback Readiness
Repeat Incident
Post-Hotfix Regression
Follow-up Debt
```

속도만 높고 재발이 많으면 좋은 Hotfix가 아니다.

---

# 104. MIGRATION Benchmark 지표

```text
Compatibility Issues Found Before Deploy
Rollback Success
Migration Duration
Data Validation Error
Downtime
Manual Intervention
Post-Migration Defects
```

---

# 105. Mode Transition

작업 중 Mode를 변경할 수 있다.

예:

```text
MAINTENANCE
→ 영향 분석 결과 대규모 DB 변경 필요
→ MIGRATION
```

또는:

```text
MAINTENANCE
→ Production 장애 발생
→ HOTFIX
```

Mode가 변경되면 다음을 브리핑한다.

```text
변경 이유
추가 Gate
검증 범위 변화
Token / Context 변화
사용자 주의점
```

---

# 106. Mode Escalation Rule

Risk가 증가하면 더 엄격한 Mode로 올린다.

```text
PATCH
→ DATA Migration 발견
→ MIGRATION

FEATURE
→ Auth 구조 변경 필요
→ MIGRATION

BUG
→ Production outage
→ HOTFIX
```

검증을 줄이기 위해 Mode를 임의 하향하지 않는다.

---

# 107. Change Request Intake Template

기존 프로젝트 업데이트 시 Harness는 다음 정보를 최소한 확보한다.

```text
무엇을 바꾸려는가
왜 바꾸려는가
현재 정상 동작은 무엇인가
절대 깨지면 안 되는 기능
운영 중인가
실제 사용자 / 데이터가 있는가
배포 환경
희망 배포 시점
긴급도
```

초보자가 모르는 항목은 AI가 Repository와 환경에서 조사한다.

---

# 108. Maintenance Beginner Briefing Example

```text
현재는 기존 기능을 수정하는 Maintenance Mode입니다.

신규 프로젝트처럼 전체 구조를 다시 만들지 않고,
이번 변경과 직접 관련된 코드와 영향 범위만 먼저 확인합니다.

이번 수정에서 중요한 점은
새 기능이 동작하는 것뿐 아니라 기존 기능을 깨뜨리지 않는 것입니다.

따라서 다음 순서로 진행합니다.

1. 현재 정상 상태 확인
2. 변경 영향 분석
3. 최소 범위 수정
4. 수정 기능 테스트
5. 기존 기능 회귀 테스트
6. 배포
7. 운영 상태 확인

현재는 1단계인 기존 상태 확인 중입니다.
```

---

# 109. Migration Beginner Briefing Example

```text
현재 작업은 일반 패치가 아니라 Migration으로 분류됩니다.

이유:
현재 Framework 버전을 변경하면 Build, Dependency, Test,
Deployment 방식까지 영향을 받을 수 있기 때문입니다.

바로 업데이트하지 않고 먼저 다음을 확인합니다.

- 현재 버전
- 목표 버전
- Breaking Change
- 기존 코드 영향
- Rollback 가능 여부

그 후 실제 변경 전에 Dry Run을 진행합니다.
```

---

# 110. Hotfix Beginner Briefing Example

```text
현재는 Production 장애가 있어 Hotfix Mode로 전환했습니다.

일반 개발보다 빠르게 수정해야 하지만,
검증을 생략하지는 않습니다.

먼저 서비스 복구에 필요한 최소 수정만 적용하고,
Critical Test와 Rollback 준비 후 배포합니다.

전체 회귀 테스트와 상세 원인 분석은
서비스가 복구된 직후 이어서 수행합니다.
```

---

# 111. Project Mode Router 파일 권장

```text
harness/runtime/project-mode-router.md
```

책임:

```text
Mode 판별
Risk 판별
Workflow 선택
Verification Profile 선택
Token Profile 선택
Decision Gate 강도 선택
```

---

# 112. Verification Profiles 권장

```text
harness/runtime/verification-profiles.md
```

예:

```text
PROFILE_GREENFIELD
PROFILE_MAINTENANCE_LOW
PROFILE_MAINTENANCE_HIGH
PROFILE_HOTFIX
PROFILE_MIGRATION
```

---

# 113. Token Profiles 권장

```text
harness/runtime/token-profiles.md
```

예:

```text
GREENFIELD_CONTEXT
MAINTENANCE_DELTA
HOTFIX_CRITICAL
MIGRATION_COMPATIBILITY
```

---

# 114. Project Mode와 Beginner Mode의 관계

Beginner Mode는 Project Mode와 별개다.

```text
BEGINNER + GREENFIELD
BEGINNER + MAINTENANCE
BEGINNER + HOTFIX
BEGINNER + MIGRATION

EXPERT + GREENFIELD
EXPERT + MAINTENANCE
EXPERT + HOTFIX
EXPERT + MIGRATION
```

초보자라고 검증을 약하게 하지 않는다.

차이는 설명의 깊이와 안내 방식이다.

---

# 115. 최종 Runtime Routing

```text
USER REQUEST
    ↓
PROJECT DETECTION
    ↓
PROJECT MODE
    ↓
RISK LEVEL
    ↓
BEGINNER / EXPERT
    ↓
PHASE WORKFLOW
    ↓
JIT CONTEXT
    ↓
MODEL / REASONING ROUTER
    ↓
IMPLEMENT
    ↓
VERIFY
    ↓
REVIEW
    ↓
EVIDENCE
```

---

# 116. v6.0 최종 핵심 원칙 보강

AI Harness v6.0은 다음을 동시에 달성해야 한다.

```text
NEW PROJECT SUCCESS
EXISTING PROJECT SAFETY
BEGINNER GUIDANCE
TOKEN / CONTEXT EFFICIENCY
```

하나를 희생해서 다른 하나를 최적화하지 않는다.

---

# 117. 최종 Definition of Done 보강

기존 v6.0 Definition of Done에 다음을 추가한다.

```text
[ ] Project Mode Router 구현
[ ] GREENFIELD Workflow 구현
[ ] MAINTENANCE Workflow 구현
[ ] HOTFIX Workflow 구현
[ ] MIGRATION Workflow 구현
[ ] Existing Behavior Contract 구현
[ ] Retroactive Rule 금지 구현
[ ] Current State Baseline 구현
[ ] Impact Analysis 구현
[ ] Regression Scope 구현
[ ] Minimum Necessary Change 구현
[ ] Risk Classification 구현
[ ] Risk-based Verification 구현
[ ] Maintenance Token Profile 구현
[ ] Before/After Evidence 구현
[ ] Harness Migration Workflow 구현
[ ] Harness Version Pinning 구현
[ ] DB Migration Gate 구현
[ ] API Compatibility Gate 구현
[ ] Security Migration Gate 구현
[ ] Staged Rollout 가이드 구현
[ ] Rollback Classification 구현
[ ] Mode-specific Benchmark 구현
[ ] Mode Transition 구현
[ ] Beginner Mode × Project Mode 조합 검증
```

---

# 118. 최종 Harness Validation 시나리오 보강

최소 다음 시나리오를 검증한다.

```text
Scenario A
초보자 + 신규 웹 프로젝트

Scenario B
초보자 + 운영 중 프로젝트 Bug Patch

Scenario C
초보자 + 기존 프로젝트 기능 추가

Scenario D
초보자 + DB Schema Migration

Scenario E
초보자 + Harness v5 → v6 Upgrade

Scenario F
운영 장애 + Hotfix

Scenario G
Framework Major Upgrade

Scenario H
UI 소규모 수정
```

각 시나리오에서 확인:

```text
올바른 Mode 선택
필요한 질문
불필요한 질문 최소화
올바른 Context 범위
올바른 Verification
Evidence 생성
Rollback 고려
초보자 브리핑
Token 낭비 여부
```

---

# 119. 최종 PATCH_NOTES 추가 항목

```text
- Project Mode Router
- Greenfield / Maintenance / Hotfix / Migration workflows
- Existing Behavior Contract protection
- Delta-first Maintenance analysis
- Impact / Regression gates
- Minimum Necessary Change policy
- Risk-based verification
- Maintenance token profile
- Harness migration safety
- Harness version pinning
- Database / API / Auth compatibility gates
- Staged rollout guidance
- Mode-specific benchmark metrics
- Beginner guidance across existing-project updates
```

---

# 120. 최종 실행 명령 보강

Codex는 AI Harness v6.0 업그레이드 시 신규 프로젝트 Workflow만 구현해서는 안 된다.

반드시 다음을 실제 Harness Runtime에 반영하라.

```text
PROJECT_MODE_ROUTER
BEGINNER_MODE
RISK_ROUTER
PHASE_ENGINE
DECISION_GATE
JIT_CONTEXT
TOKEN_ROUTER
MODEL_ROUTER
VERIFICATION_PROFILE
REVIEW_GATE
EVIDENCE_LOG
BENCHMARK
```

그리고 최소 다음 4개의 End-to-End Harness Flow를 검증하라.

```text
GREENFIELD
MAINTENANCE
HOTFIX
MIGRATION
```

Evidence 없이 v6.0 완료를 선언하지 말라.

---

# 121. Development State — 개발 진행 상태 축 추가

Project Mode만으로는 프로젝트의 현재 진행 상태를 충분히 표현할 수 없다.

AI Harness v6.0은 Project Mode와 별개로 반드시 Development State를 관리한다.

```text
NOT_STARTED
- 아직 실제 구현이 시작되지 않음

IN_PROGRESS
- 현재 구현 / 테스트 / 수정 작업이 진행 중

SAFE_CHECKPOINT
- 현재 상태를 안전하게 복원할 수 있음

FROZEN_FOR_MIGRATION
- Harness 또는 주요 환경 전환을 위해 기능 변경을 일시 중지한 상태

RESUMING
- Harness / Migration 이후 기존 개발 흐름으로 복귀 중

STABLE
- 현재 기준으로 주요 작업과 검증이 완료된 안정 상태
```

Project Mode와 Development State는 독립적인 축이다.

예:

```text
PROJECT_MODE = GREENFIELD
DEVELOPMENT_STATE = IN_PROGRESS
```

또는:

```text
PROJECT_MODE = MAINTENANCE
DEVELOPMENT_STATE = SAFE_CHECKPOINT
```

---

# 122. Harness Update During Active Development

개발 중이라고 Harness 업데이트를 금지하지 않는다.

다만 다음 규칙을 적용한다.

```text
DO NOT CHANGE HARNESS RULES
INSIDE AN ACTIVE IMPLEMENTATION PHASE
UNLESS THE UPDATE IS REQUIRED TO RESOLVE
A BLOCKING HARNESS DEFECT.
```

즉 활성 구현 Phase 내부에서 Harness의 주요 규칙을 즉시 교체하지 않는다.

기본 절차:

```text
ACTIVE DEVELOPMENT
      ↓
SAFE CHECKPOINT
      ↓
FREEZE CURRENT FEATURE CHANGES
      ↓
HARNESS MIGRATION
      ↓
HARNESS VALIDATION
      ↓
TRANSITION AUDIT
      ↓
PROJECT REGRESSION CHECK
      ↓
RESUME DEVELOPMENT
```

---

# 123. Safe Checkpoint 정의

Harness 업데이트 전에 현재 프로젝트가 최소한 다음 상태를 만족해야 한다.

```text
SAFE_CHECKPOINT

[ ] 현재 변경 파일이 식별 가능
[ ] Git 상태가 기록됨
[ ] 현재 Branch 기록
[ ] 기준 Commit 기록
[ ] 현재 Goal 기록
[ ] 현재 Acceptance Criteria 기록
[ ] 완료된 작업 기록
[ ] 미완료 작업 기록
[ ] 현재 Test 결과 기록
[ ] Known Failure 기록
[ ] DB Migration 상태 기록
[ ] Environment 변경사항 기록
[ ] 다음 작업 기록
[ ] Rollback 가능한 지점 존재
```

모든 기능이 완성되어 있을 필요는 없다.

중요한 기준은:

> 현재 상태를 다른 Agent 또는 다음 Session이 정확히 복원할 수 있는가?

이다.

---

# 124. Safe Checkpoint 생성 절차

개발 중 Harness 업데이트가 필요하면 먼저 다음을 수행한다.

```text
1. 현재 작업 중단 지점 결정
2. 변경 파일 목록 확보
3. 현재 Goal / Phase 기록
4. Acceptance Criteria 저장
5. 실행 가능한 검증 수행
6. 실패한 검증 별도 기록
7. DB / Migration 상태 기록
8. Git Commit 또는 복구 가능한 Snapshot 생성
9. 다음 작업 Handoff 기록
10. SAFE_CHECKPOINT 상태로 변경
```

---

# 125. Harness Update Classification

개발 중 Harness 업데이트는 다음 3단계로 분류한다.

```text
H1 — MINOR
H2 — WORKFLOW
H3 — MAJOR
```

---

# 126. H1 — Minor Harness Update

예:

```text
오탈자 수정
설명 개선
브리핑 문구 개선
Benchmark 항목 추가
비실행 Reference 문서 보강
```

특징:

```text
Runtime Logic 영향 낮음
Phase Routing 영향 없음
현재 작업 결과에 직접 영향 없음
```

적용 기준:

```text
SAFE_CHECKPOINT 권장
현재 Phase 유지 가능
간단한 Harness Validation 후 개발 재개
```

---

# 127. H2 — Workflow Harness Update

예:

```text
새로운 Phase 추가
Acceptance Gate 변경
Reviewer 정책 변경
JIT Context 변경
Model Router 변경
Token Router 변경
Verification Profile 변경
```

특징:

```text
현재 개발 Workflow에 영향 가능
다음 Phase부터 새로운 규칙 적용 권장
```

기본 절차:

```text
현재 Phase 완료
↓
SAFE_CHECKPOINT
↓
Harness Update
↓
Validation
↓
Transition Audit
↓
다음 Phase부터 신규 Workflow 적용
```

현재 진행 중 Phase에는 가능한 한 기존 규칙을 유지한다.

---

# 128. H3 — Major Harness Migration

예:

```text
Harness v5 → v6
Runtime Core 재설계
Project Mode 도입
Agent Architecture 변경
Directory Structure 대규모 변경
Phase Engine 교체
```

기본 절차:

```text
CURRENT DEVELOPMENT
        ↓
SAFE_CHECKPOINT
        ↓
FROZEN_FOR_MIGRATION
        ↓
HARNESS INVENTORY
        ↓
COMPATIBILITY ANALYSIS
        ↓
MIGRATION PLAN
        ↓
DRY RUN
        ↓
HARNESS UPDATE
        ↓
HARNESS VALIDATION
        ↓
TRANSITION AUDIT
        ↓
PROJECT REGRESSION
        ↓
RESUMING
        ↓
IN_PROGRESS
```

---

# 129. Harness Blocker Exception

현재 Harness 자체 결함 때문에 개발이 진행되지 않는 경우 예외적으로 활성 Phase 안에서도 Harness 수정이 가능하다.

이 경우:

```text
HARNESS_BLOCKER
```

로 분류한다.

필수 기록:

```text
Blocker Description
Affected Phase
Why Development Cannot Continue
Minimal Harness Fix
Expected Impact
Rollback
Verification
```

Harness Blocker 수정은 가능한 한 최소 범위로 제한한다.

---

# 130. Freeze Policy

`FROZEN_FOR_MIGRATION` 상태에서는 다음을 금지한다.

```text
새 기능 추가
대규모 Refactor
새 DB Migration
새 Dependency Upgrade
UI 기능 확장
Architecture 변경
```

허용:

```text
Harness Migration
Harness Validation
Compatibility Fix
Required Transition Fix
Regression Test
Documentation
```

목적은 Harness 전환과 Product 변경을 동시에 수행하지 않는 것이다.

---

# 131. Progressive Migration

Harness가 변경되었다고 해서 기존 개발 작업을 처음부터 다시 수행하지 않는다.

기본 원칙:

```text
COMPLETED PHASES
→ 재실행하지 않음

CURRENT PHASE
→ 상태 및 Evidence 확인

NEW CRITICAL GATES
→ 누락 여부만 추가 검사

FUTURE PHASES
→ 신규 Harness 규칙 적용
```

이 방식을 Progressive Migration으로 정의한다.

---

# 132. Transition Audit

Harness 업데이트 후 반드시 Transition Audit을 수행한다.

확인 항목:

```text
기존 완료 Phase 보존 여부
현재 Goal 유지 여부
Acceptance Criteria 유지 여부
Architecture Decision 유지 여부
현재 Test Baseline 유지 여부
새 Harness에서 추가된 Critical Gate
새 Harness와 기존 프로젝트 규칙 충돌
새로운 Required File 누락
새로운 Verification Requirement
새로운 Benchmark Requirement
새로운 Token / Model Routing 영향
```

---

# 133. Transition Audit 결과 분류

각 항목을 다음으로 분류한다.

```text
CARRY_FORWARD
- 그대로 유지 가능

ADOPT_NOW
- 즉시 적용 필요

ADOPT_NEXT_PHASE
- 다음 Phase부터 적용

DEFER
- 현재 개발에는 적용하지 않음

MIGRATION_REQUIRED
- 별도 Migration 필요

CONFLICT
- 사용자 Decision 필요
```

---

# 134. Critical Gate Backfill

새 Harness에서 추가된 모든 규칙을 과거 Phase에 소급 적용하지 않는다.

다만 아래 유형은 Release 이전에 Backfill할 수 있다.

```text
Security Review
Independent Review
Regression Baseline
Production Verification
Critical Data Validation
Rollback Check
```

예:

```text
v5에서 Phase 01~07 완료
v6에서 Independent Review 신규 도입

→ Phase 01부터 다시 개발하지 않음
→ Release 이전 전체 변경분 대상으로 Independent Review 1회 수행
```

---

# 135. Transition Manifest

개발 중 Harness Migration에서는 다음 파일 생성을 권장한다.

```text
harness/transition-manifest.yaml
```

예:

```yaml
harness_transition:
  from: 5.0.0
  to: 6.0.0

  project_mode: GREENFIELD
  development_state: SAFE_CHECKPOINT

  checkpoint:
    branch: feature/leave
    commit: abc123
    phase: 08_IMPLEMENTATION

  completed_phases:
    - discovery
    - requirements
    - architecture
    - acceptance
    - design
    - vertical_slice

  current_work:
    feature: leave-approval
    status: partial

  carry_forward:
    - architecture-decisions
    - acceptance-criteria
    - test-baseline

  new_required_gates:
    - independent-review
    - regression-baseline
    - benchmark

  deferred:
    - historical-ui-restructure

  resume_from:
    phase: 08_IMPLEMENTATION
```

---

# 136. Transition Manifest 필수 항목

```text
FROM_VERSION
TO_VERSION
PROJECT_MODE
DEVELOPMENT_STATE
CHECKPOINT
CURRENT_PHASE
COMPLETED_PHASES
CURRENT_WORK
CARRY_FORWARD
NEW_REQUIRED_GATES
DEFERRED_RULES
CONFLICTS
RESUME_FROM
```

---

# 137. Resume Validation

Harness Migration 이후 개발을 다시 시작하기 전에 다음을 확인한다.

```text
[ ] Harness Validation PASS
[ ] Transition Audit 완료
[ ] 기존 Build 상태 확인
[ ] 기존 Test Baseline 확인
[ ] Critical Regression PASS
[ ] Current Goal 복원
[ ] Current Phase 복원
[ ] Next Task 복원
[ ] 새로운 Gate 적용 시점 명확
```

통과하면:

```text
DEVELOPMENT_STATE = RESUMING
```

이후 첫 작업 성공 후:

```text
DEVELOPMENT_STATE = IN_PROGRESS
```

로 전환한다.

---

# 138. Development State Transition Rules

정상적인 전환 예:

```text
NOT_STARTED
→ IN_PROGRESS
→ SAFE_CHECKPOINT
→ IN_PROGRESS
→ STABLE
```

Harness Migration 시:

```text
IN_PROGRESS
→ SAFE_CHECKPOINT
→ FROZEN_FOR_MIGRATION
→ RESUMING
→ IN_PROGRESS
```

완료 시:

```text
IN_PROGRESS
→ SAFE_CHECKPOINT
→ STABLE
```

---

# 139. Invalid State Transition

다음을 기본 금지한다.

```text
IN_PROGRESS
→ Harness Major Migration 직접 적용

FROZEN_FOR_MIGRATION
→ 신규 Feature 개발

FAILED Harness Validation
→ RESUMING

No Rollback Point
→ Destructive Harness Migration
```

---

# 140. Active Phase Consistency Rule

하나의 Active Phase 안에서는 가능한 한 동일한 Harness Rule Set을 유지한다.

예:

```text
Phase 시작:
Harness v5 rules

Phase 중간:
v6 설치 요청

처리:
Phase Safe Checkpoint 생성
→ 현재 Phase 완료 또는 중단 상태 기록
→ Migration
→ Transition Audit
→ 이후 신규 Rule Set 적용
```

하나의 구현 단위 안에서:

```text
v5 → v6 → v5 → v6
```

처럼 기준이 반복 변경되지 않도록 한다.

---

# 141. In-Progress Project Token Policy

개발 중 Harness Migration에서는 전체 Repository를 다시 읽는 것을 기본값으로 하지 않는다.

Context 우선순위:

```text
Transition Manifest
↓
Current Goal
↓
Current Phase
↓
Architecture Decisions
↓
Acceptance Criteria
↓
Affected Files
↓
Test Baseline
↓
필요한 경우에만 Wider Repository Context
```

---

# 142. Migration Context Preservation

Harness Migration 전에 반드시 보존한다.

```text
Current Goal
Current Phase
Current Decisions
Acceptance Criteria
Known Risks
Known Failures
Test Evidence
Changed Files
Next Task
User Decisions
```

긴 Raw Log 전체를 보존할 필요는 없다.

핵심 상태를 구조화해서 저장한다.

---

# 143. Development State Beginner Briefing

개발 중 Harness 업데이트 요청 시 초보자에게 다음처럼 안내한다.

```text
현재 프로젝트는 개발 진행 중입니다.

Harness 업데이트는 가능하지만,
현재 기능 구현 도중 즉시 규칙을 교체하면
기존 기준과 새 기준이 섞일 수 있습니다.

먼저 현재 작업을 안전한 Checkpoint로 저장한 뒤
Harness를 업데이트하겠습니다.

기존 완료 작업을 처음부터 다시 만들지는 않습니다.

새 Harness에서 새롭게 필수가 된 검증 항목만 확인하고,
이후 작업부터 새 Workflow를 적용합니다.
```

---

# 144. Harness Update Decision Briefing

다음 정보를 제공한다.

```text
현재 Harness Version
목표 Harness Version
현재 Development State
현재 Phase
현재 작업 완료도
업데이트 분류 H1 / H2 / H3
지금 업데이트할 경우 영향
현재 Phase 종료 후 적용할 경우 영향
추천 적용 시점
Rollback 가능 여부
```

---

# 145. Harness Update Timing Recommendation

기본 우선순위:

```text
가장 좋음
- Milestone 종료 직후
- Phase PASS 직후
- Release 직후 다음 개발 시작 전
- 명시적 SAFE_CHECKPOINT

허용
- 기능 단위 중간이지만 복원 가능한 Checkpoint

주의
- Test 실패 원인이 불명확한 상태
- DB Migration 진행 중
- Merge Conflict 진행 중
- 대규모 Refactor 중

기본 금지
- Production Deployment 실행 중
- Destructive Migration 실행 중
- 데이터 변환 진행 중
- 긴급 장애 복구 중 Harness와 Product를 동시에 변경
```

---

# 146. Harness Update Deferred State

지금 업데이트하지 않는 것이 더 안전하면 다음처럼 기록한다.

```text
HARNESS_UPDATE = DEFERRED
TARGET_CHECKPOINT = <phase/milestone>
REASON = <reason>
```

사용자가 업데이트 요청을 잊지 않도록 다음 Checkpoint에서 다시 안내한다.

---

# 147. Hotfix 중 Harness Update

HOTFIX 상태에서는 일반적으로 Harness major update를 함께 수행하지 않는다.

기본:

```text
HOTFIX
→ 서비스 복구
→ Critical Regression
→ Stable Checkpoint
→ Harness Migration
```

예외:

```text
현재 Harness 결함 때문에 Hotfix 수행 자체가 불가능
```

이 경우에만 `HARNESS_BLOCKER`로 최소 수정한다.

---

# 148. Migration 중 Product Feature 변경 금지

Harness Migration과 Product Feature 개발을 동일 Patch에 혼합하지 않는다.

좋은 예:

```text
Commit A
Harness v5 → v6 Migration

Commit B
Feature Development Resume
```

나쁜 예:

```text
Commit A
Harness v6 Migration
+ DB 기능 추가
+ UI 수정
+ API Refactor
```

원인 추적과 Rollback을 어렵게 만들기 때문이다.

---

# 149. Transition Benchmark

Harness 전환 자체도 Benchmark 대상이다.

측정:

```text
Migration Token Usage
Migration Wall Time
Files Changed
Rules Reused
Rules Replaced
Conflicts Found
Manual Decisions
Regression Failures
Transition Repair Count
Resume Success
```

---

# 150. In-Progress Migration Success Metrics

```text
Development Work Lost = 0
Completed Phase Rework 최소화
Regression 발생 없음
User Decisions 보존
Current Goal 보존
Resume 성공
Token 재탐색 최소화
```

---

# 151. Transition Failure Conditions

다음 중 하나라도 발생하면 Migration 완료로 선언하지 않는다.

```text
현재 Goal 유실
현재 Phase 식별 불가
기존 Acceptance Criteria 유실
Test Baseline 유실
Custom Project Rule 유실
Build 실패 원인 미확인
Critical Regression 발생
Rollback 불가
Transition Manifest 불완전
```

---

# 152. Runtime Router 최종 확장

기존 Runtime Routing을 다음으로 확장한다.

```text
USER REQUEST
      ↓
PROJECT MODE
      ↓
DEVELOPMENT STATE
      ↓
CHANGE TYPE
      ↓
HARNESS UPDATE CLASS
      ↓
RISK LEVEL
      ↓
SAFE CHECKPOINT?
      ↓
BEGINNER / EXPERT
      ↓
PHASE WORKFLOW
      ↓
JIT CONTEXT
      ↓
MODEL / REASONING ROUTER
      ↓
IMPLEMENT
      ↓
VERIFY
      ↓
REVIEW
      ↓
EVIDENCE
```

---

# 153. Runtime 신규 파일 권장

추가 권장:

```text
harness/runtime/development-state.md
harness/runtime/checkpoint-policy.md
harness/runtime/harness-update-router.md
harness/runtime/transition-audit.md
```

역할:

```text
development-state.md
- 상태 정의 및 전환

checkpoint-policy.md
- Safe Checkpoint 조건

harness-update-router.md
- H1 / H2 / H3 분류 및 적용 시점

transition-audit.md
- Migration 후 Carry Forward / Backfill / Resume 판단
```

---

# 154. 최종 Definition of Done 추가

v6.0 최종 완료 조건에 다음을 추가한다.

```text
[ ] Development State 구현
[ ] Safe Checkpoint 구현
[ ] Active Phase Consistency Rule 구현
[ ] Harness Update H1/H2/H3 분류 구현
[ ] Harness Blocker Exception 구현
[ ] Freeze Policy 구현
[ ] Progressive Migration 구현
[ ] Transition Audit 구현
[ ] Transition Manifest 지원
[ ] Critical Gate Backfill 구현
[ ] Resume Validation 구현
[ ] Invalid State Transition 차단
[ ] In-progress Token Policy 구현
[ ] Harness Update Timing Guide 구현
[ ] Deferred Update 처리 구현
[ ] Hotfix + Harness Update 충돌 방지
[ ] Transition Benchmark 구현
```

---

# 155. Harness Validation 시나리오 추가

기존 시나리오에 다음을 추가한다.

```text
Scenario I
GREENFIELD 개발 중 v5 → v6 Harness Migration

Scenario J
MAINTENANCE 기능 개발 중 Workflow Update

Scenario K
활성 DB Migration 중 Harness Update 요청

Scenario L
HOTFIX 진행 중 Harness Major Update 요청

Scenario M
Harness Blocker로 인해 현재 Phase 진행 불가

Scenario N
Phase 중간 Safe Checkpoint 후 Migration 및 Resume
```

검증:

```text
올바른 업데이트 시점 판단
Safe Checkpoint 생성
현재 작업 보존
기존 완료 Phase 재작업 방지
새 Critical Gate Backfill
Transition Manifest 생성
Regression PASS
Resume 성공
```

---

# 156. 최종 운영 원칙

AI Harness v6.0은 다음 질문에 항상 답할 수 있어야 한다.

```text
현재 이 프로젝트는 어떤 Mode인가?
현재 개발 상태는 무엇인가?
지금 Harness를 업데이트해도 안전한가?
어느 Checkpoint에서 업데이트해야 하는가?
기존 완료 작업 중 무엇을 유지할 것인가?
새 Harness 규칙 중 무엇을 즉시 적용할 것인가?
무엇을 다음 Phase로 미룰 것인가?
업데이트 후 어떻게 원래 개발로 복귀할 것인가?
```

이 질문에 답할 수 없는 상태에서는 Harness Major Migration을 시작하지 않는다.

---

# 157. 최종 목표 보강

AI Harness v6.0의 목표는 Harness 자체가 프로젝트 진행을 방해하지 않도록 하는 것이다.

Harness는 다음을 만족해야 한다.

```text
개발 전
→ 올바른 Workflow를 선택

개발 중
→ 진행 상태를 보호

업데이트 시
→ 안전한 Checkpoint에서 전환

업데이트 후
→ 기존 상태를 복원

배포 전
→ 필요한 검증 강제

배포 후
→ 실제 운영 상태 확인

프로젝트 종료 후
→ Benchmark와 Retrospective로 Harness 개선
```

Harness는 개발을 통제하되 개발 흐름을 불필요하게 초기화하거나 반복하게 만들어서는 안 된다.

---

# 158. Codex 최종 실행 지시 보강

AI Harness v6.0 업그레이드 시 반드시 다음 Runtime Capability를 구현하라.

```text
PROJECT_MODE_ROUTER
DEVELOPMENT_STATE_ROUTER
HARNESS_UPDATE_ROUTER
SAFE_CHECKPOINT
TRANSITION_MANIFEST
TRANSITION_AUDIT
PROGRESSIVE_MIGRATION
CRITICAL_GATE_BACKFILL
RESUME_VALIDATION
BEGINNER_BRIEFING
TOKEN_ROUTER
MODEL_ROUTER
VERIFICATION_PROFILE
BENCHMARK
```

Harness v6.0은 신규 프로젝트뿐 아니라 다음 상황에서 실제로 동작해야 한다.

```text
신규 개발
개발 진행 중
기존 프로젝트 패치
긴급 장애
대규모 Migration
Harness 자체 Upgrade
Harness Upgrade 이후 개발 Resume
```

Evidence 없이 완료를 선언하지 말라.

---

# 159. GitHub Harness as Source of Truth

AI Harness v6.0의 최종 배포 기준은 GitHub의 공식 Harness 저장소다.

GitHub 저장소의 v6.0은 단순한 문서 집합이 아니라 다른 프로젝트가 설치 / 업그레이드 / 복구 시 참조하는 **Source of Truth**로 동작해야 한다.

따라서 v6.0 저장소에는 다음 정보가 반드시 존재해야 한다.

```text
Harness Version
Schema Version
Runtime Capability
Project Mode Router
Development State Router
Harness Update Router
Risk Router
Checkpoint Policy
Transition Protocol
Compatibility Rules
Token Policy
Model / Reasoning Router
Verification Profiles
Benchmark Schema
Migration Rules
Beginner Guidance
```

---

# 160. Harness Install / Update Intent

사용자가 다음과 같은 표현을 사용하면 별도의 일반 파일 수정 요청으로 취급하지 않는다.

```text
하네스 설치해줘
Harness 설치
AI Harness 적용
Harness 업데이트
Harness 최신버전 적용
v6.0으로 업데이트
하네스 버전 올려줘
Harness migration
```

위 요청은 모두 우선적으로 다음 Intent 후보로 분류한다.

```text
HARNESS_INSTALL
HARNESS_UPDATE
HARNESS_MIGRATION
```

그리고 현재 Repository 상태를 조사하여 최종 Intent를 결정한다.

---

# 161. Install Request Reclassification

사용자가 "설치"라고 표현했다고 해서 항상 신규 설치를 수행하지 않는다.

Repository 조사 결과 기존 프로젝트 또는 기존 Harness가 확인되면 자동으로 Migration 여부를 판단한다.

예:

```text
USER:
AI Harness v6.0 설치해줘

DETECTED:
- Existing application
- Existing production data
- Existing Harness v5
- Active development

RESULT:
HARNESS_INSTALL
→ HARNESS_MIGRATION으로 재분류
```

사용자에게는 다음처럼 브리핑한다.

```text
기존 프로젝트와 기존 Harness가 확인되었습니다.

신규 설치 방식으로 덮어쓰면 현재 규칙과 개발 상태를 손상시킬 수 있으므로 안전한 Migration 절차로 전환합니다.

현재 상태와 Checkpoint를 먼저 확인하겠습니다.
```

---

# 162. Harness Update Must Be Self-Contained

v6.0의 핵심 요구사항:

> 다른 프로젝트의 사용자가 Update Protocol 전체를 Prompt로 다시 작성할 필요가 없어야 한다.

다른 프로젝트에서 사용자가:

```text
이 프로젝트의 AI Harness를 v6.0으로 업데이트해줘.
```

라고만 요청해도 Harness가 자동으로 다음을 수행해야 한다.

```text
VERSION DETECTION
↓
PROJECT MODE
↓
DEVELOPMENT STATE
↓
UPDATE CLASS H1/H2/H3
↓
RISK LEVEL
↓
SAFE CHECKPOINT
↓
CUSTOM RULE / SKILL INVENTORY
↓
COMPATIBILITY ANALYSIS
↓
TRANSITION MANIFEST
↓
PROGRESSIVE MIGRATION
↓
HARNESS VALIDATION
↓
PROJECT REGRESSION
↓
CRITICAL GATE BACKFILL
↓
TRANSITION AUDIT
↓
RESUME VALIDATION
↓
BENCHMARK
```

이 흐름은 사용자의 추가 Prompt에 의존하지 않는다.

---

# 163. Harness Update Router — 필수 Runtime Capability

다음 Runtime 파일 또는 동등한 기능을 반드시 구현한다.

```text
harness/runtime/harness-update-router.md
```

책임:

```text
1. Install / Update / Migration Intent 탐지
2. 기존 Harness Version 확인
3. Target Harness Version 확인
4. Project Mode 확인
5. Development State 확인
6. Update Class H1/H2/H3 분류
7. Risk Level 분류
8. Safe Checkpoint 필요 여부 결정
9. Migration Workflow 선택
10. Verification Profile 선택
11. Token Profile 선택
12. Transition Audit 호출
13. Resume Validation 호출
```

---

# 164. Update Router Decision Flow

```text
Harness 요청 감지
      ↓
기존 Harness 존재?
      │
      ├─ NO
      │   ↓
      │ 신규 프로젝트?
      │   ├─ YES → INSTALL
      │   └─ NO  → EXISTING PROJECT ADOPTION
      │
      └─ YES
          ↓
      Version 동일?
          │
          ├─ YES → Repair / Reconcile 필요 여부 판단
          └─ NO  → UPGRADE / MIGRATION
```

---

# 165. Existing Project Adoption Mode

기존 프로젝트에 Harness가 없지만 코드와 운영 이력이 존재하는 경우 신규 Greenfield 설치처럼 처리하지 않는다.

다음 Mode를 사용한다.

```text
EXISTING_PROJECT_ADOPTION
```

절차:

```text
Repository Inventory
↓
Current Architecture Summary
↓
Build / Test Baseline
↓
Operational Constraints
↓
Project-specific Rules
↓
Harness Compatibility
↓
Minimal Harness Installation
↓
Validation
↓
No Retroactive Refactor
```

기존 코드 전체를 새 Harness 규칙으로 자동 재작성하지 않는다.

---

# 166. Version Detection

가능하면 프로젝트마다 명시적인 Version 정보를 유지한다.

최소:

```text
HARNESS_VERSION
```

권장:

```text
harness/manifest.yaml
```

예:

```yaml
harness:
  name: ai-harness
  version: 6.0.0
  schema_version: 3

capabilities:
  project_mode_router: true
  development_state_router: true
  beginner_mode: true
  safe_checkpoint: true
  transition_manifest: true
  benchmark: true
  token_router: true
  model_router: true
  verification_profiles: true

compatibility:
  migration_supported_from:
    - "4.x"
    - "5.x"
```

---

# 167. Manifest as Machine-Readable Contract

`harness/manifest.yaml`은 단순 버전 표시가 아니다.

AI가 빠르게 다음을 판단할 수 있는 Machine-Readable Contract로 사용한다.

```text
Current Harness Version
Schema Version
Enabled Capabilities
Required Runtime Files
Supported Migration Sources
Required Project Files
Benchmark Schema
Compatibility Level
```

이를 통해 불필요한 문서 전체 재독을 줄인다.

---

# 168. GitHub v6 Required Update Directory

다음 구조 또는 동등한 구조를 권장한다.

```text
harness/
├─ update/
│  ├─ UPDATE_PROTOCOL.md
│  ├─ VERSION_DETECTION.md
│  ├─ COMPATIBILITY_RULES.md
│  ├─ TRANSITION_PROTOCOL.md
│  ├─ ADOPTION_PROTOCOL.md
│  └─ ROLLBACK_PROTOCOL.md
```

책임:

```text
UPDATE_PROTOCOL.md
- 전체 Update Lifecycle

VERSION_DETECTION.md
- 현재 / 목표 Version 판단

COMPATIBILITY_RULES.md
- 기존 Project / Custom Rule 호환성

TRANSITION_PROTOCOL.md
- 개발 중 Migration

ADOPTION_PROTOCOL.md
- 기존 프로젝트에 Harness 최초 적용

ROLLBACK_PROTOCOL.md
- Harness Update 실패 시 복구
```

---

# 169. AGENTS.md Mandatory Upgrade Invariant

GitHub v6.0의 `AGENTS.md`에는 다음 의미의 규칙을 반드시 포함한다.

```text
HARNESS UPGRADE INVARIANT

사용자가 Harness 설치 / 업데이트 / 업그레이드 / 버전 변경 / 최신 Harness 적용을 요청하면 파일을 즉시 덮어쓰지 않는다.

반드시:

1. Current Harness Version
2. Target Harness Version
3. Project Mode
4. Development State
5. Existing Custom Rule / Skill / Policy
6. Safe Checkpoint
7. Compatibility / Gap Analysis
8. Transition Manifest
9. Migration
10. Harness Validation
11. Regression Verification
12. Critical Gate Backfill
13. Transition Audit
14. Resume Validation
15. Benchmark

절차를 따른다.

ACTIVE IMPLEMENTATION PHASE에서 Major Harness Update를 직접 적용하지 않는다.

기존 Project Rule을 명시적 Migration Decision 없이 삭제하거나 전체 코드에 소급 적용하지 않는다.
```

AGENTS.md는 세부 Migration 문서를 전부 포함하지 않고 관련 Runtime / Update Protocol로 Routing해야 한다.

---

# 170. PROJECT_INIT Harness Detection

프로젝트 진입 시 다음을 확인하도록 한다.

```text
Harness installed?
Harness version?
Manifest exists?
Project type?
Project mode?
Development state?
Existing transition in progress?
Pending Harness update?
```

상태 예:

```text
HARNESS_VERSION_MISMATCH
HARNESS_MIGRATION_IN_PROGRESS
HARNESS_UPDATE_DEFERRED
HARNESS_REPAIR_REQUIRED
HARNESS_CURRENT
```

---

# 171. No Silent Harness Update

Harness 버전이 다르다고 자동으로 파일을 교체하지 않는다.

Harness는:

```text
Detect
→ Analyze
→ Brief
→ Migrate Safely
```

순서로 동작한다.

단순 문서 Patch 수준의 H1 변경은 정책에 따라 간소화할 수 있다.

---

# 172. GitHub Harness Upgrade First Principle

v6.0 도입 순서는 다음을 기본으로 한다.

```text
1. GitHub Source Harness를 v6.0으로 완성
2. GitHub v6.0 자체 Validation
3. GitHub v6.0 Benchmark
4. Version Tag / Release 준비
5. 다른 프로젝트에 v6.0 적용
```

다른 프로젝트마다 별도의 임시 v6 구현을 먼저 만들지 않는다.

GitHub의 공식 v6.0이 기준이 되어야 한다.

---

# 173. GitHub v5 → v6 Upgrade Procedure

현재 GitHub Harness 저장소를 v6.0으로 업데이트할 때:

```text
CURRENT HARNESS INVENTORY
↓
CUSTOM RULE INVENTORY
↓
RUNTIME INVENTORY
↓
SKILL INVENTORY
↓
JIT / TOKEN POLICY INVENTORY
↓
BENCHMARK BASELINE
↓
V6 GAP ANALYSIS
↓
COMPATIBILITY ANALYSIS
↓
FILE-BY-FILE MIGRATION PLAN
↓
SAFE CHECKPOINT
↓
IMPLEMENTATION
↓
HARNESS VALIDATION
↓
BEGINNER SIMULATION
↓
GREENFIELD FLOW TEST
↓
MAINTENANCE FLOW TEST
↓
HOTFIX FLOW TEST
↓
MIGRATION FLOW TEST
↓
ACTIVE DEVELOPMENT MIGRATION TEST
↓
BENCHMARK
↓
PATCH_NOTES
↓
MIGRATION_NOTES
↓
CHANGELOG
```

---

# 174. GitHub Upgrade Must Reuse Existing Good Parts

현재 GitHub Harness에 이미 구현된 다음 요소는 동일 기능을 새로 만들기 전에 반드시 재사용 가능성을 검토한다.

```text
Runtime Core
JIT Policy
Existing Skills
Build Log
Project Init
Existing Agent Routing
Existing Model Routing
Existing Verification
Existing Benchmark
Existing Patch Notes
```

분류:

```text
KEEP
EXTEND
MERGE
REPLACE
DEPRECATE
```

---

# 175. File-by-File Migration Plan

GitHub v6 구현 전에 파일 단위 계획을 만든다.

표준:

```text
FILE
CURRENT ROLE
V6 ROLE
ACTION
RISK
DEPENDENCIES
VERIFICATION
```

---

# 176. GitHub v6 Validation — Structural

다음을 검사한다.

```text
Missing References
Broken Links
Duplicate Rules
Conflicting Rules
Circular Routing
Dead Routing
Missing Required Runtime File
Manifest Mismatch
Version Mismatch
Phase Deadlock
State Deadlock
Update Router Deadlock
Decision Gate Deadlock
```

---

# 177. GitHub v6 Validation — Behavioral

최소 다음 요청을 실제 시뮬레이션한다.

```text
"새 프로젝트 시작해줘"
"기존 프로젝트에 Harness 설치해줘"
"현재 Harness를 v6으로 업데이트해줘"
"개발 중인데 Harness 최신버전 적용해줘"
"운영 장애가 발생했어"
"DB 구조를 바꿔야 해"
"Framework major version 올려줘"
```

각 요청에서 올바른 Router가 선택되는지 확인한다.

---

# 178. One-Line Update User Experience

v6.0 성공 기준 중 하나:

다른 프로젝트에서 아래 요청만으로 충분해야 한다.

```text
이 프로젝트의 AI Harness를 v6.0으로 업데이트해줘.
```

사용자가 다음을 직접 적을 필요가 없어야 한다.

```text
Safe Checkpoint 만들어라
Project Mode 판별해라
Development State 판별해라
Transition Manifest 만들어라
Regression 해라
Benchmark 해라
Resume 해라
```

이 절차는 Harness 내부 규칙이다.

---

# 179. One-Line Install User Experience

신규 프로젝트:

```text
AI Harness v6.0 설치해줘.
```

자동 흐름:

```text
Environment Diagnosis
↓
Project Detection
↓
GREENFIELD
↓
Beginner Mode
↓
Project Init
```

기존 프로젝트:

```text
AI Harness v6.0 설치해줘.
```

자동 흐름:

```text
Existing Project Detection
↓
EXISTING_PROJECT_ADOPTION or MIGRATION
↓
Baseline
↓
Compatibility
↓
Safe Installation
↓
Validation
```

---

# 180. Beginner Guidance Must Survive Updates

Harness 업데이트 이후에도 Beginner Mode가 초기화되거나 사라지면 안 된다.

Migration 시 다음을 Carry Forward한다.

```text
Beginner / Expert Preference
Project Mode
Current Development State
User Decisions
Current Goal
Current Phase
Known Constraints
Deployment Target
```

---

# 181. Update Protocol Token Policy

Harness 업데이트는 자체적으로 Token 최적화 대상이다.

Context 순서:

```text
manifest.yaml
↓
HARNESS_VERSION
↓
Transition Manifest if exists
↓
AGENTS Router
↓
Relevant Update Protocol
↓
Current Project Summary
↓
Affected Custom Rules
↓
Needed Runtime Files
```

모든 Harness 문서를 처음부터 전체 로드하지 않는다.

---

# 182. Update Protocol Model Routing

예:

```text
Version Detection
→ FAST / LOW

Inventory
→ FAST or BALANCED / LOW-MEDIUM

Compatibility
→ BALANCED or STRONG / MEDIUM-HIGH

Migration Planning
→ STRONG / HIGH

Mechanical File Migration
→ BALANCED / MEDIUM

Independent Review
→ STRONG / HIGH

Benchmark Analysis
→ BALANCED / MEDIUM
```

---

# 183. Source-of-Truth Integrity

다른 프로젝트의 Local Harness가 GitHub Source와 다를 수 있다.

따라서 Update 시:

```text
UPSTREAM VERSION
LOCAL VERSION
LOCAL CUSTOMIZATION
```

을 분리한다.

Local customization을 무조건 upstream으로 덮어쓰지 않는다.

---

# 184. Local Customization Preservation

다음은 별도 확인 없이 삭제하지 않는다.

```text
Project-specific Rules
Domain-specific Skills
Custom Verification Commands
Custom Deployment Rules
Security Constraints
Company Policies
Local Model Routing Overrides
```

각 항목을:

```text
UPSTREAM
LOCAL
MERGED
CONFLICT
```

로 분류한다.

---

# 185. Three-Way Harness Merge Concept

가능하면 Harness 업데이트는 다음 개념으로 처리한다.

```text
OLD UPSTREAM
      +
LOCAL CUSTOMIZATION
      +
NEW UPSTREAM
      ↓
MERGED HARNESS
```

단순:

```text
NEW UPSTREAM
→ overwrite LOCAL
```

방식을 기본값으로 사용하지 않는다.

---

# 186. Harness Conflict Decision Gate

다음 상황에서는 사용자에게 질문한다.

```text
새 v6 규칙과 회사 정책 충돌
새 Token 정책과 Local 강제 모델 정책 충돌
새 Phase Gate가 기존 배포 프로세스와 충돌
기존 Custom Skill이 v6 Runtime과 충돌
```

브리핑:

```text
충돌 내용
기존 동작
v6 동작
선택지
각 선택의 영향
추천 방향
Rollback
```

---

# 187. Update Rollback

Harness Migration 실패 시 Product Code와 Harness 상태를 분리하여 복구할 수 있어야 한다.

기본:

```text
HARNESS MIGRATION FAIL
↓
STOP PRODUCT FEATURE CHANGE
↓
RESTORE HARNESS CHECKPOINT
↓
RESTORE MANIFEST
↓
VERIFY PROJECT BUILD
↓
VERIFY CRITICAL TEST
↓
REPORT FAILURE
```

Harness Update 실패를 Product Rollback과 혼동하지 않는다.

---

# 188. Version Tagging Recommendation

GitHub Source Harness는 가능하면 명확한 Release Tag를 사용한다.

```text
v6.0.0
v6.0.1
v6.1.0
```

Semantic Version 의미:

```text
PATCH
- 문서 / 작은 Runtime Fix

MINOR
- Backward-compatible capability 추가

MAJOR
- Migration이 필요한 Runtime / Workflow 변경
```

---

# 189. Compatibility Declaration

Release마다 가능한 경우 다음 정보를 제공한다.

```text
SUPPORTED_FROM
KNOWN_CONFLICTS
MIGRATION_REQUIRED
MIGRATION_OPTIONAL
DEPRECATED
REMOVED
```

---

# 190. Harness Release Evidence

GitHub v6.0을 완료로 선언하기 전에 최소 다음 Evidence를 남긴다.

```text
Structural Validation
Behavioral Validation
Beginner Simulation
Greenfield Test
Maintenance Test
Hotfix Test
Migration Test
Active Development Migration Test
Update Router Test
Transition Audit Test
Benchmark Result
Known Limitations
```

---

# 191. GitHub v6 Benchmark Baseline

가능하면 v5와 v6을 동일 대표 Task로 비교한다.

필수 지표:

```text
Task Success
First Pass Success
Token Usage
Wall Time
Tool Calls
Retry
Human Intervention
Regression
Reviewer Findings
Beginner Completion
Harness Migration Success
Resume Success
```

---

# 192. Upgrade Automation Success Criteria

다른 프로젝트에서 Harness 업데이트를 수행했을 때 다음을 성공 기준으로 한다.

```text
[ ] 사용자 한 줄 요청으로 Update Router 작동
[ ] 현재 Version 탐지
[ ] 현재 Project Mode 탐지
[ ] Development State 탐지
[ ] Safe Checkpoint 판단
[ ] Local Customization 보존
[ ] Migration Plan 생성
[ ] Transition Manifest 생성
[ ] Migration 성공
[ ] Regression PASS
[ ] Resume 성공
[ ] Benchmark 기록
[ ] 기존 Product 기능 손상 없음
```

---

# 193. Existing Project Adoption Success Criteria

기존 프로젝트에 Harness를 처음 적용할 때:

```text
[ ] 기존 Code를 Greenfield로 오판하지 않음
[ ] 기존 Build / Test Baseline 확보
[ ] Existing Architecture 존중
[ ] 전체 코드 소급 Refactor 없음
[ ] Project-specific Rule 보존
[ ] Beginner Guide 활성
[ ] Future Maintenance Workflow 준비
```

---

# 194. GitHub v6 Mandatory Files — 권장 최소 세트

실제 기존 구조를 존중하되 다음 Capability가 파일 또는 동등한 Runtime 구조로 존재해야 한다.

```text
HARNESS_VERSION
harness/manifest.yaml

harness/runtime/
- project-mode-router.md
- development-state.md
- harness-update-router.md
- checkpoint-policy.md
- transition-audit.md
- token-policy.md
- model-router.md
- verification-profiles.md

harness/update/
- UPDATE_PROTOCOL.md
- VERSION_DETECTION.md
- COMPATIBILITY_RULES.md
- TRANSITION_PROTOCOL.md
- ADOPTION_PROTOCOL.md
- ROLLBACK_PROTOCOL.md

harness/benchmark/
- benchmark-schema.md
- baseline/
- cases/
- results/
```

---

# 195. README Required User Commands

README에는 초보자가 사용할 수 있는 대표 요청 예시를 짧게 제공한다.

```text
신규 프로젝트:
"AI Harness v6.0 기준으로 이 프로젝트를 시작해줘."

기존 프로젝트 최초 적용:
"이 프로젝트에 AI Harness v6.0을 적용해줘."

기존 Harness 업데이트:
"이 프로젝트의 AI Harness를 v6.0으로 업데이트해줘."

개발 중 Harness 업데이트:
"현재 개발 상태를 보존하면서 AI Harness를 v6.0으로 업데이트해줘."
```

단, 마지막 문구를 반드시 사용해야 하는 구조로 만들지 않는다.

일반적인 "업데이트해줘" 요청만으로도 동일 안전 절차가 작동해야 한다.

---

# 196. GitHub v6 Final Upgrade Instruction

이 문서를 GitHub의 현재 AI Harness 저장소에 제공받은 Agent는 다음 순서로 작업한다.

```text
1. 이 문서를 전체 실행 요구사항으로 읽는다.
2. 현재 GitHub Harness Repository를 조사한다.
3. Inventory를 작성한다.
4. 현재 Project / Development State를 판단한다.
5. Safe Checkpoint 필요 여부를 확인한다.
6. v5 → v6 Gap Analysis를 작성한다.
7. 기존 기능을 KEEP / EXTEND / MERGE / REPLACE / DEPRECATE로 분류한다.
8. File-by-File Migration Plan을 작성한다.
9. v6 Runtime Capability를 구현한다.
10. Harness Update Protocol을 Harness 자체에 내장한다.
11. Manifest / Version Detection을 구현한다.
12. Existing Project Adoption Flow를 구현한다.
13. Local Customization Preservation을 구현한다.
14. Transition / Rollback Flow를 구현한다.
15. Beginner Mode가 모든 Mode에서 동작하도록 한다.
16. Token / JIT / Model Routing을 연결한다.
17. Verification / Evidence / Benchmark를 연결한다.
18. 대표 시나리오를 검증한다.
19. README / PATCH_NOTES / MIGRATION_NOTES / CHANGELOG를 갱신한다.
20. Evidence를 포함한 최종 보고를 작성한다.
```

---

# 197. Critical Final Requirement

v6.0의 핵심은 이 Upgrade 문서가 있어야만 안전하게 동작하는 것이 아니다.

이 문서는 **GitHub Source Harness를 v6.0으로 만드는 Bootstrap Instruction**이다.

v6.0 구현이 완료된 이후에는 다른 프로젝트에서 이 문서를 다시 전달하지 않아도 된다.

다른 프로젝트의 사용자는 단순히:

```text
AI Harness v6.0으로 업데이트해줘.
```

라고 요청할 수 있어야 한다.

그러면 GitHub v6.0 Harness에 내장된 Runtime / Update Protocol이 이 문서에서 정의한 안전 절차를 자동으로 적용해야 한다.

---

# 198. Final v6 Architecture

```text
                    GITHUB AI HARNESS v6.0
                            │
                            │ Source of Truth
                            ▼
                    HARNESS MANIFEST
                            │
                            ▼
                     INTENT ROUTER
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
           INSTALL        UPDATE       MIGRATION
              │             │             │
              └───────┬─────┴─────┬───────┘
                      ▼           ▼
                PROJECT MODE   DEVELOPMENT STATE
                      │           │
                      └─────┬─────┘
                            ▼
                         RISK
                            ▼
                    SAFE CHECKPOINT
                            ▼
                    COMPATIBILITY
                            ▼
                    TRANSITION PLAN
                            ▼
                         APPLY
                            ▼
                         VERIFY
                            ▼
                         REVIEW
                            ▼
                        BENCHMARK
                            ▼
                         RESUME
```

---

# 199. Final Definition of Done V3

AI Harness v6.0은 다음 조건을 만족해야 최종 완료다.

```text
CORE
[ ] Full SDLC Phase Engine
[ ] Project Mode Router
[ ] Development State Router
[ ] Beginner Mode
[ ] Decision Gate
[ ] Risk Router
[ ] Acceptance-first
[ ] Vertical Slice
[ ] Independent Review
[ ] Evidence Completion

EFFICIENCY
[ ] JIT Context
[ ] Token Policy
[ ] Context Compaction
[ ] Model Router
[ ] Reasoning Router
[ ] Worker Handoff

EXISTING PROJECT
[ ] Maintenance Workflow
[ ] Regression Gate
[ ] Minimum Necessary Change
[ ] Existing Behavior Contract
[ ] No Retroactive Rule
[ ] Existing Project Adoption

MIGRATION
[ ] Safe Checkpoint
[ ] Harness Update H1/H2/H3
[ ] Transition Manifest
[ ] Transition Audit
[ ] Progressive Migration
[ ] Critical Gate Backfill
[ ] Resume Validation
[ ] Rollback Protocol

SOURCE OF TRUTH
[ ] HARNESS_VERSION
[ ] Machine-readable Manifest
[ ] Harness Update Intent
[ ] Update Router
[ ] Version Detection
[ ] Compatibility Rules
[ ] Local Customization Preservation
[ ] GitHub v6 Source-of-Truth operation

VALIDATION
[ ] Structural Validation
[ ] Behavioral Validation
[ ] Beginner Simulation
[ ] Greenfield Scenario
[ ] Maintenance Scenario
[ ] Hotfix Scenario
[ ] Migration Scenario
[ ] Active Development Migration Scenario
[ ] Existing Project Adoption Scenario
[ ] One-line Harness Update Scenario

BENCHMARK
[ ] v5 Baseline
[ ] v6 Result
[ ] Token Measurement
[ ] Time Measurement
[ ] Retry Measurement
[ ] Human Intervention Measurement
[ ] Regression Measurement
[ ] Beginner Success Measurement
[ ] Migration / Resume Measurement

DOCUMENTATION
[ ] README
[ ] PATCH_NOTES
[ ] MIGRATION_NOTES
[ ] CHANGELOG
[ ] Known Limitations
```

---

# 200. Codex에게 주는 최종 V3 실행 명령

이 문서는 AI Harness v6.0의 최종 Bootstrap / Upgrade Specification이다.

현재 GitHub AI Harness Repository를 본 문서의 요구사항에 맞게 v6.0으로 실제 업데이트하라.

단순 문서 복사나 규칙 추가로 끝내지 말고 Harness Runtime 자체가 향후 다른 프로젝트에서 설치 / 업데이트 / Migration 요청을 자동으로 안전 처리하도록 구현하라.

특히 사용자가 다른 프로젝트에서 단순히:

```text
AI Harness v6.0으로 업데이트해줘.
```

라고 요청하는 것만으로 다음이 자동 실행되어야 한다.

```text
Version Detection
Project Mode
Development State
Update Class
Risk
Safe Checkpoint
Local Customization Inventory
Compatibility Analysis
Transition Manifest
Progressive Migration
Harness Validation
Regression
Critical Gate Backfill
Transition Audit
Resume Validation
Benchmark
```

사용자가 이 절차를 매번 Prompt에 다시 작성해야 하는 구조는 v6.0 완료로 인정하지 않는다.

현재 GitHub Harness의 좋은 기능과 Custom Rule은 최대한 재사용하라.

먼저 Inventory / Gap Analysis / File-by-File Migration Plan을 작성한 뒤 구현을 시작하고, 각 주요 단계에서 Beginner-friendly Briefing을 제공하라.

중대한 선택에는 장점 / 단점 / 위험 / 장기 영향 / 추천 방향을 설명한 뒤 사용자 Decision Gate를 적용하라.

실제 검증 Evidence와 Benchmark 없이 AI Harness v6.0 완료를 선언하지 말라.
