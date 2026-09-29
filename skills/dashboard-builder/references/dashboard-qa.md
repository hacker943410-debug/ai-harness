# Dashboard QA

## Functional
- [ ] 페이지가 열린다.
- [ ] console error가 없다.
- [ ] 데이터 로드 성공한다.
- [ ] 잘못된 파일/경로에서 오류 UI가 나온다.
- [ ] KPI와 차트가 동일 filter context를 사용한다.
- [ ] filter reset이 동작한다.
- [ ] 자동 갱신 시 중복 chart instance가 쌓이지 않는다.

## Data Integrity
- [ ] KPI 최소 2개를 독립 계산으로 cross-check했다.
- [ ] 날짜 범위가 원본과 일치한다.
- [ ] 합계가 raw row 기준 집계와 일치한다.
- [ ] 퍼센트 분모가 정확하다.
- [ ] null과 zero가 구분된다.
- [ ] 중복 데이터가 의도치 않게 이중 집계되지 않는다.

## Visual
- [ ] 첫 화면에서 핵심 KPI와 primary chart가 보인다.
- [ ] 긴 제목/범주 label이 잘리지 않는다.
- [ ] legend가 과도하게 공간을 차지하지 않는다.
- [ ] 테이블 숫자 정렬과 단위가 일관된다.
- [ ] 1440px / 1024px / 390px 폭에서 layout이 유지된다.

## UX
- [ ] loading / empty / error state 존재
- [ ] filter 적용 상태를 알 수 있음
- [ ] 마지막 업데이트 시각 확인 가능(주기 갱신형)
- [ ] 데이터 파일을 교체할 경로가 명확함

검증하지 않은 항목은 체크하지 않는다. 정적 검사와 실제 브라우저 동작 검증을 구분한다.
