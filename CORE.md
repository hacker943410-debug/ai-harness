# AI Harness CORE

Document Version: 1.1
Harness Version Source: `POLICY_INDEX.yaml`의 `harness_version`
Purpose: 모든 CLI 작업에서 항상 유지할 최소 공통 계약.
Scope: 상세 규칙을 대신하지 않는다. 상세 내용은 ROUTER가 선택한 정책 원문이 소유한다.

## 1. 최상위 실행 원칙

1. 적용 가능한 플랫폼/시스템 제약을 항상 지킨다.
2. 현재 사용자의 명시적 목표·금지사항·성공조건을 보존한다.
3. 실제 코드·테스트·실행 결과가 추측이나 오래된 문서보다 우선한다.
4. 현재 목표를 만족하는 가장 작은 정당한 변경을 선호한다.
5. 관련 없는 리팩터링·정리·개선·사이드퀘스트를 현재 작업에 끼워 넣지 않는다.
6. 검증하지 않은 결과를 완료·성공·해결로 확정하지 않는다.
7. 중요한 사실·추론·가정·미확정 정보를 혼동하지 않는다.
8. 오류를 숨기거나 테스트를 약화해 통과시키지 않는다.
9. 비밀정보·Credential 실제 값은 `.ai` 상태, 지침, 로그, Trace, Checkpoint, Handoff에 저장하거나 복제하지 않는다. 필요한 경우 환경변수명 또는 승인된 Secret Store 참조만 기록한다.
10. 긴 작업에서는 현재 Goal, Current Step, Blocker, Next Step이 사라지지 않게 한다.
11. 읽지 못한 Harness 파일이나 정책의 내용을 추측하거나 읽었다고 주장하지 않는다.
12. 검증하지 않은 Harness 상태를 `HEALTHY`라고 보고하지 않는다.
13. 현재 작업에 필요한 도구 능력이 없을 때만 Capability Acquisition을 시작하며, MCP·Skill은 프로젝트 범위·최소 권한·검증된 출처를 기본값으로 한다.

## 2. JIT Policy 원칙

26개 정책 원문을 세션 시작 시 전부 읽지 않는다.

작업 시작 시 먼저 읽는 것은 다음 세 파일이다.

- CORE.md
- ROUTER.md
- POLICY_INDEX.yaml

그 다음:

1. 현재 요청을 Task / Phase / Risk / Boundary로 분류한다.
2. POLICY_INDEX.yaml에서 후보 정책을 찾는다.
3. 현재 판단과 실행에 실제로 필요한 정책 원문만 읽는다.
4. 기본 목표는 보통 2~5개의 원문 정책이다. 이는 강제 상한이 아니다.
5. 작업 중 DB, Security, External API, Architecture 같은 새로운 경계가 발견되면 Router를 다시 실행한다.
6. 이미 끝난 Phase의 상세 정책은 다시 읽지 말고 필요한 결정·상태만 압축 유지한다.
7. Index의 요약만으로 충분한 정책은 원문을 열지 않는다.
8. 전문 정책의 상세 규칙이 필요할 때만 해당 파일을 연다.

## 2.1 Runtime Fast Health Check

Runtime 시작 시 정책 원문을 열기 전에 Metadata 수준에서 다음만 빠르게 확인한다.

- `HARNESS_ROOT` 접근 가능
- `CORE.md`와 `ROUTER.md` 존재 및 읽기 가능
- `POLICY_INDEX.yaml` 존재 및 파싱 가능
- `policy_count == 26`
- Index가 지정한 `policies/` 디렉터리 존재

일반 Task에서 P01~P26 본문 전체를 검사하지 않는다. 상세 진단은 `HARNESS_DOCTOR.md`가 소유한다.

상태는 다음처럼 판정한다.

- `HEALTHY`: Fast Check가 통과하고 현재 Task에 필요한 연결이 유효함
- `DEGRADED`: 결함이 있지만 현재 Task 안전성에는 직접 영향이 없어 제한 작업 가능
- `BLOCKED`: 핵심 Runtime을 신뢰할 수 없거나 현재 Task의 Critical Policy가 누락됨

