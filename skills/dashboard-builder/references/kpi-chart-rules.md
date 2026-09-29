# KPI & Chart Selection Rules

## KPI Selection
좋은 KPI는 다음 중 하나 이상을 답한다.
1. 지금 상태가 어떤가?
2. 이전/목표 대비 어떻게 변했는가?
3. 즉시 조치가 필요한 이상이 있는가?

상단 KPI 카드는 보통 3~7개다. KPI마다 name, business question, formula, current value, comparison basis, unit, directionality를 갖는다.

## Chart Selection by Question
| 질문 | 권장 차트 |
|---|---|
| 시간에 따라 어떻게 변했나? | line / area |
| 항목 간 크기 차이는? | horizontal bar / column |
| 구성 비율은? | 100% stacked bar, 제한적인 donut |
| 목표 대비 실적은? | progress / variance bar |
| 두 변수 관계는? | scatter |
| 분포와 이상치는? | histogram / boxplot 대체 시 bar bins |
| 여러 상태의 흐름은? | stacked bar / status timeline |
| 상세값 확인은? | sortable table |

## Avoid
3D chart, 의미 없는 gauge, 범주가 많은 pie/donut, 동일 데이터 반복, 설명 없는 dual-axis, 색상만으로 상태 구분.

## Layout
1. Header + period/filter
2. KPI row
3. Primary trend/status
4. Driver breakdown
5. Secondary comparison
6. Detail table

가장 중요한 차트에 가장 넓은 영역을 준다.
