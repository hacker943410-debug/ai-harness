# Runtime Data Connection

## Default Excel Runtime

```js
const DATA_URL = './data.xlsx';
```

## Web Mode: http/https
- `fetch(DATA_URL + '?t=' + Date.now(), { cache: 'no-store' })`
- ArrayBuffer → SheetJS workbook parse
- 필요한 sheet를 normalized rows로 변환
- 파싱/렌더링 로직은 별도 함수로 분리
- 자동 갱신이 필요하면 사용자 요구와 데이터 갱신주기에 맞춘다.

## Local Mode: file://
브라우저 보안상 fetch가 막힐 수 있으므로 파일 선택 input, drag & drop, FileReader/File.arrayBuffer fallback을 제공한다. Web/Local mode는 동일한 `parseWorkbook()` 이후 로직을 공유한다.

## Sheet Selection
sheet 이름을 임의 추정하지 않는다. 명시값 우선, 없으면 workbook sheet names와 실제 데이터 존재 여부를 확인한다. 여러 sheet join은 업무 key를 명시한다.

## Normalization
header trim, empty header 처리, date normalization, numeric coercion, percent normalization, null 보존. 원본을 파괴하지 말고 normalized layer를 만든다.

## Dependency Policy
간단한 배포는 CDN 기반 SheetJS/Chart.js를 사용할 수 있다. 폐쇄망/오프라인이면 dependency를 로컬 vendoring하거나 기존 package manager를 사용한다.

## Refresh State
last updated, loading, error, retry를 표시한다. refresh 실패 시 기존 화면이 stale data임을 사용자가 알 수 있어야 한다.