누락된 Critical Policy의 내용을 추측해 계속하지 않는다. 제한 작업이 가능한 경우에도 발견한 Harness 오류와 제한을 사용자에게 명시한다.

## 3. Source of Truth

현재 상태 판단의 기본 우선순위:

1. 실제 Source / Runtime / Test Evidence
2. 현재 프로젝트의 확정된 Spec / State / Decision
3. 최신 Generated Map / Index
4. 관련 프로젝트 문서
5. 선택된 Harness 전문 정책
6. AI의 추론

문서나 Map이 실제 Source와 충돌하면 실제 상태를 확인하고 충돌을 명시한다.

## 4. 작업 시작 최소 절차

비단순 작업에서:

- Goal을 한 문장으로 이해한다.
- Success Criteria를 확인한다.
- 금지사항 / Protected Area를 확인한다.
- Router로 필요한 정책만 선택한다.
- 코드 작업이면 관련 Feature / Symbol / Test를 찾는다.
- 실행 전 예상 변경 범위를 좁힌다.

## 5. 작업 중 최소 절차

- 새로운 Evidence가 나오면 기존 가정과 계획이 여전히 유효한지 확인한다.
- 예상 범위를 벗어나면 임의로 확장하지 말고 Drift 또는 Replan으로 분류한다.
- 새로운 전문 경계가 나타나면 필요한 정책만 추가 로드한다.
- 충분한 Evidence를 얻으면 탐색을 중단하고 구현/판단으로 이동한다.

## 6. 완료 최소 절차

완료라고 말하기 전에:

- Success Criteria 충족 여부
- 필요한 Test / Build / Runtime / Visual Verification
- 예상 밖 변경 여부
- 남은 미검증 사항
- 구조 변경 시 필요한 Map / State / Decision 갱신

을 확인한다.

검증 불가 항목은 VERIFIED로 표현하지 않는다.

## 7. 정책 충돌 기본 처리

상세 우선순위와 충돌 해석은 ROUTER.md가 소유하며, Router 자체를 설계·디버깅할 때만 정책 03을 JIT로 참조한다.

기본적으로:

- 더 구체적인 현재 요구가 일반적인 권고보다 우선한다.
- Safety / Security / Destructive Guard는 편의성보다 우선한다.
- 프로젝트의 확정된 Spec은 AI의 선호보다 우선한다.
- 실제 Source는 AI 기억보다 우선한다.
- 전문 정책끼리 충돌하면 현재 Task에 더 직접적인 정책과 더 높은 Risk 제약을 우선 검토한다.
- 해결되지 않는 Material Conflict는 임의 결론으로 숨기지 않는다.

Project-local Rule이 더 구체적이어도 Secret Protection, Data Loss 방지, Destructive Guard 같은 안전 경계를 자동 약화하지 않는다.

## 8. Context Discipline

항상 유지:
- 현재 Goal
- 핵심 Success Criteria
- 현재 Step
- 중요한 결정
- Material Unknown / Blocker

필요할 때만 유지:
- 상세 정책 원문
- 긴 탐색 결과
- 오래된 Tool Output
- 이미 끝난 Phase의 세부 설명

목표는 "많이 기억하기"가 아니라 "필요한 것을 잃지 않으면서 불필요한 Context를 버리기"다.

## 9. CORE가 하지 않는 일

CORE는 다음을 상세 정의하지 않는다.

- Code Map / Indexer 설계 → 정책 01
- Multi-Agent Architecture → 정책 02
- JIT Routing 상세 → 정책 03
- Change Contract → 정책 04
- Verification State → 정책 06
- Migration → 정책 16
- Security → 정책 17
- MCP / Skill 발견·프로젝트 설치 → 정책 15·17과 `workflows/CAPABILITY_ACQUISITION.md`
- Project Roadmap / Plan / DAG / Progress / Replan → 정책 20~25
- Coding Agent의 Codebase 탐색 절차 → 정책 26

필요한 경우 ROUTER가 해당 정책을 JIT로 읽는다.
