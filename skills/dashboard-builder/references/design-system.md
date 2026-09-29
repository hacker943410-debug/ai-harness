# Dashboard Design System

사용자가 별도 디자인 시스템을 제공하지 않았을 때의 기본 규칙이다.

## Visual Hierarchy
- Page title: 22~28px
- Section title: 16~20px
- KPI value: 24~36px
- Body/table: 12~14px
- Secondary metadata: body보다 한 단계 작게

## Grid & Spacing
- 12-column responsive grid
- 8px spacing scale
- section gap: 20~32px
- card padding: 16~24px
- radius는 과도하게 둥글지 않게 일관 적용

## KPI Cards
KPI name, current value, comparison/variance, optional micro-context 중심. 긴 설명은 카드 밖으로 뺀다.

## Charts
장식/gridline 최소화, 필요한 label만 표시, 단위가 있는 tooltip, series 수보다 과도한 색상 금지.

## Tables
text left, number right, date/time consistent alignment, sticky header 고려, status는 text/icon과 함께 표시.

## Responsive
- Desktop 1366~1440px 기본
- 1024px 이하: 2-column/1-column
- 600px 이하: KPI 1~2열, 차트 1열
- 390px에서 horizontal page scroll 금지

## Accessibility
대비 확보, 상태를 색만으로 표현하지 않음, focus 상태 제공.
