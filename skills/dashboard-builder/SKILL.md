---
name: dashboard-builder
description: Excel/CSV/JSON 등 업무 데이터를 분석해 KPI, 질문 중심 차트, 레이아웃, 디자인 시스템을 설계하고 검증 가능한 단일 HTML 웹 대시보드를 생성한다. 경영/운영/실적/현황 대시보드, Excel 보고서의 웹 시각화, Chart.js·SheetJS 기반 dashboard.html 또는 index.html 제작 요청에 사용한다.
---

# Dashboard Builder

업무 데이터를 **분석 → 기획 → 구현 → 검증** 순서로 처리해 실제 의사결정에 쓰이는 웹 대시보드를 만든다.

이 Skill은 단순히 예쁜 차트를 만드는 Skill이 아니다. 데이터가 답해야 하는 질문을 먼저 정의하고, KPI와 차트를 그 질문에 연결한 뒤, 실제 데이터 파일과 동작하는 결과물을 생성한다.

## Core Principles

1. **Question-first**: 차트보다 먼저 “이 화면이 답해야 할 질문”을 정의한다.
2. **Data-grounded**: 실제 컬럼·값·기간·단위를 확인하지 않은 KPI를 만들지 않는다.
3. **Progressive disclosure**: 현재 단계에 필요한 reference만 읽는다. 모든 문서를 한 번에 로드하지 않는다.
4. **One source of truth**: KPI 계산식과 데이터 변환 로직은 한 곳에서 정의하고 카드/차트/표가 재사용한다.
5. **Executive scanability**: 5~10초 안에 현황, 이상, 추세, 원인을 파악할 수 있어야 한다.
6. **No decorative charts**: 질문에 답하지 못하는 차트는 넣지 않는다.
7. **Verify before done**: 생성 후 데이터 로드, KPI 값, 필터, 차트, 반응형, 오류 상태를 검증한다.

## Trigger Examples

- “이 엑셀 파일로 대시보드 만들어줘.”
- “매출/운영/장애/근무 현황을 웹 대시보드로 만들어줘.”
- “Excel 보고서를 HTML dashboard로 바꿔줘.”
- “KPI랑 차트를 알아서 정해서 경영진용 대시보드 만들어줘.”
- “Chart.js와 SheetJS로 data.xlsx를 읽는 대시보드를 만들어줘.”
- “Cloudflare R2/Workers에 올릴 대시보드 파일 구조 만들어줘.”

단순 Excel 수식 수정, 셀 서식 변경, 데이터 정리만 요청한 경우에는 우선 사용하지 않는다.

## Required Workflow

### Phase 0 — Context Check

사용자 요청, 현재 저장소, 제공 파일을 먼저 확인한다. 대상 데이터, 사용 대상(audience), 대시보드 목적이 명확하면 질문하지 말고 진행한다. 문맥으로 합리적으로 추정할 수 있으면 best judgment로 진행하고 `dashboard-brief.md`에 가정을 기록한다.

### Phase 1 — Inspect Data

반드시 파악한다.

- 파일 형식과 시트/테이블 이름
- 행/열 규모, 컬럼명, 데이터 타입
- 날짜 컬럼과 분석 가능 기간
- 범주형 차원(dimensions), 수치형 측정값(measures)
- null/중복/이상치
- 단위(원, %, 건, 시간 등)
- 계산 가능한 KPI 후보

세부 절차는 `references/data-analysis.md`를 JIT로 읽는다. 데이터를 읽지 못했거나 샘플만 있으면 존재하지 않는 값을 만들지 않고 prototype임을 명시한다.

### Phase 2 — Plan Dashboard

HTML을 바로 작성하지 않는다. 먼저 다음 기획을 만든다.

1. 핵심 분석 관점 3~5개
2. KPI 3~7개
3. 각 KPI의 계산식/분모/기간/단위
4. 차트 3~6개와 각 차트가 답하는 질문
5. 필터/슬라이서
6. 상단→하단 레이아웃
7. 예외/빈 데이터/오류 상태

`references/kpi-chart-rules.md`를 읽고, 가능하면 `templates/dashboard-brief.md` 형식으로 남긴다.

### Phase 3 — Choose Design System

사용자가 브랜드/참고 화면/기존 시스템을 지정하면 그것을 우선한다. 지정이 없으면 `references/design-system.md`의 기본 업무 대시보드 규칙을 사용한다. 외부 design-system.md가 제공되면 그 문서가 기본값보다 우선한다.

### Phase 4 — Implement

기본 산출물은 동작 가능한 `index.html`이다. 기존 React/Vite 등 프레임워크가 있으면 기존 스택을 존중한다.

Excel 직접 연결 모드에서는 `references/runtime-data.md`를 읽는다.

- `DATA_URL` 한 곳에서 데이터 경로 관리
- xlsx 파싱은 SheetJS 사용 가능
- 차트는 Chart.js 사용 가능
- http/https와 file:// 실행 모드 구분
- 웹 모드: 상대경로 데이터 자동 로드
- 로컬 모드: 파일 선택/drag & drop fallback
- 데이터 로딩 실패 상태 표시
- 동일 계산 로직을 KPI와 chart가 공유
- 필터 변경 시 KPI/chart/table 동시 갱신
- raw data 전체를 HTML에 하드코딩하지 않음
- 사용자 데이터에 없는 숫자를 demo value로 숨겨 넣지 않음

### Phase 5 — Verify

`references/dashboard-qa.md`를 읽고 최소한 다음을 검증한다.

- HTML/JS syntax error 없음
- 데이터 로드 성공/실패 UI
- KPI 계산식과 표시값 일치
- 필터가 관련 컴포넌트 전체에 적용
- 날짜/숫자/퍼센트 포맷
- 1366~1440px 데스크톱 첫 화면 가독성
- 390px 모바일 가로 overflow 없음
- chart legend/label 잘림 없음
- empty/null/zero 처리
- console error 없음

가능하면 `scripts/validate_dashboard.py`도 실행한다.

## Output Modes

- **Prototype**: `dashboard-brief.md` + `index.html`
- **Local Working Dashboard**: 실제 Excel/CSV 연결 + 필요 시 README
- **Deployable Dashboard**: 배포까지 요청되면 `references/cloudflare-deploy.md` 추가 JIT

배포 자격증명/token/secret은 코드에 하드코딩하지 않는다.

## JIT Reference Routing

- 데이터 구조 → `references/data-analysis.md`
- KPI/차트 → `references/kpi-chart-rules.md`
- 디자인 → `references/design-system.md`
- Excel runtime → `references/runtime-data.md`
- 최종 QA → `references/dashboard-qa.md`
- Cloudflare 배포 → `references/cloudflare-deploy.md`

## Completion Contract

1. 데이터 근거 없는 KPI가 없어야 한다.
2. 모든 차트에는 명확한 질문이 연결되어야 한다.
3. 중요한 지표의 계산 규칙을 추적할 수 있어야 한다.
4. 로딩/오류/빈 상태가 존재해야 한다.
5. 결과물은 실제 열어볼 수 있는 파일이어야 한다.
6. 검증하지 않은 항목을 완료라고 표현하지 않는다.
