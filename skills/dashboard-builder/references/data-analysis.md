# Data Analysis Workflow

## Goal
대시보드 설계 전에 데이터의 의미와 품질을 확정한다.

## Inspection Order
1. 파일/시트 목록
2. 헤더 및 첫 20~50행 샘플
3. 전체 행 수와 사용 범위
4. 컬럼별 타입 추정
5. 날짜 최소/최대
6. 범주형 unique count
7. 수치형 min/max/mean/sum
8. null count
9. duplicate 후보
10. KPI 계산에 필요한 key 존재 여부

## Column Classification
- `time`: 일자, 월, 주차, 시간
- `dimension`: 조직, 제품, 고객, 상태, 지역, 유형
- `measure`: 매출, 수량, 비용, 시간, 건수
- `identifier`: ID, 티켓번호, 사번, 주문번호
- `text`: 메모, 제목, 상세내용

identifier는 단순 합계/평균 대상으로 사용하지 않는다.

## Data Quality Rules
- 날짜처럼 보이는 문자열은 실제 파싱 가능 여부를 확인한다.
- %, 통화, 천 단위 문자열을 숫자로 정규화할 때 원본 단위를 보존한다.
- 0과 null을 동일하게 취급하지 않는다.
- 중복 제거는 업무 key가 확인된 경우만 수행한다.
- 합계행/소계행은 raw transaction과 분리한다.

## KPI Feasibility
KPI마다 numerator, denominator, time grain, filter scope, unit, null handling, aggregation rule을 확인한다.

## Large Files
원본 전체를 LLM context에 넣지 않는다. 코드로 schema/profile과 집계를 계산하고 representative sample만 inspect한다.
